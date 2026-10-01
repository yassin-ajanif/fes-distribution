import 'package:drift/drift.dart';
import 'package:fes_distribution/business/enums/type_tiers.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/models/supplier_balance.dart';
import 'package:fes_distribution/db/app_database.dart';

/// What we still owe each supplier.
///
/// The mirror image of [ClientBalance]: BR totals − payments − credit notes.
/// Supplier payments live on the BR, so a BR counts as a debt as soon as the
/// goods are received, invoiced or not. A facture fournisseur only groups BRs
/// and carries no money, so it never enters the sum — which is what used to
/// require a special case to avoid counting an invoiced BR twice.
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
      return a.fournisseurNom
          .toLowerCase()
          .compareTo(b.fournisseurNom.toLowerCase());
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

  /// Every BR behind one supplier's balance, newest first.
  ///
  /// Credit notes are not attributed to a document: a supplier avoir has no
  /// link to a BR, so it is only deducted at the supplier level.
  Future<List<SupplierBalanceLine>> documentDetails(int fournisseurId) async {
    final brs = await (_db.select(_db.bonsReception)
          ..where((b) => b.fournisseurId.equals(fournisseurId))
          ..orderBy([
            (b) => OrderingTerm.desc(b.date),
            (b) => OrderingTerm.desc(b.id),
          ]))
        .get();
    if (brs.isEmpty) return [];

    final paidByBr = await _payeByBr(brs.map((b) => b.id).toList());

    final factureIds =
        brs.map((b) => b.factureFournisseurId).whereType<int>().toSet();
    final factures = factureIds.isEmpty
        ? <FacturesFournisseur>[]
        : await (_db.select(_db.facturesFournisseurs)
              ..where((f) => f.id.isIn(factureIds.toList())))
            .get();
    final factureMap = {for (final f in factures) f.id: f.numero};

    return [
      for (final b in brs)
        SupplierBalanceLine(
          brId: b.id,
          numero: b.numero,
          date: b.date,
          totalTtc: b.totalTtc,
          totalPaye: paidByBr[b.id] ?? 0,
          factureNumero: factureMap[b.factureFournisseurId],
        ),
    ];
  }

  Future<List<SupplierBalance>> _compute(List<Tier> fournisseurs) async {
    final ids = fournisseurs.map((f) => f.id).toList();

    final brs = await (_db.select(_db.bonsReception)
          ..where((b) => b.fournisseurId.isIn(ids)))
        .get();

    final totalByFournisseur = <int, double>{};
    final nbByFournisseur = <int, int>{};
    for (final b in brs) {
      totalByFournisseur[b.fournisseurId] =
          (totalByFournisseur[b.fournisseurId] ?? 0) + b.totalTtc;
      nbByFournisseur[b.fournisseurId] = (nbByFournisseur[b.fournisseurId] ?? 0) + 1;
    }

    final payeByFournisseur = <int, double>{};
    if (brs.isNotEmpty) {
      final fournisseurByBr = {for (final b in brs) b.id: b.fournisseurId};
      final paiements = await (_db.select(_db.paiementsFournisseurs)
            ..where((p) => p.bonReceptionId.isIn(fournisseurByBr.keys.toList())))
          .get();
      for (final p in paiements) {
        final fournisseurId = fournisseurByBr[p.bonReceptionId];
        if (fournisseurId == null) continue;
        payeByFournisseur[fournisseurId] =
            (payeByFournisseur[fournisseurId] ?? 0) + p.montant;
      }
    }

    final avoirByFournisseur = await _avoirTtcByFournisseur(ids);

    return [
      for (final f in fournisseurs)
        SupplierBalance(
          fournisseurId: f.id,
          fournisseurNom: f.nom,
          totalLivraison: totalByFournisseur[f.id] ?? 0,
          totalPaye: payeByFournisseur[f.id] ?? 0,
          totalAvoir: avoirByFournisseur[f.id] ?? 0,
          nbBr: nbByFournisseur[f.id] ?? 0,
        ),
    ];
  }

  Future<Map<int, double>> _payeByBr(List<int> brIds) async {
    final paiements = await (_db.select(_db.paiementsFournisseurs)
          ..where((p) => p.bonReceptionId.isIn(brIds)))
        .get();
    final paid = <int, double>{};
    for (final p in paiements) {
      paid[p.bonReceptionId] = (paid[p.bonReceptionId] ?? 0) + p.montant;
    }
    return paid;
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
