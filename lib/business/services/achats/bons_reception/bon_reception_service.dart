import 'package:drift/drift.dart';
import 'package:fes_distribution/business/enums/mode_paiement.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/bon_reception_list_item.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/models/document_paiement.dart';
import 'package:fes_distribution/business/services/stock/parametres/document_number_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/db/app_database.dart';

/// Bon de réception = goods received from a supplier. Stock always enters the
/// default depot (Peinture `SyncBonReceptionStockAsync`); BR lines have no
/// remise. Invoiced later on a facture fournisseur.
///
/// The BR is also where the debt lives: payments to the supplier are recorded
/// here, mirroring the ventes side where they sit on the BL. The facture
/// fournisseur only groups BRs and carries no money of its own.
class BonReceptionService {
  BonReceptionService(
    this._db,
    this._numbers,
    this._locations,
    this._stock,
  );

  final AppDatabase _db;
  final DocumentNumberService _numbers;
  final StockLocationService _locations;
  final StockMovementService _stock;

  Future<List<BonReceptionListItem>> list({
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await (_db.select(_db.bonsReception)
          ..orderBy([
            (b) => OrderingTerm.desc(b.date),
            (b) => OrderingTerm.desc(b.id),
          ]))
        .get();
    final tiers = await _db.select(_db.tiers).get();
    final tiersMap = {for (final t in tiers) t.id: t.nom};

    Iterable<BonsReceptionData> filtered = rows;
    if (dateFrom != null) {
      filtered = filtered.where((b) => !b.date.isBefore(dateFrom));
    }
    if (dateTo != null) {
      filtered = filtered.where((b) => !b.date.isAfter(dateTo));
    }
    if (search != null && search.trim().isNotEmpty) {
      final t = search.trim().toLowerCase();
      filtered = filtered.where(
        (b) =>
            b.numero.toLowerCase().contains(t) ||
            (tiersMap[b.fournisseurId]?.toLowerCase().contains(t) ?? false),
      );
    }

    final docs = filtered.skip(offset).take(limit).toList();
    if (docs.isEmpty) return [];

    final factureIds =
        docs.map((d) => d.factureFournisseurId).whereType<int>().toSet();
    final factures = factureIds.isEmpty
        ? <FacturesFournisseur>[]
        : await (_db.select(_db.facturesFournisseurs)
              ..where((f) => f.id.isIn(factureIds.toList())))
            .get();
    final factureMap = {for (final f in factures) f.id: f.numero};

    final paiements = await (_db.select(_db.paiementsFournisseurs)
          ..where((p) => p.bonReceptionId.isIn(docs.map((d) => d.id).toList())))
        .get();
    final paidByBr = <int, double>{};
    for (final p in paiements) {
      paidByBr[p.bonReceptionId] =
          (paidByBr[p.bonReceptionId] ?? 0) + p.montant;
    }

    return [
      for (final d in docs)
        BonReceptionListItem(
          br: d,
          fournisseurNom: tiersMap[d.fournisseurId] ?? '?',
          factureNumero: factureMap[d.factureFournisseurId],
          montantPaye: paidByBr[d.id] ?? 0,
        ),
    ];
  }

  Future<
      ({
        BonsReceptionData br,
        List<DocumentLine> lines,
        List<DocumentPaiement> paiements,
        String? factureNumero,
      })?> getById(int id) async {
    final br = await (_db.select(_db.bonsReception)
          ..where((b) => b.id.equals(id)))
        .getSingleOrNull();
    if (br == null) return null;
    final facture = br.factureFournisseurId == null
        ? null
        : await (_db.select(_db.facturesFournisseurs)
              ..where((f) => f.id.equals(br.factureFournisseurId!)))
            .getSingleOrNull();

    final lineRows = await (_db.select(_db.bonReceptionLignes)
          ..where((l) => l.bRId.equals(id))
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
    final productIds = lineRows.map((l) => l.produitId).toSet();
    final products = productIds.isEmpty
        ? <Produit>[]
        : await (_db.select(_db.produits)
              ..where((p) => p.id.isIn(productIds.toList())))
            .get();
    final productMap = {for (final p in products) p.id: p};

    final paiementRows = await (_db.select(_db.paiementsFournisseurs)
          ..where((p) => p.bonReceptionId.equals(id))
          ..orderBy([
            (p) => OrderingTerm.desc(p.date),
            (p) => OrderingTerm.desc(p.id),
          ]))
        .get();

    return (
      br: br,
      lines: [
        for (final l in lineRows)
          DocumentLine(
            produitId: l.produitId,
            reference: productMap[l.produitId]?.reference ?? '',
            designation: l.designation,
            quantite: l.quantiteRecue,
            prixUnitaireHt: l.prixUnitaireHT,
            tauxTva: l.tauxTVA,
          ),
      ],
      paiements: [
        for (final p in paiementRows)
          DocumentPaiement(
            date: p.date,
            montant: p.montant,
            mode: ModePaiement.fromCode(p.mode),
            reference: p.reference,
          ),
      ],
      factureNumero: facture?.numero,
    );
  }

  /// Creates or updates the BR with its lines and payments, then syncs the
  /// default depot stock and product purchase prices. Returns the BR id.
  Future<int> save({
    int? id,
    required int fournisseurId,
    required DateTime date,
    String note = '',
    required List<DocumentLine> lines,
    List<DocumentPaiement> paiements = const [],
    int? createdByUserId,
  }) async {
    if (fournisseurId <= 0) throw StateError('Sélectionnez un fournisseur.');
    final validLines = lines
        .where((l) => l.produitId > 0 && l.quantite > 0)
        .map((l) => l.copyWith(remise: 0))
        .toList();
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
    if (paiements.any((p) => p.montant <= 0)) {
      throw StateError('Le montant doit être supérieur à 0.');
    }
    final totalPaye = paiements.fold<double>(0, (s, p) => s + p.montant);
    if (DocumentTotals.paymentsExceedTtc(ttc, totalPaye)) {
      throw StateError(
        'La somme des paiements (${totalPaye.toStringAsFixed(2)} TTC) ne peut pas '
        'dépasser le total du BR (${ttc.toStringAsFixed(2)} TTC).',
      );
    }

    return _db.transaction(() async {
      final now = DateTime.now().toUtc();
      final estPayee = _computeEstPayee(ttc, paiements);
      late int brId;
      late String numero;

      if (id == null) {
        numero = await _numbers.nextBonReception();
        brId = await _db.into(_db.bonsReception).insert(
              BonsReceptionCompanion.insert(
                numero: numero,
                fournisseurId: fournisseurId,
                date: date,
                estPayee: Value(estPayee),
                totalTtc: Value(ttc),
                note: Value(note.trim()),
                createdAt: now,
                updatedAt: now,
                createdByUserId: Value(createdByUserId),
              ),
            );
      } else {
        brId = id;
        final existing = await (_db.select(_db.bonsReception)
              ..where((b) => b.id.equals(id)))
            .getSingle();
        numero = existing.numero;
        await (_db.update(_db.bonsReception)..where((b) => b.id.equals(id)))
            .write(
          BonsReceptionCompanion(
            fournisseurId: Value(fournisseurId),
            date: Value(date),
            estPayee: Value(estPayee),
            totalTtc: Value(ttc),
            note: Value(note.trim()),
            updatedAt: Value(now),
          ),
        );
        await (_db.delete(_db.bonReceptionLignes)
              ..where((l) => l.bRId.equals(id)))
            .go();
        await (_db.delete(_db.paiementsFournisseurs)
              ..where((p) => p.bonReceptionId.equals(id)))
            .go();
      }

      for (final line in validLines) {
        await _db.into(_db.bonReceptionLignes).insert(
              BonReceptionLignesCompanion.insert(
                bRId: brId,
                produitId: line.produitId,
                designation: line.designation,
                quantiteRecue: line.quantite,
                prixUnitaireHT: line.prixUnitaireHt,
                tauxTVA: Value(line.tauxTva),
                createdAt: now,
                updatedAt: now,
                createdByUserId: Value(createdByUserId),
              ),
            );
      }

      for (final p in paiements) {
        await _db.into(_db.paiementsFournisseurs).insert(
              PaiementsFournisseursCompanion.insert(
                bonReceptionId: brId,
                date: p.date,
                montant: p.montant,
                mode: Value(p.mode.code),
                reference: Value(p.reference.trim()),
                createdAt: now,
                updatedAt: now,
                createdByUserId: Value(createdByUserId),
              ),
            );
      }

      final depot = await _locations.getOrCreateDefaultDepot();
      await _stock.resyncBonReceptionStock(
        bonReceptionId: brId,
        noteDetail: numero,
        depotLocationId: depot.id,
        lines: validLines.map(
          (l) => (
            produitId: l.produitId,
            quantite: l.quantite,
            prixUnitaireHt: l.prixUnitaireHt,
          ),
        ),
        createdByUserId: createdByUserId,
      );

      return brId;
    });
  }

  /// Deletes the BR and takes its goods back out of the default depot.
  /// Refused when the BR is already invoiced.
  Future<void> delete(int id, {int? createdByUserId}) async {
    await _db.transaction(() async {
      final br = await (_db.select(_db.bonsReception)
            ..where((b) => b.id.equals(id)))
          .getSingle();
      if (br.factureFournisseurId != null) {
        final facture = await (_db.select(_db.facturesFournisseurs)
              ..where((f) => f.id.equals(br.factureFournisseurId!)))
            .getSingleOrNull();
        throw StateError(
          'Impossible de supprimer ${br.numero} : déjà facturé '
          '(${facture?.numero ?? '#${br.factureFournisseurId}'}).',
        );
      }

      final depot = await _locations.getOrCreateDefaultDepot();
      await _stock.resyncBonReceptionStock(
        bonReceptionId: id,
        noteDetail: br.numero,
        depotLocationId: depot.id,
        lines: const [],
        createdByUserId: createdByUserId,
      );

      await (_db.delete(_db.bonReceptionLignes)..where((l) => l.bRId.equals(id)))
          .go();
      await (_db.delete(_db.paiementsFournisseurs)
            ..where((p) => p.bonReceptionId.equals(id)))
          .go();
      await (_db.delete(_db.bonsReception)..where((b) => b.id.equals(id))).go();
    });
  }

  /// Credit payments do not count as paid (Peinture `SyncEstPayee`).
  static bool _computeEstPayee(double ttc, List<DocumentPaiement> paiements) {
    final paid = paiements
        .where((p) => p.mode != ModePaiement.credit)
        .fold<double>(0, (s, p) => s + p.montant);
    return ttc > 0 && paid >= ttc - DocumentTotals.paiementTtcTolerance;
  }
}
