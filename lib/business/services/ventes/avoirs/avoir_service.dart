import 'package:drift/drift.dart';
import 'package:fes_distribution/business/enums/user_type.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/avoir_list_item.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/models/linked_document.dart';
import 'package:fes_distribution/business/services/stock/parametres/document_number_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/db/app_database.dart';

/// Client credit note, optionally crediting a facture (Peinture
/// `AvoirWorkflowService`). With [Avoir.retourMarchandise] the goods come
/// back into a vendeur's car — never a depot, since all sales go through
/// vendeurs. The vendeur is not stored on the avoir: it is read back from the
/// avoir's own stock movements.
class AvoirService {
  AvoirService(
    this._db,
    this._numbers,
    this._locations,
    this._stock,
  );

  final AppDatabase _db;
  final DocumentNumberService _numbers;
  final StockLocationService _locations;
  final StockMovementService _stock;

  Future<List<AvoirListItem>> list({
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await (_db.select(_db.avoirs)
          ..orderBy([
            (a) => OrderingTerm.desc(a.date),
            (a) => OrderingTerm.desc(a.id),
          ]))
        .get();
    final tiers = await _db.select(_db.tiers).get();
    final tiersMap = {for (final t in tiers) t.id: t.nom};
    final factures = await _db.select(_db.factures).get();
    final factureMap = {for (final f in factures) f.id: f.numero};

    Iterable<Avoir> filtered = rows;
    if (dateFrom != null) {
      filtered = filtered.where((a) => !a.date.isBefore(dateFrom));
    }
    if (dateTo != null) {
      filtered = filtered.where((a) => !a.date.isAfter(dateTo));
    }
    if (search != null && search.trim().isNotEmpty) {
      final t = search.trim().toLowerCase();
      filtered = filtered.where(
        (a) =>
            a.numero.toLowerCase().contains(t) ||
            a.motif.toLowerCase().contains(t) ||
            (tiersMap[a.clientId]?.toLowerCase().contains(t) ?? false) ||
            (factureMap[a.factureId]?.toLowerCase().contains(t) ?? false),
      );
    }

    final docs = filtered.skip(offset).take(limit).toList();
    if (docs.isEmpty) return [];
    final ttcByAvoir = await _ttcByAvoir(docs.map((d) => d.id).toList());

    return [
      for (final d in docs)
        AvoirListItem(
          avoir: d,
          clientNom: tiersMap[d.clientId] ?? '?',
          totalTtc: ttcByAvoir[d.id] ?? 0,
          factureNumero: factureMap[d.factureId],
        ),
    ];
  }

  Future<
      ({
        Avoir avoir,
        List<DocumentLine> lines,
        int? vendeurId,
      })?> getById(int id) async {
    final avoir = await (_db.select(_db.avoirs)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
    if (avoir == null) return null;

    final lineRows = await (_db.select(_db.avoirLignes)
          ..where((l) => l.avoirId.equals(id))
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
    final references = await _referencesFor(lineRows.map((l) => l.produitId));

    return (
      avoir: avoir,
      lines: [
        for (final l in lineRows) _toLine(l, references[l.produitId] ?? ''),
      ],
      vendeurId: await _vendeurFromMovements(id),
    );
  }

  /// Factures of [clientId] an avoir can credit, newest first.
  Future<List<LinkedDocument>> facturesForClient(int clientId) async {
    final rows = await (_db.select(_db.factures)
          ..where((f) => f.clientId.equals(clientId))
          ..orderBy([
            (f) => OrderingTerm.desc(f.date),
            (f) => OrderingTerm.desc(f.id),
          ]))
        .get();
    return [
      for (final f in rows)
        LinkedDocument(
          id: f.id,
          numero: f.numero,
          date: f.date,
          totalTtc: f.totalTtc,
        ),
    ];
  }

  Future<Facture?> getFacture(int factureId) =>
      (_db.select(_db.factures)..where((f) => f.id.equals(factureId)))
          .getSingleOrNull();

  /// The facture's lines as avoir lines, one unit each (Peinture
  /// `LoadNewAsync(factureId)`: `Quantite = Math.Min(l.Quantite, 1)`).
  Future<List<DocumentLine>> loadFactureLines(int factureId) async {
    final rows = await (_db.select(_db.factureLignes)
          ..where((l) => l.factureId.equals(factureId))
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
    final references = await _referencesFor(rows.map((l) => l.produitId));
    return [
      for (final l in rows)
        DocumentLine(
          produitId: l.produitId,
          reference: references[l.produitId] ?? '',
          designation: l.designation,
          quantite: l.quantite < 1 ? l.quantite : 1,
          prixUnitaireHt: l.prixUnitaireHT,
          remise: l.remise,
          tauxTva: l.tauxTVA,
        ),
    ];
  }

  /// Vendeur of the facture's first BL — the car returned goods go back to.
  Future<int?> vendeurForFacture(int factureId) async {
    final bl = await (_db.select(_db.bonsLivraison)
          ..where((b) => b.factureId.equals(factureId) & b.vendeurId.isNotNull())
          ..orderBy([(b) => OrderingTerm.asc(b.date)])
          ..limit(1))
        .getSingleOrNull();
    return bl?.vendeurId;
  }

  /// TTC still available for avoirs on [factureId] (facture TTC minus the
  /// other avoirs already crediting it).
  Future<double> remainingOnFacture(int factureId, {int? excludeAvoirId}) async {
    final facture = await getFacture(factureId);
    if (facture == null) return 0;
    final others = await (_db.select(_db.avoirs)
          ..where(
            (a) =>
                a.factureId.equals(factureId) &
                (excludeAvoirId == null
                    ? const Constant(true)
                    : a.id.equals(excludeAvoirId).not()),
          ))
        .get();
    final ttc = await _ttcByAvoir(others.map((a) => a.id).toList());
    final deja = ttc.values.fold<double>(0, (s, v) => s + v);
    final reste = facture.totalTtc - deja;
    return reste > 0 ? reste : 0;
  }

  /// Creates or updates the avoir with its lines, then syncs the vendeur's
  /// car stock. Returns the avoir id.
  Future<int> save({
    int? id,
    required int clientId,
    int? factureId,
    required DateTime date,
    String motif = '',
    bool retourMarchandise = true,
    int? vendeurId,
    required List<DocumentLine> lines,
    int? createdByUserId,
  }) async {
    if (clientId <= 0) throw StateError('Sélectionnez un client.');
    final validLines =
        lines.where((l) => l.produitId > 0 && l.quantite > 0).toList();
    if (validLines.isEmpty) {
      throw StateError('Ajoutez au moins une ligne avec quantité.');
    }
    final ttc = DocumentTotals.fromLines(validLines).totalTtc;
    if (DocumentTotals.isEffectivelyZero(ttc)) {
      throw StateError('Le total TTC ne peut pas être nul.');
    }
    if (retourMarchandise && vendeurId == null) {
      throw StateError('Sélectionnez le vendeur qui reprend la marchandise.');
    }

    return _db.transaction(() async {
      if (factureId != null) {
        final facture = await getFacture(factureId);
        if (facture == null) throw StateError('Facture introuvable.');
        if (facture.clientId != clientId) {
          throw StateError(
            '${facture.numero} : le client ne correspond pas à celui de l\'avoir.',
          );
        }
        final reste = await remainingOnFacture(factureId, excludeAvoirId: id);
        if (ttc > reste + DocumentTotals.paiementTtcTolerance) {
          throw StateError(
            'Montant avoir (${ttc.toStringAsFixed(2)} TTC) supérieur au reste '
            'disponible sur la facture (${reste.toStringAsFixed(2)} TTC).',
          );
        }
      }
      final carId = retourMarchandise ? await _carLocationId(vendeurId!) : null;

      final now = DateTime.now().toUtc();
      late int avoirId;
      late String numero;
      if (id == null) {
        numero = await _numbers.nextAvoir();
        avoirId = await _db.into(_db.avoirs).insert(
              AvoirsCompanion.insert(
                numero: numero,
                clientId: clientId,
                factureId: Value(factureId),
                date: date,
                motif: Value(motif.trim()),
                retourMarchandise: Value(retourMarchandise),
                createdAt: now,
                updatedAt: now,
                createdByUserId: Value(createdByUserId),
              ),
            );
      } else {
        avoirId = id;
        final existing =
            await (_db.select(_db.avoirs)..where((a) => a.id.equals(id))).getSingle();
        numero = existing.numero;
        await (_db.update(_db.avoirs)..where((a) => a.id.equals(id))).write(
          AvoirsCompanion(
            clientId: Value(clientId),
            factureId: Value(factureId),
            date: Value(date),
            motif: Value(motif.trim()),
            retourMarchandise: Value(retourMarchandise),
            updatedAt: Value(now),
          ),
        );
        await (_db.delete(_db.avoirLignes)..where((l) => l.avoirId.equals(id)))
            .go();
      }

      for (final line in validLines) {
        await _db.into(_db.avoirLignes).insert(
              AvoirLignesCompanion.insert(
                avoirId: avoirId,
                produitId: line.produitId,
                designation: line.designation,
                quantite: line.quantite,
                prixUnitaireHT: line.prixUnitaireHt,
                remise: Value(line.remise),
                tauxTVA: Value(line.tauxTva),
                createdAt: now,
                updatedAt: now,
                createdByUserId: Value(createdByUserId),
              ),
            );
      }

      await _stock.resyncAvoirStock(
        avoirId: avoirId,
        noteDetail: numero,
        vendeurLocationId: carId,
        retourMarchandise: retourMarchandise,
        lines: validLines
            .map((l) => (produitId: l.produitId, quantite: l.quantite)),
        createdByUserId: createdByUserId,
      );

      return avoirId;
    });
  }

  /// Deletes the avoir and takes returned goods back out of the car.
  Future<void> delete(int id, {int? createdByUserId}) async {
    await _db.transaction(() async {
      final avoir =
          await (_db.select(_db.avoirs)..where((a) => a.id.equals(id))).getSingle();
      await _stock.resyncAvoirStock(
        avoirId: id,
        noteDetail: avoir.numero,
        vendeurLocationId: null,
        retourMarchandise: false,
        lines: const [],
        createdByUserId: createdByUserId,
      );
      await (_db.delete(_db.avoirLignes)..where((l) => l.avoirId.equals(id))).go();
      await (_db.delete(_db.avoirs)..where((a) => a.id.equals(id))).go();
    });
  }

  Future<int> _carLocationId(int vendeurId) async {
    final user = await (_db.select(_db.users)
          ..where(
            (u) => u.id.equals(vendeurId) & u.userType.equals(UserType.vendeur),
          ))
        .getSingleOrNull();
    if (user == null) throw StateError('Sélectionnez un vendeur.');
    return (await _locations.getOrCreateVirtualForUser(user)).id;
  }

  Future<int?> _vendeurFromMovements(int avoirId) async {
    final locationIds = await _stock.documentLocationIds(
      StockMovementService.origineTypeAvoir,
      avoirId,
    );
    if (locationIds.isEmpty) return null;
    final car = await (_db.select(_db.stockLocations)
          ..where(
            (l) =>
                l.id.isIn(locationIds.toList()) &
                l.isVirtual.equals(true) &
                l.userId.isNotNull(),
          )
          ..limit(1))
        .getSingleOrNull();
    return car?.userId;
  }

  Future<Map<int, double>> _ttcByAvoir(List<int> avoirIds) async {
    if (avoirIds.isEmpty) return {};
    final lignes = await (_db.select(_db.avoirLignes)
          ..where((l) => l.avoirId.isIn(avoirIds)))
        .get();
    final linesByAvoir = <int, List<DocumentLine>>{};
    for (final l in lignes) {
      linesByAvoir.putIfAbsent(l.avoirId, () => []).add(_toLine(l, ''));
    }
    return {
      for (final e in linesByAvoir.entries)
        e.key: DocumentTotals.fromLines(e.value).totalTtc,
    };
  }

  Future<Map<int, String>> _referencesFor(Iterable<int> produitIds) async {
    final ids = produitIds.toSet().toList();
    if (ids.isEmpty) return {};
    final products =
        await (_db.select(_db.produits)..where((p) => p.id.isIn(ids))).get();
    return {for (final p in products) p.id: p.reference};
  }

  static DocumentLine _toLine(AvoirLigne l, String reference) => DocumentLine(
        produitId: l.produitId,
        reference: reference,
        designation: l.designation,
        quantite: l.quantite,
        prixUnitaireHt: l.prixUnitaireHT,
        remise: l.remise,
        tauxTva: l.tauxTVA,
      );
}
