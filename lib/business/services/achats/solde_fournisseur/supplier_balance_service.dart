import 'package:drift/drift.dart';
import 'package:fes_distribution/business/enums/type_tiers.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/models/supplier_balance.dart';
import 'package:fes_distribution/db/app_database.dart';

/// What we still owe each supplier.
///
/// Stock enters the depot on a BR, which is not yet a debt until it is
/// invoiced; the debt itself is the facture, and that is where supplier
/// payments are recorded. A facture's TTC already contains the BRs it groups,
/// so only the BRs *not* linked to a facture are added separately.
class SupplierBalanceService {
  SupplierBalanceService(this._db);

  final AppDatabase _db;

  /// One row per active supplier, biggest debt first.
  Future<List<SupplierBalance>> list({
    String? search,
    bool uniquementAvecSolde = true,
  }) async {
    final fournisseurs = await (_db.select(_db.tiers)
          ..where(
            (t) =>
                t.actif.equals(true) &
                t.type.isIn(const [TypeTiers.fournisseur, TypeTiers.lesDeux]),
          ))
        .get();
    if (fournisseurs.isEmpty) return [];

    var balances = await _compute(fournisseurs);

    if (search != null && search.trim().isNotEmpty) {
      final t = search.trim().toLowerCase();
      balances = balances
          .where((b) => b.fournisseurNom.toLowerCase().contains(t))
          .toList();
    }
    if (uniquementAvecSolde) {
      balances = balances.where((b) => b.doit).toList();
    }

    balances.sort((a, b) {
      final bySolde = b.solde.compareTo(a.solde);
      if (bySolde != 0) return bySolde;
      return a.fournisseurNom.toLowerCase().compareTo(b.fournisseurNom.toLowerCase());
    });
    return balances;
  }

  /// Balance of a single supplier, whatever their type or active flag.
  Future<SupplierBalance?> get(int fournisseurId) async {
    final fournisseur =
        await (_db.select(_db.tiers)..where((t) => t.id.equals(fournisseurId)))
            .getSingleOrNull();
    if (fournisseur == null) return null;
    final balances = await _compute([fournisseur]);
    return balances.isEmpty ? null : balances.first;
  }

  /// The invoices and uninvoiced BRs behind one supplier's balance, newest
  /// first.
  ///
  /// Credit notes are not attributed to a document: a supplier avoir has no
  /// link to a facture, so it is only deducted at the supplier level.
  Future<List<SupplierBalanceLine>> documentDetails(int fournisseurId) async {
    final factures = await (_db.select(_db.facturesFournisseurs)
          ..where((f) => f.fournisseurId.equals(fournisseurId))
          ..orderBy([
            (f) => OrderingTerm.desc(f.date),
            (f) => OrderingTerm.desc(f.id),
          ]))
        .get();

    final paidByFacture = <int, double>{};
    if (factures.isNotEmpty) {
      final paiements = await (_db.select(_db.paiementsFournisseurs)
            ..where(
              (p) => p.factureFournisseurId
                  .isIn(factures.map((f) => f.id).toList()),
            ))
          .get();
      for (final p in paiements) {
        paidByFacture[p.factureFournisseurId] =
            (paidByFacture[p.factureFournisseurId] ?? 0) + p.montant;
      }
    }

    final brs = await (_db.select(_db.bonsReception)
          ..where(
            (b) =>
                b.fournisseurId.equals(fournisseurId) &
                b.factureFournisseurId.isNull(),
          )
          ..orderBy([
            (b) => OrderingTerm.desc(b.date),
            (b) => OrderingTerm.desc(b.id),
          ]))
        .get();

    final lines = <SupplierBalanceLine>[
      for (final f in factures)
        SupplierBalanceLine(
          documentId: f.id,
          kind: SupplierDocumentKind.facture,
          numero: f.numero,
          date: f.date,
          totalTtc: f.totalTtc,
          totalPaye: paidByFacture[f.id] ?? 0,
        ),
      for (final b in brs)
        SupplierBalanceLine(
          documentId: b.id,
          kind: SupplierDocumentKind.bonReception,
          numero: b.numero,
          date: b.date,
          totalTtc: b.totalTtc,
          totalPaye: 0,
        ),
    ];
    lines.sort((a, b) => b.date.compareTo(a.date));
    return lines;
  }

  Future<List<SupplierBalance>> _compute(List<Tier> fournisseurs) async {
    final ids = fournisseurs.map((f) => f.id).toList();

    final factureByFournisseur = <int, double>{};
    final nbFacture = <int, int>{};
    final fournisseurByFacture = <int, int>{};
    final factureIds = <int>[];

    final factures = await (_db.select(_db.facturesFournisseurs)
          ..where((f) => f.fournisseurId.isIn(ids)))
        .get();
    for (final f in factures) {
      factureByFournisseur[f.fournisseurId] =
          (factureByFournisseur[f.fournisseurId] ?? 0) + f.totalTtc;
      nbFacture[f.fournisseurId] = (nbFacture[f.fournisseurId] ?? 0) + 1;
      fournisseurByFacture[f.id] = f.fournisseurId;
      factureIds.add(f.id);
    }

    final payeByFournisseur = <int, double>{};
    if (factureIds.isNotEmpty) {
      final paiements = await (_db.select(_db.paiementsFournisseurs)
            ..where((p) => p.factureFournisseurId.isIn(factureIds)))
          .get();
      for (final p in paiements) {
        final fournisseurId = fournisseurByFacture[p.factureFournisseurId];
        if (fournisseurId == null) continue;
        payeByFournisseur[fournisseurId] =
            (payeByFournisseur[fournisseurId] ?? 0) + p.montant;
      }
    }

    // Only the BRs no facture covers yet: an invoiced BR is already inside its
    // facture's total and adding it again would double-count.
    final brByFournisseur = <int, double>{};
    final nbBr = <int, int>{};
    final brs = await (_db.select(_db.bonsReception)
          ..where((b) => b.fournisseurId.isIn(ids) & b.factureFournisseurId.isNull()))
        .get();
    for (final b in brs) {
      brByFournisseur[b.fournisseurId] =
          (brByFournisseur[b.fournisseurId] ?? 0) + b.totalTtc;
      nbBr[b.fournisseurId] = (nbBr[b.fournisseurId] ?? 0) + 1;
    }

    final avoirByFournisseur = await _avoirTtcByFournisseur(ids);

    return [
      for (final f in fournisseurs)
        SupplierBalance(
          fournisseurId: f.id,
          fournisseurNom: f.nom,
          totalFacture: factureByFournisseur[f.id] ?? 0,
          totalBrNonFacture: brByFournisseur[f.id] ?? 0,
          totalPaye: payeByFournisseur[f.id] ?? 0,
          totalAvoir: avoirByFournisseur[f.id] ?? 0,
          nbFacture: nbFacture[f.id] ?? 0,
          nbBrNonFacture: nbBr[f.id] ?? 0,
        ),
    ];
  }

  Future<Map<int, double>> _avoirTtcByFournisseur(List<int> ids) async {
    final avoirs = await (_db.select(_db.avoirsFournisseurs)
          ..where((a) => a.fournisseurId.isIn(ids)))
        .get();
    if (avoirs.isEmpty) return {};

    final lignes = await (_db.select(_db.avoirFournisseurLignes)
          ..where((l) => l.avoirFournisseurId
              .isIn(avoirs.map((a) => a.id).toList())))
        .get();
    final lignesByAvoir = <int, List<DocumentLine>>{};
    for (final l in lignes) {
      lignesByAvoir.putIfAbsent(l.avoirFournisseurId, () => []).add(
            DocumentLine(
              produitId: l.produitId,
              designation: l.designation,
              quantite: l.quantite,
              prixUnitaireHt: l.prixUnitaireHT,
              remise: l.remise,
              tauxTva: l.tauxTVA,
            ),
          );
    }

    final totals = <int, double>{};
    for (final a in avoirs) {
      final lines = lignesByAvoir[a.id];
      if (lines == null) continue;
      totals[a.fournisseurId] = (totals[a.fournisseurId] ?? 0) +
          DocumentTotals.fromLines(lines).totalTtc;
    }
    return totals;
  }
}