import 'package:drift/drift.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/models/facture_fournisseur_list_item.dart';
import 'package:fes_distribution/business/models/linked_document.dart';
import 'package:fes_distribution/business/services/stock/parametres/document_number_service.dart';
import 'package:fes_distribution/db/app_database.dart';

/// Supplier invoice. Groups one or more BRs of the same supplier (each BR can
/// be invoiced once) and/or free catalog lines. No stock impact — stock
/// already entered the depot on the BR, and no money either: supplier payments
/// are recorded on the BRs themselves.
class FactureFournisseurService {
  FactureFournisseurService(this._db, this._numbers);

  final AppDatabase _db;
  final DocumentNumberService _numbers;

  /// [estPayee]: null = all, true = paid only, false = unpaid only.
  Future<List<FactureFournisseurListItem>> list({
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool? estPayee,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await (_db.select(_db.facturesFournisseurs)
          ..orderBy([
            (f) => OrderingTerm.desc(f.date),
            (f) => OrderingTerm.desc(f.id),
          ]))
        .get();
    final tiers = await _db.select(_db.tiers).get();
    final tiersMap = {for (final t in tiers) t.id: t.nom};

    Iterable<FacturesFournisseur> filtered = rows;
    if (estPayee != null) {
      filtered = filtered.where((f) => f.estPayee == estPayee);
    }
    if (dateFrom != null) {
      filtered = filtered.where((f) => !f.date.isBefore(dateFrom));
    }
    if (dateTo != null) {
      filtered = filtered.where((f) => !f.date.isAfter(dateTo));
    }
    if (search != null && search.trim().isNotEmpty) {
      final t = search.trim().toLowerCase();
      filtered = filtered.where(
        (f) =>
            f.numero.toLowerCase().contains(t) ||
            (tiersMap[f.fournisseurId]?.toLowerCase().contains(t) ?? false),
      );
    }

    final docs = filtered.skip(offset).take(limit).toList();
    if (docs.isEmpty) return [];
    final ids = docs.map((d) => d.id).toList();

    final brs = await (_db.select(_db.bonsReception)
          ..where((b) => b.factureFournisseurId.isIn(ids))
          ..orderBy([(b) => OrderingTerm.asc(b.date)]))
        .get();
    final brsByFacture = <int, List<String>>{};
    for (final b in brs) {
      brsByFacture.putIfAbsent(b.factureFournisseurId!, () => []).add(b.numero);
    }

    return [
      for (final f in docs)
        FactureFournisseurListItem(
          facture: f,
          fournisseurNom: tiersMap[f.fournisseurId] ?? '?',
          brNumeros: brsByFacture[f.id] ?? const [],
        ),
    ];
  }

  Future<
      ({
        FacturesFournisseur facture,
        List<DocumentLine> lines,
        List<LinkedDocument> brs,
      })?> getById(int id) async {
    final facture = await (_db.select(_db.facturesFournisseurs)
          ..where((f) => f.id.equals(id)))
        .getSingleOrNull();
    if (facture == null) return null;

    final lineRows = await (_db.select(_db.factureFournisseurLignes)
          ..where((l) => l.factureFournisseurId.equals(id))
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
    final references = await _referencesFor(lineRows.map((l) => l.produitId));
    final brRows = await (_db.select(_db.bonsReception)
          ..where((b) => b.factureFournisseurId.equals(id))
          ..orderBy([
            (b) => OrderingTerm.asc(b.date),
            (b) => OrderingTerm.asc(b.numero),
          ]))
        .get();

    return (
      facture: facture,
      lines: [
        for (final l in lineRows)
          DocumentLine(
            produitId: l.produitId,
            reference: references[l.produitId] ?? '',
            designation: l.designation,
            quantite: l.quantite,
            prixUnitaireHt: l.prixUnitaireHT,
            remise: l.remise,
            tauxTva: l.tauxTVA,
            bonReceptionId: l.bonReceptionId,
          ),
      ],
      brs: brRows.map(_toLinkedDocument).toList(),
    );
  }

  /// BRs of [fournisseurId] that are not invoiced yet (Peinture
  /// `GetAvailableBrsForFournisseurAsync`).
  Future<List<LinkedDocument>> availableBrsForFournisseur(
    int fournisseurId,
  ) async {
    final rows = await (_db.select(_db.bonsReception)
          ..where(
            (b) =>
                b.fournisseurId.equals(fournisseurId) &
                b.factureFournisseurId.isNull(),
          )
          ..orderBy([
            (b) => OrderingTerm.asc(b.date),
            (b) => OrderingTerm.asc(b.numero),
          ]))
        .get();
    return rows.map(_toLinkedDocument).toList();
  }

  Future<LinkedDocument?> getBr(int brId) async {
    final br = await (_db.select(_db.bonsReception)
          ..where((b) => b.id.equals(brId)))
        .getSingleOrNull();
    return br == null ? null : _toLinkedDocument(br);
  }

  /// The BR's received quantities as facture lines (Peinture
  /// `LoadBrLinesAsync`).
  Future<List<DocumentLine>> loadBrLines(int brId) async {
    final rows = await (_db.select(_db.bonReceptionLignes)
          ..where((l) => l.bRId.equals(brId))
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
    final references = await _referencesFor(rows.map((l) => l.produitId));
    return [
      for (final l in rows)
        DocumentLine(
          produitId: l.produitId,
          reference: references[l.produitId] ?? '',
          designation: l.designation,
          quantite: l.quantiteRecue,
          prixUnitaireHt: l.prixUnitaireHT,
          tauxTva: l.tauxTVA,
          bonReceptionId: brId,
        ),
    ];
  }

  /// Creates or updates the facture with its lines, and links exactly [brIds]
  /// to it. Returns the facture id.
  ///
  /// No payments here: they live on the BRs, like the BL on the ventes side.
  /// [estPayee] stays a manual marker, as on `FactureClient`.
  Future<int> save({
    int? id,
    required int fournisseurId,
    required DateTime date,
    required DateTime dateEcheance,
    bool estPayee = false,
    double remiseGlobale = 0,
    String note = '',
    required List<DocumentLine> lines,
    List<int> brIds = const [],
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
    if (remiseGlobale < 0 || remiseGlobale > 100) {
      throw StateError('La remise globale doit être entre 0 et 100 %.');
    }
    final ttc =
        DocumentTotals.fromLines(validLines, remiseGlobale: remiseGlobale)
            .totalTtc;
    if (DocumentTotals.isEffectivelyZero(ttc)) {
      throw StateError('Le total TTC ne peut pas être nul.');
    }

    final linkedIds = brIds.toSet();
    return _db.transaction(() async {
      await _validateBrs(fournisseurId, linkedIds, factureId: id);

      final now = DateTime.now().toUtc();
      late int factureId;
      if (id == null) {
        factureId = await _db.into(_db.facturesFournisseurs).insert(
              FacturesFournisseursCompanion.insert(
                numero: await _numbers.nextFactureFournisseur(),
                fournisseurId: fournisseurId,
                date: date,
                dateEcheance: dateEcheance,
                estPayee: Value(estPayee),
                remiseGlobale: Value(remiseGlobale),
                totalTtc: Value(ttc),
                note: Value(note.trim()),
                createdAt: now,
                updatedAt: now,
                createdByUserId: Value(createdByUserId),
              ),
            );
      } else {
        factureId = id;
        await (_db.update(_db.facturesFournisseurs)
              ..where((f) => f.id.equals(id)))
            .write(
          FacturesFournisseursCompanion(
            fournisseurId: Value(fournisseurId),
            date: Value(date),
            dateEcheance: Value(dateEcheance),
            estPayee: Value(estPayee),
            remiseGlobale: Value(remiseGlobale),
            totalTtc: Value(ttc),
            note: Value(note.trim()),
            updatedAt: Value(now),
          ),
        );
        await (_db.delete(_db.factureFournisseurLignes)
              ..where((l) => l.factureFournisseurId.equals(id)))
            .go();
      }

      for (final line in validLines) {
        final brId = line.bonReceptionId;
        await _db.into(_db.factureFournisseurLignes).insert(
              FactureFournisseurLignesCompanion.insert(
                factureFournisseurId: factureId,
                bonReceptionId:
                    Value(brId != null && linkedIds.contains(brId) ? brId : null),
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

      await (_db.update(_db.bonsReception)
            ..where(
              (b) =>
                  b.factureFournisseurId.equals(factureId) &
                  b.id.isNotIn(linkedIds.toList()),
            ))
          .write(const BonsReceptionCompanion(factureFournisseurId: Value(null)));
      if (linkedIds.isNotEmpty) {
        await (_db.update(_db.bonsReception)
              ..where((b) => b.id.isIn(linkedIds.toList())))
            .write(BonsReceptionCompanion(factureFournisseurId: Value(factureId)));
      }

      return factureId;
    });
  }

  /// Deletes the facture with its lines and frees its BRs. The BRs keep their
  /// own payments, which now live on them.
  Future<void> delete(int id) async {
    await _db.transaction(() async {
      await (_db.update(_db.bonsReception)
            ..where((b) => b.factureFournisseurId.equals(id)))
          .write(const BonsReceptionCompanion(factureFournisseurId: Value(null)));
      await (_db.delete(_db.factureFournisseurLignes)
            ..where((l) => l.factureFournisseurId.equals(id)))
          .go();
      await (_db.delete(_db.facturesFournisseurs)
            ..where((f) => f.id.equals(id)))
          .go();
    });
  }

  /// Peinture `ValidateBrsForFactureFournisseurAsync`: BRs must exist, belong
  /// to the facture's supplier and not be invoiced by another facture.
  Future<void> _validateBrs(
    int fournisseurId,
    Set<int> brIds, {
    int? factureId,
  }) async {
    if (brIds.isEmpty) return;
    final brs = await (_db.select(_db.bonsReception)
          ..where((b) => b.id.isIn(brIds.toList())))
        .get();
    final errors = <String>[];
    final found = brs.map((b) => b.id).toSet();
    for (final id in brIds) {
      if (!found.contains(id)) errors.add('BR #$id introuvable.');
    }
    for (final b in brs) {
      if (b.fournisseurId != fournisseurId) {
        errors.add(
          '${b.numero} : le fournisseur ne correspond pas à celui de la facture.',
        );
      }
      if (b.factureFournisseurId != null && b.factureFournisseurId != factureId) {
        errors.add('${b.numero} est déjà facturé.');
      }
    }
    if (errors.isNotEmpty) throw StateError(errors.join('\n'));
  }

  Future<Map<int, String>> _referencesFor(Iterable<int> produitIds) async {
    final ids = produitIds.toSet().toList();
    if (ids.isEmpty) return {};
    final products =
        await (_db.select(_db.produits)..where((p) => p.id.isIn(ids))).get();
    return {for (final p in products) p.id: p.reference};
  }

  static LinkedDocument _toLinkedDocument(BonsReceptionData b) =>
      LinkedDocument(
        id: b.id,
        numero: b.numero,
        date: b.date,
        totalTtc: b.totalTtc,
      );
}
