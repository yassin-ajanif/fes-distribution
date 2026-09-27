import 'package:drift/drift.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/models/facture_list_item.dart';
import 'package:fes_distribution/business/models/linked_bl.dart';
import 'package:fes_distribution/business/services/stock/parametres/document_number_service.dart';
import 'package:fes_distribution/db/app_database.dart';

/// Client invoice. Groups one or more BLs of the same client (each BL can be
/// invoiced once) and/or free catalog lines. No stock impact — stock already
/// left the vendeur's car on the BL — and no payments (they live on the BL).
class FactureService {
  FactureService(this._db, this._numbers);

  final AppDatabase _db;
  final DocumentNumberService _numbers;

  /// [estPayee]: null = all, true = paid only, false = unpaid only.
  Future<List<FactureListItem>> list({
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool? estPayee,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await (_db.select(_db.factures)
          ..orderBy([
            (f) => OrderingTerm.desc(f.date),
            (f) => OrderingTerm.desc(f.id),
          ]))
        .get();
    final clients = await _db.select(_db.tiers).get();
    final clientMap = {for (final c in clients) c.id: c.nom};

    Iterable<Facture> filtered = rows;
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
            (clientMap[f.clientId]?.toLowerCase().contains(t) ?? false),
      );
    }

    final docs = filtered.skip(offset).take(limit).toList();
    if (docs.isEmpty) return [];

    final bls = await (_db.select(_db.bonsLivraison)
          ..where((b) => b.factureId.isIn(docs.map((d) => d.id).toList()))
          ..orderBy([(b) => OrderingTerm.asc(b.date)]))
        .get();
    final blsByFacture = <int, List<String>>{};
    for (final b in bls) {
      blsByFacture.putIfAbsent(b.factureId!, () => []).add(b.numero);
    }

    return [
      for (final f in docs)
        FactureListItem(
          facture: f,
          clientNom: clientMap[f.clientId] ?? '?',
          blNumeros: blsByFacture[f.id] ?? const [],
        ),
    ];
  }

  Future<({Facture facture, List<DocumentLine> lines, List<LinkedBl> bls})?>
      getById(int id) async {
    final facture = await (_db.select(_db.factures)
          ..where((f) => f.id.equals(id)))
        .getSingleOrNull();
    if (facture == null) return null;

    final lineRows = await (_db.select(_db.factureLignes)
          ..where((l) => l.factureId.equals(id))
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
    final references = await _referencesFor(lineRows.map((l) => l.produitId));
    final blRows = await (_db.select(_db.bonsLivraison)
          ..where((b) => b.factureId.equals(id))
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
            bonLivraisonId: l.bonLivraisonId,
          ),
      ],
      bls: blRows.map(_toLinkedBl).toList(),
    );
  }

  /// BLs of [clientId] that are not invoiced yet (Peinture
  /// `GetAvailableBlsForClientAsync`).
  Future<List<LinkedBl>> availableBlsForClient(int clientId) async {
    final rows = await (_db.select(_db.bonsLivraison)
          ..where((b) => b.clientId.equals(clientId) & b.factureId.isNull())
          ..orderBy([
            (b) => OrderingTerm.asc(b.date),
            (b) => OrderingTerm.asc(b.numero),
          ]))
        .get();
    return rows.map(_toLinkedBl).toList();
  }

  Future<LinkedBl?> getBl(int blId) async {
    final bl = await (_db.select(_db.bonsLivraison)
          ..where((b) => b.id.equals(blId)))
        .getSingleOrNull();
    return bl == null ? null : _toLinkedBl(bl);
  }

  /// The BL's delivered quantities as facture lines.
  Future<List<DocumentLine>> loadBlLines(int blId) async {
    final rows = await (_db.select(_db.bonLivraisonLignes)
          ..where((l) => l.bLId.equals(blId))
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
    final references = await _referencesFor(rows.map((l) => l.produitId));
    return [
      for (final l in rows)
        DocumentLine(
          produitId: l.produitId,
          reference: references[l.produitId] ?? '',
          designation: l.designation,
          quantite: l.quantiteLivree,
          prixUnitaireHt: l.prixUnitaireHT,
          remise: l.remise,
          tauxTva: l.tauxTVA,
          bonLivraisonId: blId,
        ),
    ];
  }

  /// Creates or updates the facture and links exactly [blIds] to it.
  /// Returns the facture id.
  Future<int> save({
    int? id,
    required int clientId,
    required DateTime date,
    required DateTime dateEcheance,
    bool estPayee = false,
    double remiseGlobale = 0,
    String bonCommandeReference = '',
    String note = '',
    required List<DocumentLine> lines,
    List<int> blIds = const [],
    int? createdByUserId,
  }) async {
    if (clientId <= 0) throw StateError('Sélectionnez un client.');
    final validLines =
        lines.where((l) => l.produitId > 0 && l.quantite > 0).toList();
    if (validLines.isEmpty) {
      throw StateError('Ajoutez au moins une ligne avec quantité.');
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

    final linkedIds = blIds.toSet();
    return _db.transaction(() async {
      await _validateBls(clientId, linkedIds, factureId: id);

      final now = DateTime.now().toUtc();
      late int factureId;
      if (id == null) {
        factureId = await _db.into(_db.factures).insert(
              FacturesCompanion.insert(
                numero: await _numbers.nextFacture(),
                clientId: clientId,
                date: date,
                dateEcheance: dateEcheance,
                estPayee: Value(estPayee),
                remiseGlobale: Value(remiseGlobale),
                totalTtc: Value(ttc),
                bonCommandeReference: Value(bonCommandeReference.trim()),
                note: Value(note.trim()),
                createdAt: now,
                updatedAt: now,
                createdByUserId: Value(createdByUserId),
              ),
            );
      } else {
        factureId = id;
        await (_db.update(_db.factures)..where((f) => f.id.equals(id))).write(
          FacturesCompanion(
            clientId: Value(clientId),
            date: Value(date),
            dateEcheance: Value(dateEcheance),
            estPayee: Value(estPayee),
            remiseGlobale: Value(remiseGlobale),
            totalTtc: Value(ttc),
            bonCommandeReference: Value(bonCommandeReference.trim()),
            note: Value(note.trim()),
            updatedAt: Value(now),
          ),
        );
        await (_db.delete(_db.factureLignes)
              ..where((l) => l.factureId.equals(id)))
            .go();
      }

      for (final line in validLines) {
        final blId = line.bonLivraisonId;
        await _db.into(_db.factureLignes).insert(
              FactureLignesCompanion.insert(
                factureId: factureId,
                bonLivraisonId:
                    Value(blId != null && linkedIds.contains(blId) ? blId : null),
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

      await (_db.update(_db.bonsLivraison)
            ..where(
              (b) =>
                  b.factureId.equals(factureId) & b.id.isNotIn(linkedIds.toList()),
            ))
          .write(const BonsLivraisonCompanion(factureId: Value(null)));
      if (linkedIds.isNotEmpty) {
        await (_db.update(_db.bonsLivraison)
              ..where((b) => b.id.isIn(linkedIds.toList())))
            .write(BonsLivraisonCompanion(factureId: Value(factureId)));
      }

      return factureId;
    });
  }

  /// Deletes the facture and frees its BLs. Refused when an avoir refers to it.
  Future<void> delete(int id) async {
    await _db.transaction(() async {
      final avoir = await (_db.select(_db.avoirs)
            ..where((a) => a.factureId.equals(id))
            ..limit(1))
          .getSingleOrNull();
      if (avoir != null) {
        throw StateError(
          'Impossible de supprimer : la facture est référencée par l\'avoir ${avoir.numero}.',
        );
      }
      await (_db.update(_db.bonsLivraison)..where((b) => b.factureId.equals(id)))
          .write(const BonsLivraisonCompanion(factureId: Value(null)));
      await (_db.delete(_db.factureLignes)..where((l) => l.factureId.equals(id)))
          .go();
      await (_db.delete(_db.factures)..where((f) => f.id.equals(id))).go();
    });
  }

  /// Peinture `ValidateBlsForFactureAsync`: BLs must exist, belong to the
  /// facture's client and not be invoiced by another facture.
  Future<void> _validateBls(
    int clientId,
    Set<int> blIds, {
    int? factureId,
  }) async {
    if (blIds.isEmpty) return;
    final bls = await (_db.select(_db.bonsLivraison)
          ..where((b) => b.id.isIn(blIds.toList())))
        .get();
    final errors = <String>[];
    final found = bls.map((b) => b.id).toSet();
    for (final id in blIds) {
      if (!found.contains(id)) errors.add('BL #$id introuvable.');
    }
    for (final b in bls) {
      if (b.clientId != clientId) {
        errors.add('${b.numero} : le client ne correspond pas à celui de la facture.');
      }
      if (b.factureId != null && b.factureId != factureId) {
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

  static LinkedBl _toLinkedBl(BonsLivraisonData b) => LinkedBl(
        id: b.id,
        numero: b.numero,
        date: b.date,
        totalTtc: b.totalTtc,
      );
}
