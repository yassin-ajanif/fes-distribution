import 'package:drift/drift.dart';
import 'package:fes_distribution/business/models/stock_shortage.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_balance_service.dart';
import 'package:fes_distribution/db/app_database.dart';

/// Stock transfer engine aligned with Peinture [StockMovementService].
class StockMovementService {
  StockMovementService(
    this._db,
    this._balance,
  );

  final AppDatabase _db;
  final StockBalanceService _balance;

  static const origineTypeBonLivraison = 'BL';
  static const origineTypeBonReception = 'BR';
  static const origineTypeAvoir = 'Avoir';
  static const origineTypeAvoirFournisseur = 'AvoirFournisseur';
  static const origineTypeBonCharge = 'BCH';
  static const origineTypeBonDecharge = 'BDH';
  static const origineTypeInventaire = 'Inventaire';
  static const origineTypeTransfert = 'Transfert';

  /// Manual stock correction at one location (Peinture "Ajustement").
  /// Positive [delta] adds stock, negative removes it.
  Future<void> applyAdjustment({
    required int produitId,
    required int locationId,
    required double delta,
    String note = '',
    int? createdByUserId,
  }) async {
    if (delta == 0) {
      throw ArgumentError('La variation ne peut pas être nulle.');
    }
    final motif = note.trim();
    await _db.transaction(() async {
      await _applyLocationMovement(
        produitId: produitId,
        fromId: delta < 0 ? locationId : null,
        toId: delta > 0 ? locationId : null,
        quantite: delta.abs(),
        origineType: origineTypeInventaire,
        origineId: null,
        note: motif.isEmpty ? 'Inventaire' : 'Inventaire — $motif',
        createdByUserId: createdByUserId,
      );
    });
  }

  /// Moves goods between two physical depots. Each product becomes one
  /// `Transfert` row in `MouvementsStock` (no document table).
  Future<void> transfer({
    required int fromLocationId,
    required int toLocationId,
    required Iterable<({int produitId, double quantite})> lines,
    String note = '',
    int? createdByUserId,
  }) async {
    if (fromLocationId == toLocationId) {
      throw StateError(
        'Le dépôt source et le dépôt destination doivent être différents.',
      );
    }

    final qtyByProduit = <int, double>{};
    for (final line in lines) {
      if (line.produitId <= 0 || line.quantite <= 0) continue;
      qtyByProduit[line.produitId] =
          (qtyByProduit[line.produitId] ?? 0) + line.quantite;
    }
    if (qtyByProduit.isEmpty) {
      throw StateError('Ajoutez au moins une ligne avec quantité.');
    }

    await _db.transaction(() async {
      final from = await _requirePhysicalLocation(fromLocationId);
      final to = await _requirePhysicalLocation(toLocationId);
      final motif = note.trim();
      final detail = 'Transfert ${from.nom} → ${to.nom}';

      for (final entry in qtyByProduit.entries) {
        await _applyLocationMovement(
          produitId: entry.key,
          fromId: from.id,
          toId: to.id,
          quantite: entry.value,
          origineType: origineTypeTransfert,
          origineId: null,
          note: motif.isEmpty ? detail : '$detail — $motif',
          createdByUserId: createdByUserId,
        );
      }
    });
  }

  Future<StockLocation> _requirePhysicalLocation(int locationId) async {
    final location = await (_db.select(_db.stockLocations)
          ..where((l) => l.id.equals(locationId) & l.actif.equals(true)))
        .getSingleOrNull();
    if (location == null) {
      throw StateError('Emplacement de stock inactif ou introuvable.');
    }
    if (location.isVirtual) {
      throw StateError(
        'Utilisez un bon de charge / décharge pour le stock d\'un vendeur.',
      );
    }
    return location;
  }

  Future<void> resyncBonChargeStock({
    required int bonChargeId,
    required String noteDetail,
    required int depotLocationId,
    required int virtualLocationId,
    required Iterable<({int produitId, double quantite})> lines,
    int? createdByUserId,
  }) =>
      _syncTransferDocumentStock(
        origineType: origineTypeBonCharge,
        origineId: bonChargeId,
        noteDetail: noteDetail,
        fromLocationId: depotLocationId,
        toLocationId: virtualLocationId,
        lines: lines,
        createdByUserId: createdByUserId,
      );

  Future<void> resyncBonDechargeStock({
    required int bonDechargeId,
    required String noteDetail,
    required int depotLocationId,
    required int virtualLocationId,
    required Iterable<({int produitId, double quantite})> lines,
    int? createdByUserId,
  }) =>
      _syncTransferDocumentStock(
        origineType: origineTypeBonDecharge,
        origineId: bonDechargeId,
        noteDetail: noteDetail,
        fromLocationId: virtualLocationId,
        toLocationId: depotLocationId,
        lines: lines,
        createdByUserId: createdByUserId,
      );

  /// A BL sale takes [lines] out of [vendeurLocationId] (the vendeur's car).
  /// Movements this BL left on another location (vendeur changed) are
  /// reversed first. Empty [lines] cancels the BL's whole stock impact.
  Future<void> resyncBonLivraisonStock({
    required int bonLivraisonId,
    required String noteDetail,
    required int vendeurLocationId,
    required Iterable<({int produitId, double quantite})> lines,
    int? createdByUserId,
  }) =>
      _resyncDocumentAtLocation(
        origineType: origineTypeBonLivraison,
        origineId: bonLivraisonId,
        noteDetail: noteDetail,
        locationId: vendeurLocationId,
        desiredSignedByProduit: _sumByProduit(lines, sign: -1),
        createdByUserId: createdByUserId,
      );

  /// A bon de réception brings [lines] into [depotLocationId] (the default
  /// depot) and updates each product's `PrixAchatHT` to the weighted average
  /// cost (Peinture `SyncBonReceptionStockAsync`). Empty [lines] cancels the
  /// BR's whole stock impact.
  Future<void> resyncBonReceptionStock({
    required int bonReceptionId,
    required String noteDetail,
    required int depotLocationId,
    required Iterable<({int produitId, double quantite, double prixUnitaireHt})>
        lines,
    int? createdByUserId,
  }) {
    final valid =
        lines.where((l) => l.produitId > 0 && l.quantite > 0).toList();
    final qtyByProduit = <int, double>{};
    final valueByProduit = <int, double>{};
    for (final l in valid) {
      qtyByProduit[l.produitId] = (qtyByProduit[l.produitId] ?? 0) + l.quantite;
      valueByProduit[l.produitId] =
          (valueByProduit[l.produitId] ?? 0) + l.quantite * l.prixUnitaireHt;
    }

    return _resyncDocumentAtLocation(
      origineType: origineTypeBonReception,
      origineId: bonReceptionId,
      noteDetail: noteDetail,
      locationId: depotLocationId,
      desiredSignedByProduit: qtyByProduit,
      createdByUserId: createdByUserId,
      onEntree: (produitId, entreeDelta) async {
        final totalQty = qtyByProduit[produitId];
        if (totalQty == null || totalQty <= 0) return;
        final newPrice = valueByProduit[produitId]! / totalQty;
        final produit = await (_db.select(_db.produits)
              ..where((p) => p.id.equals(produitId)))
            .getSingleOrNull();
        if (produit == null) return;
        final balanceAfter = await _balance.getStock(produitId, depotLocationId);
        final oldQty = balanceAfter - entreeDelta;
        final newQty = oldQty + entreeDelta;
        if (newQty <= 0) return;
        final prixAchat =
            (oldQty * produit.prixAchatHT + entreeDelta * newPrice) / newQty;
        await (_db.update(_db.produits)..where((p) => p.id.equals(produitId)))
            .write(ProduitsCompanion(prixAchatHT: Value(prixAchat)));
      },
    );
  }

  /// A supplier credit note with goods returned takes [lines] out of
  /// [depotLocationId] (the default depot). Without [retourMarchandise] — or
  /// with empty [lines] — the avoir has no stock impact.
  Future<void> resyncAvoirFournisseurStock({
    required int avoirFournisseurId,
    required String noteDetail,
    required int depotLocationId,
    required bool retourMarchandise,
    required Iterable<({int produitId, double quantite})> lines,
    int? createdByUserId,
  }) =>
      _resyncDocumentAtLocation(
        origineType: origineTypeAvoirFournisseur,
        origineId: avoirFournisseurId,
        noteDetail: noteDetail,
        locationId: depotLocationId,
        desiredSignedByProduit:
            retourMarchandise ? _sumByProduit(lines, sign: -1) : const {},
        createdByUserId: createdByUserId,
      );

  /// A client avoir with goods returned puts [lines] back into
  /// [vendeurLocationId] (the vendeur's car — sales never touch a depot).
  /// Without [retourMarchandise] — or with a null location / empty [lines] —
  /// every movement the avoir made is cancelled.
  Future<void> resyncAvoirStock({
    required int avoirId,
    required String noteDetail,
    required int? vendeurLocationId,
    required bool retourMarchandise,
    required Iterable<({int produitId, double quantite})> lines,
    int? createdByUserId,
  }) async {
    if (retourMarchandise && vendeurLocationId != null) {
      await _resyncDocumentAtLocation(
        origineType: origineTypeAvoir,
        origineId: avoirId,
        noteDetail: noteDetail,
        locationId: vendeurLocationId,
        desiredSignedByProduit: _sumByProduit(lines, sign: 1),
        createdByUserId: createdByUserId,
      );
      return;
    }
    for (final locationId in await documentLocationIds(origineTypeAvoir, avoirId)) {
      await _syncSingleLocationDocumentStock(
        origineType: origineTypeAvoir,
        origineId: avoirId,
        noteDetail: noteDetail,
        desiredSignedByProduit: const {},
        locationId: locationId,
        createdByUserId: createdByUserId,
      );
    }
  }

  /// Locations where a document's stock movements still have a non-zero net
  /// effect on at least one product.
  Future<Set<int>> documentLocationIds(String origineType, int origineId) async {
    final prior = await (_db.select(_db.mouvementsStock)
          ..where(
            (m) =>
                m.origineType.equals(origineType) &
                m.origineId.equals(origineId),
          ))
        .get();
    final net = <(int, int), double>{};
    for (final m in prior) {
      for (final locationId in [m.fromLocationId, m.toLocationId]) {
        if (locationId == null) continue;
        final key = (locationId, m.produitId);
        net[key] = (net[key] ?? 0) + _signedImpactOnLocation(m, locationId);
      }
    }
    return {
      for (final e in net.entries)
        if (e.value.abs() > 1e-9) e.key.$1,
    };
  }

  static Map<int, double> _sumByProduit(
    Iterable<({int produitId, double quantite})> lines, {
    required int sign,
  }) {
    final result = <int, double>{};
    for (final line in lines) {
      if (line.produitId <= 0 || line.quantite <= 0) continue;
      result[line.produitId] =
          (result[line.produitId] ?? 0) + sign * line.quantite;
    }
    return result;
  }

  /// Brings a single-location document to [desiredSignedByProduit] at
  /// [locationId]. Movements it left on any other location (location changed)
  /// are reversed first.
  Future<void> _resyncDocumentAtLocation({
    required String origineType,
    required int origineId,
    required String noteDetail,
    required int locationId,
    required Map<int, double> desiredSignedByProduit,
    int? createdByUserId,
    Future<void> Function(int produitId, double entreeDelta)? onEntree,
  }) async {
    final prior = await (_db.select(_db.mouvementsStock)
          ..where(
            (m) =>
                m.origineType.equals(origineType) &
                m.origineId.equals(origineId),
          ))
        .get();
    final otherLocationIds = {
      for (final m in prior) ...[m.fromLocationId, m.toLocationId],
    }.whereType<int>().where((id) => id != locationId);

    for (final oldLocationId in otherLocationIds) {
      await _syncSingleLocationDocumentStock(
        origineType: origineType,
        origineId: origineId,
        noteDetail: noteDetail,
        desiredSignedByProduit: const {},
        locationId: oldLocationId,
        createdByUserId: createdByUserId,
      );
    }
    await _syncSingleLocationDocumentStock(
      origineType: origineType,
      origineId: origineId,
      noteDetail: noteDetail,
      desiredSignedByProduit: desiredSignedByProduit,
      locationId: locationId,
      createdByUserId: createdByUserId,
      onEntree: onEntree,
    );
  }

  Future<void> _syncSingleLocationDocumentStock({
    required String origineType,
    required int origineId,
    required String noteDetail,
    required Map<int, double> desiredSignedByProduit,
    required int locationId,
    int? createdByUserId,
    Future<void> Function(int produitId, double entreeDelta)? onEntree,
  }) async {
    final movements = await (_db.select(_db.mouvementsStock)
          ..where(
            (m) =>
                m.origineType.equals(origineType) &
                m.origineId.equals(origineId),
          ))
        .get();
    final documentHasPriorMovements = movements.isNotEmpty;

    final currentSignedByProduit = <int, double>{};
    for (final m in movements) {
      final impact = _signedImpactOnLocation(m, locationId);
      if (impact == 0) continue;
      currentSignedByProduit[m.produitId] =
          (currentSignedByProduit[m.produitId] ?? 0) + impact;
    }

    final produitIds = {
      ...currentSignedByProduit.keys,
      ...desiredSignedByProduit.keys,
    };
    for (final produitId in produitIds) {
      final current = currentSignedByProduit[produitId] ?? 0;
      final desired = desiredSignedByProduit[produitId] ?? 0;
      final delta = desired - current;
      if (delta == 0) continue;

      final isAnnulation = desired == 0 && current != 0;
      final isModification = !isAnnulation && documentHasPriorMovements;
      final note = isAnnulation
          ? 'Annulation — $noteDetail'
          : isModification
              ? 'Modification — $noteDetail'
              : noteDetail;

      await _applyLocationMovement(
        produitId: produitId,
        fromId: delta < 0 ? locationId : null,
        toId: delta > 0 ? locationId : null,
        quantite: delta.abs(),
        origineType: origineType,
        origineId: origineId,
        note: note,
        createdByUserId: createdByUserId,
      );
      if (delta > 0 && onEntree != null) await onEntree(produitId, delta);
    }
  }

  Future<List<StockShortage>> getOutboundShortages({
    required int fromLocationId,
    required Iterable<({int produitId, double quantite})> desiredOutboundLines,
    String? origineType,
    int? origineId,
  }) async {
    final desired = <int, double>{};
    for (final line in desiredOutboundLines) {
      if (line.produitId <= 0 || line.quantite <= 0) continue;
      desired[line.produitId] =
          (desired[line.produitId] ?? 0) + line.quantite;
    }
    if (desired.isEmpty) return [];

    final location = await (_db.select(_db.stockLocations)
          ..where((l) => l.id.equals(fromLocationId)))
        .getSingleOrNull();
    final locationName = location?.nom ?? '#$fromLocationId';

    final alreadyOutbound = <int, double>{};
    if (origineType != null && origineId != null && origineId > 0) {
      final movements = await (_db.select(_db.mouvementsStock)
            ..where(
              (m) =>
                  m.origineType.equals(origineType) &
                  m.origineId.equals(origineId),
            ))
          .get();
      for (final group in movements.groupListsBy((m) => m.produitId).entries) {
        final net = group.value.fold<double>(
          0,
          (sum, m) => sum + _signedImpactOnLocation(m, fromLocationId),
        );
        alreadyOutbound[group.key] = net < 0 ? -net : 0;
      }
    }

    final shortages = <StockShortage>[];
    for (final entry in desired.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
      final produitId = entry.key;
      final want = entry.value;
      final already = alreadyOutbound[produitId] ?? 0;
      final additional = want - already;
      if (additional <= 0) continue;

      final available = await _balance.getStock(produitId, fromLocationId);
      if (available >= additional) continue;

      final product = await (_db.select(_db.produits)
            ..where((p) => p.id.equals(produitId)))
          .getSingleOrNull();
      shortages.add(
        StockShortage(
          produitId: produitId,
          reference: product?.reference ?? '#$produitId',
          designation: product?.designation ?? '',
          locationName: locationName,
          requested: want,
          available: available,
          shortage: additional - available,
        ),
      );
    }
    return shortages;
  }

  Future<void> _syncTransferDocumentStock({
    required String origineType,
    required int origineId,
    required String noteDetail,
    required int fromLocationId,
    required int toLocationId,
    required Iterable<({int produitId, double quantite})> lines,
    int? createdByUserId,
  }) async {
    if (fromLocationId <= 0 || toLocationId <= 0) {
      throw ArgumentError('Transfer locations are required.');
    }
    if (fromLocationId == toLocationId) {
      throw ArgumentError('From and To locations must differ.');
    }

    final fromOk = await (_db.select(_db.stockLocations)
          ..where(
            (l) => l.id.equals(fromLocationId) & l.actif.equals(true),
          ))
        .getSingleOrNull();
    final toOk = await (_db.select(_db.stockLocations)
          ..where((l) => l.id.equals(toLocationId) & l.actif.equals(true)))
        .getSingleOrNull();
    if (fromOk == null || toOk == null) {
      throw StateError('Emplacement de stock inactif ou introuvable.');
    }

    final desiredQtyByProduit = <int, double>{};
    for (final line in lines) {
      if (line.produitId <= 0 || line.quantite <= 0) continue;
      desiredQtyByProduit[line.produitId] =
          (desiredQtyByProduit[line.produitId] ?? 0) + line.quantite;
    }

    final movements = await (_db.select(_db.mouvementsStock)
          ..where(
            (m) =>
                m.origineType.equals(origineType) &
                m.origineId.equals(origineId),
          ))
        .get();

    final documentHasPriorMovements = movements.isNotEmpty;

    final currentImpact = <(int, int), double>{};
    for (final m in movements) {
      if (m.fromLocationId case final fid?) {
        final key = (m.produitId, fid);
        currentImpact[key] =
            (currentImpact[key] ?? 0) + _signedImpactOnLocation(m, fid);
      }
      if (m.toLocationId case final tid?) {
        final key = (m.produitId, tid);
        currentImpact[key] =
            (currentImpact[key] ?? 0) + _signedImpactOnLocation(m, tid);
      }
    }

    final desiredImpact = <(int, int), double>{};
    for (final entry in desiredQtyByProduit.entries) {
      desiredImpact[(entry.key, fromLocationId)] = -entry.value;
      desiredImpact[(entry.key, toLocationId)] = entry.value;
    }

    final produitIds = {
      ...currentImpact.keys.map((k) => k.$1),
      ...desiredImpact.keys.map((k) => k.$1),
    };

    for (final produitId in produitIds) {
      final locationIds = {
        ...currentImpact.keys.where((k) => k.$1 == produitId).map((k) => k.$2),
        ...desiredImpact.keys.where((k) => k.$1 == produitId).map((k) => k.$2),
      };

      final deltas = <int, double>{};
      for (final locId in locationIds) {
        final current = currentImpact[(produitId, locId)] ?? 0;
        final desired = desiredImpact[(produitId, locId)] ?? 0;
        final delta = desired - current;
        if (delta != 0) deltas[locId] = delta;
      }
      if (deltas.isEmpty) continue;

      final isAnnulation =
          (desiredQtyByProduit[produitId] ?? 0) == 0 && documentHasPriorMovements;
      final isModification = !isAnnulation && documentHasPriorMovements;
      final note = isAnnulation
          ? 'Annulation — $noteDetail'
          : isModification
              ? 'Modification — $noteDetail'
              : noteDetail;

      final sources = deltas.entries
          .where((e) => e.value < 0)
          .map((e) => (locationId: e.key, remaining: -e.value))
          .toList();
      final sinks = deltas.entries
          .where((e) => e.value > 0)
          .map((e) => (locationId: e.key, remaining: e.value))
          .toList();

      var si = 0;
      var ti = 0;
      while (si < sources.length && ti < sinks.length) {
        final move = sources[si].remaining < sinks[ti].remaining
            ? sources[si].remaining
            : sinks[ti].remaining;
        if (move > 0) {
          await _applyLocationMovement(
            produitId: produitId,
            fromId: sources[si].locationId,
            toId: sinks[ti].locationId,
            quantite: move,
            origineType: origineType,
            origineId: origineId,
            note: note,
            createdByUserId: createdByUserId,
          );
        }
        sources[si] = (
          locationId: sources[si].locationId,
          remaining: sources[si].remaining - move,
        );
        sinks[ti] = (
          locationId: sinks[ti].locationId,
          remaining: sinks[ti].remaining - move,
        );
        if (sources[si].remaining <= 0) si++;
        if (sinks[ti].remaining <= 0) ti++;
      }

      if (si < sources.length || ti < sinks.length) {
        throw StateError(
          'Stock transfer resync imbalance for product #$produitId on $origineType $origineId.',
        );
      }
    }
  }

  Future<void> _applyLocationMovement({
    required int produitId,
    required int? fromId,
    required int? toId,
    required double quantite,
    required String origineType,
    required int? origineId,
    required String note,
    int? createdByUserId,
  }) async {
    if (quantite <= 0) {
      throw ArgumentError.value(quantite, 'quantite');
    }
    if (fromId == null && toId == null) {
      throw ArgumentError('From and To cannot both be null.');
    }

    final fromApres = fromId == null
        ? null
        : await _balance.getStock(produitId, fromId) - quantite;
    final toApres =
        toId == null ? null : await _balance.getStock(produitId, toId) + quantite;
    final now = DateTime.now().toUtc();

    await _db.into(_db.mouvementsStock).insert(
          MouvementsStockCompanion.insert(
            produitId: produitId,
            fromLocationId: Value(fromId),
            toLocationId: Value(toId),
            quantite: quantite,
            fromApres: Value(fromApres),
            toApres: Value(toApres),
            origineType: origineType,
            origineId: Value(origineId),
            note: Value(note),
            createdAt: now,
            updatedAt: now,
            createdByUserId: Value(createdByUserId),
          ),
        );
  }

  static double _signedImpactOnLocation(MouvementsStockData m, int locationId) {
    if (m.toLocationId == locationId && m.fromLocationId != locationId) {
      return m.quantite.abs();
    }
    if (m.fromLocationId == locationId && m.toLocationId != locationId) {
      return -m.quantite.abs();
    }
    return 0;
  }
}

extension _GroupListsBy<E> on Iterable<E> {
  Map<K, List<E>> groupListsBy<K>(K Function(E) keyFn) {
    final map = <K, List<E>>{};
    for (final element in this) {
      map.putIfAbsent(keyFn(element), () => []).add(element);
    }
    return map;
  }
}
