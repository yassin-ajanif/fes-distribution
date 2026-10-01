import 'package:drift/drift.dart';
import 'package:fes_distribution/business/enums/type_tiers.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/client_balance.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/db/app_database.dart';

/// What each client still owes.
///
/// Every sale leaves through a BL and payments are recorded on the BL itself
/// (a facture only groups BLs and carries no payments), so the balance is
/// simply: sum of BL totals − sum of BL payments − sum of avoir totals.
class ClientBalanceService {
  ClientBalanceService(this._db);

  final AppDatabase _db;

  /// One row per active client, biggest debt first.
  ///
  /// [uniquementAvecSolde] hides clients who owe nothing, and [search] filters
  /// on the client name.
  Future<List<ClientBalance>> list({
    String? search,
    bool uniquementAvecSolde = true,
  }) async {
    final clients = await (_db.select(_db.tiers)
          ..where(
            (t) =>
                t.actif.equals(true) &
                t.type.isIn(const [TypeTiers.client, TypeTiers.lesDeux]),
          ))
        .get();
    if (clients.isEmpty) return [];

    var balances = await _compute(clients);

    if (search != null && search.trim().isNotEmpty) {
      final t = search.trim().toLowerCase();
      balances = balances
          .where((b) => b.clientNom.toLowerCase().contains(t))
          .toList();
    }
    if (uniquementAvecSolde) {
      balances = balances.where((b) => b.doit).toList();
    }

    balances.sort((a, b) {
      final bySolde = b.solde.compareTo(a.solde);
      if (bySolde != 0) return bySolde;
      return a.clientNom.toLowerCase().compareTo(b.clientNom.toLowerCase());
    });
    return balances;
  }

  /// Balance of a single client, whatever their type or active flag.
  Future<ClientBalance?> get(int clientId) async {
    final client = await (_db.select(_db.tiers)..where((t) => t.id.equals(clientId)))
        .getSingleOrNull();
    if (client == null) return null;
    final balances = await _compute([client]);
    return balances.isEmpty ? null : balances.first;
  }

  /// The BLs behind one client's balance, newest first.
  ///
  /// Credit notes are not listed per BL: an avoir points at a facture, which
  /// may group several BLs, so it can only be deducted at the client level.
  Future<List<ClientBlLine>> blDetails(int clientId) async {
    final bls = await (_db.select(_db.bonsLivraison)
          ..where((b) => b.clientId.equals(clientId))
          ..orderBy([
            (b) => OrderingTerm.desc(b.date),
            (b) => OrderingTerm.desc(b.id),
          ]))
        .get();
    if (bls.isEmpty) return [];

    final paiements = await (_db.select(_db.paiementsBonLivraison)
          ..where((p) => p.bonLivraisonId.isIn(bls.map((b) => b.id).toList())))
        .get();
    final paidByBl = <int, double>{};
    for (final p in paiements) {
      paidByBl[p.bonLivraisonId] = (paidByBl[p.bonLivraisonId] ?? 0) + p.montant;
    }

    return [
      for (final b in bls)
        ClientBlLine(
          blId: b.id,
          numero: b.numero,
          date: b.date,
          totalTtc: b.totalTtc,
          totalPaye: paidByBl[b.id] ?? 0,
        ),
    ];
  }

  Future<List<ClientBalance>> _compute(List<Tier> clients) async {
    final clientIds = clients.map((c) => c.id).toList();

    final livraisonByClient = <int, double>{};
    final nbBlByClient = <int, int>{};
    final clientIdByBl = <int, int>{};

    final bls = await (_db.select(_db.bonsLivraison)
          ..where((b) => b.clientId.isIn(clientIds)))
        .get();
    final blIds = <int>[];
    for (final b in bls) {
      livraisonByClient[b.clientId] =
          (livraisonByClient[b.clientId] ?? 0) + b.totalTtc;
      nbBlByClient[b.clientId] = (nbBlByClient[b.clientId] ?? 0) + 1;
      clientIdByBl[b.id] = b.clientId;
      blIds.add(b.id);
    }

    final payeByClient = <int, double>{};
    if (blIds.isNotEmpty) {
      final paiements = await (_db.select(_db.paiementsBonLivraison)
            ..where((p) => p.bonLivraisonId.isIn(blIds)))
          .get();
      for (final p in paiements) {
        final clientId = clientIdByBl[p.bonLivraisonId];
        if (clientId == null) continue;
        payeByClient[clientId] = (payeByClient[clientId] ?? 0) + p.montant;
      }
    }

    final avoirByClient = await _avoirTtcByClient(clientIds);

    return [
      for (final c in clients)
        ClientBalance(
          clientId: c.id,
          clientNom: c.nom,
          totalLivraison: livraisonByClient[c.id] ?? 0,
          totalPaye: payeByClient[c.id] ?? 0,
          totalAvoir: avoirByClient[c.id] ?? 0,
          nbBl: nbBlByClient[c.id] ?? 0,
        ),
    ];
  }

  Future<Map<int, double>> _avoirTtcByClient(List<int> clientIds) async {
    final avoirs = await (_db.select(_db.avoirs)
          ..where((a) => a.clientId.isIn(clientIds)))
        .get();
    if (avoirs.isEmpty) return {};

    final lignes = await (_db.select(_db.avoirLignes)
          ..where((l) => l.avoirId.isIn(avoirs.map((a) => a.id).toList())))
        .get();
    final lignesByAvoir = <int, List<DocumentLine>>{};
    for (final l in lignes) {
      lignesByAvoir.putIfAbsent(l.avoirId, () => []).add(
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
      totals[a.clientId] = (totals[a.clientId] ?? 0) +
          DocumentTotals.fromLines(lines).totalTtc;
    }
    return totals;
  }
}