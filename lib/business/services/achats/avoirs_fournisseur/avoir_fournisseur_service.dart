import 'package:drift/drift.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/avoir_fournisseur_list_item.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/services/stock/parametres/document_number_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/db/app_database.dart';

/// Supplier credit note. With [AvoirsFournisseur.retourMarchandise] the goods
/// go back to the supplier and leave the default depot (Peinture
/// `SyncAvoirFournisseurStockAsync`); otherwise it is a price-only credit.
class AvoirFournisseurService {
  AvoirFournisseurService(
    this._db,
    this._numbers,
    this._locations,
    this._stock,
  );

  final AppDatabase _db;
  final DocumentNumberService _numbers;
  final StockLocationService _locations;
  final StockMovementService _stock;

  Future<List<AvoirFournisseurListItem>> list({
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await (_db.select(_db.avoirsFournisseurs)
          ..orderBy([
            (a) => OrderingTerm.desc(a.date),
            (a) => OrderingTerm.desc(a.id),
          ]))
        .get();
    final tiers = await _db.select(_db.tiers).get();
    final tiersMap = {for (final t in tiers) t.id: t.nom};

    Iterable<AvoirsFournisseur> filtered = rows;
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
            (tiersMap[a.fournisseurId]?.toLowerCase().contains(t) ?? false),
      );
    }

    final docs = filtered.skip(offset).take(limit).toList();
    if (docs.isEmpty) return [];

    final lignes = await (_db.select(_db.avoirFournisseurLignes)
          ..where(
            (l) => l.avoirFournisseurId.isIn(docs.map((d) => d.id).toList()),
          ))
        .get();
    final linesByAvoir = <int, List<DocumentLine>>{};
    for (final l in lignes) {
      linesByAvoir.putIfAbsent(l.avoirFournisseurId, () => []).add(_toLine(l, ''));
    }

    return [
      for (final d in docs)
        AvoirFournisseurListItem(
          avoir: d,
          fournisseurNom: tiersMap[d.fournisseurId] ?? '?',
          totalTtc:
              DocumentTotals.fromLines(linesByAvoir[d.id] ?? const []).totalTtc,
        ),
    ];
  }

  Future<({AvoirsFournisseur avoir, List<DocumentLine> lines})?> getById(
    int id,
  ) async {
    final avoir = await (_db.select(_db.avoirsFournisseurs)
          ..where((a) => a.id.equals(id)))
        .getSingleOrNull();
    if (avoir == null) return null;

    final lineRows = await (_db.select(_db.avoirFournisseurLignes)
          ..where((l) => l.avoirFournisseurId.equals(id))
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
    final productIds = lineRows.map((l) => l.produitId).toSet();
    final products = productIds.isEmpty
        ? <Produit>[]
        : await (_db.select(_db.produits)
              ..where((p) => p.id.isIn(productIds.toList())))
            .get();
    final references = {for (final p in products) p.id: p.reference};

    return (
      avoir: avoir,
      lines: [
        for (final l in lineRows) _toLine(l, references[l.produitId] ?? ''),
      ],
    );
  }

  /// Creates or updates the avoir with its lines, then syncs the default depot
  /// stock. Returns the avoir id.
  Future<int> save({
    int? id,
    required int fournisseurId,
    required DateTime date,
    String motif = '',
    bool retourMarchandise = true,
    required List<DocumentLine> lines,
    int? createdByUserId,
  }) async {
    if (fournisseurId <= 0) throw StateError('Sélectionnez un fournisseur.');
    final validLines =
        lines.where((l) => l.produitId > 0 && l.quantite > 0).toList();
    if (validLines.isEmpty) {
      throw StateError('Ajoutez au moins une ligne avec quantité.');
    }
    if (validLines.any((l) => l.prixUnitaireHt < 0)) {
      throw StateError('Le prix unitaire ne peut pas être négatif.');
    }
    final ttc = DocumentTotals.fromLines(validLines).totalTtc;
    if (DocumentTotals.isEffectivelyZero(ttc)) {
      throw StateError('Le total TTC ne peut pas être nul.');
    }

    return _db.transaction(() async {
      final now = DateTime.now().toUtc();
      late int avoirId;
      late String numero;

      if (id == null) {
        numero = await _numbers.nextAvoirFournisseur();
        avoirId = await _db.into(_db.avoirsFournisseurs).insert(
              AvoirsFournisseursCompanion.insert(
                numero: numero,
                fournisseurId: fournisseurId,
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
        final existing = await (_db.select(_db.avoirsFournisseurs)
              ..where((a) => a.id.equals(id)))
            .getSingle();
        numero = existing.numero;
        await (_db.update(_db.avoirsFournisseurs)..where((a) => a.id.equals(id)))
            .write(
          AvoirsFournisseursCompanion(
            fournisseurId: Value(fournisseurId),
            date: Value(date),
            motif: Value(motif.trim()),
            retourMarchandise: Value(retourMarchandise),
            updatedAt: Value(now),
          ),
        );
        await (_db.delete(_db.avoirFournisseurLignes)
              ..where((l) => l.avoirFournisseurId.equals(id)))
            .go();
      }

      for (final line in validLines) {
        await _db.into(_db.avoirFournisseurLignes).insert(
              AvoirFournisseurLignesCompanion.insert(
                avoirFournisseurId: avoirId,
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

      final depot = await _locations.getOrCreateDefaultDepot();
      await _stock.resyncAvoirFournisseurStock(
        avoirFournisseurId: avoirId,
        noteDetail: numero,
        depotLocationId: depot.id,
        retourMarchandise: retourMarchandise,
        lines: validLines
            .map((l) => (produitId: l.produitId, quantite: l.quantite)),
        createdByUserId: createdByUserId,
      );

      return avoirId;
    });
  }

  /// Deletes the avoir and puts returned goods back into the default depot.
  Future<void> delete(int id, {int? createdByUserId}) async {
    await _db.transaction(() async {
      final avoir = await (_db.select(_db.avoirsFournisseurs)
            ..where((a) => a.id.equals(id)))
          .getSingle();
      final depot = await _locations.getOrCreateDefaultDepot();
      await _stock.resyncAvoirFournisseurStock(
        avoirFournisseurId: id,
        noteDetail: avoir.numero,
        depotLocationId: depot.id,
        retourMarchandise: false,
        lines: const [],
        createdByUserId: createdByUserId,
      );
      await (_db.delete(_db.avoirFournisseurLignes)
            ..where((l) => l.avoirFournisseurId.equals(id)))
          .go();
      await (_db.delete(_db.avoirsFournisseurs)..where((a) => a.id.equals(id)))
          .go();
    });
  }

  static DocumentLine _toLine(AvoirFournisseurLigne l, String reference) =>
      DocumentLine(
        produitId: l.produitId,
        reference: reference,
        designation: l.designation,
        quantite: l.quantite,
        prixUnitaireHt: l.prixUnitaireHT,
        remise: l.remise,
        tauxTva: l.tauxTVA,
      );
}
