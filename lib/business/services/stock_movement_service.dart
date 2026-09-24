import 'package:drift/drift.dart';
import 'package:fes_distribution/business/models/stock_shortage.dart';
import 'package:fes_distribution/business/services/stock_balance_service.dart';
import 'package:fes_distribution/db/app_database.dart';

/// Stock transfer engine aligned with Peinture [StockMovementService].
class StockMovementService {
  StockMovementService(
    this._db,
    this._balance,
  );

  final AppDatabase _db;
  final StockBalanceService _balance;

  static const origineTypeBonCharge = 'BCH';
  static const origineTypeBonDecharge = 'BDH';

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
    required int fromId,
    required int toId,
    required double quantite,
    required String origineType,
    required int origineId,
    required String note,
    int? createdByUserId,
  }) async {
    if (quantite <= 0) {
      throw ArgumentError.value(quantite, 'quantite');
    }

    final fromAvant = await _balance.getStock(produitId, fromId);
    final toAvant = await _balance.getStock(produitId, toId);
    final now = DateTime.now().toUtc();

    await _db.into(_db.mouvementsStock).insert(
          MouvementsStockCompanion.insert(
            produitId: produitId,
            fromLocationId: Value(fromId),
            toLocationId: Value(toId),
            quantite: quantite,
            fromApres: Value(fromAvant - quantite),
            toApres: Value(toAvant + quantite),
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
