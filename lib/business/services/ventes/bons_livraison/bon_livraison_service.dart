import 'package:drift/drift.dart';
import 'package:fes_distribution/business/enums/mode_paiement.dart';
import 'package:fes_distribution/business/enums/user_type.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/bon_livraison_list_item.dart';
import 'package:fes_distribution/business/models/bon_livraison_paiement.dart';
import 'package:fes_distribution/business/models/personnel_document_line.dart';
import 'package:fes_distribution/business/services/stock/parametres/document_number_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/db/app_database.dart';

/// Bon de livraison = sale to a client. Goods always leave the vendeur's car
/// (never a physical depot); client payments are recorded on the BL.
class BonLivraisonService {
  BonLivraisonService(
    this._db,
    this._numbers,
    this._locations,
    this._stock,
  );

  final AppDatabase _db;
  final DocumentNumberService _numbers;
  final StockLocationService _locations;
  final StockMovementService _stock;

  Future<List<BonLivraisonListItem>> list({
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await (_db.select(_db.bonsLivraison)
          ..orderBy([
            (b) => OrderingTerm.desc(b.date),
            (b) => OrderingTerm.desc(b.id),
          ]))
        .get();

    final clients = await _db.select(_db.tiers).get();
    final clientMap = {for (final c in clients) c.id: c.nom};
    final users = await _db.select(_db.users).get();
    final userMap = {for (final u in users) u.id: u.fullName};

    Iterable<BonsLivraisonData> filtered = rows;
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
            (clientMap[b.clientId]?.toLowerCase().contains(t) ?? false) ||
            (userMap[b.vendeurId]?.toLowerCase().contains(t) ?? false),
      );
    }

    final docs = filtered.skip(offset).take(limit).toList();
    if (docs.isEmpty) return [];

    final paiements = await (_db.select(_db.paiementsBonLivraison)
          ..where((p) => p.bonLivraisonId.isIn(docs.map((d) => d.id).toList())))
        .get();
    final paidByBl = <int, double>{};
    for (final p in paiements) {
      paidByBl[p.bonLivraisonId] = (paidByBl[p.bonLivraisonId] ?? 0) + p.montant;
    }

    return [
      for (final d in docs)
        BonLivraisonListItem(
          bl: d,
          clientNom: clientMap[d.clientId] ?? '?',
          vendeurNom: userMap[d.vendeurId] ?? '',
          montantPaye: paidByBl[d.id] ?? 0,
        ),
    ];
  }

  Future<
      ({
        BonsLivraisonData bl,
        List<PersonnelDocumentLine> lines,
        List<BonLivraisonPaiement> paiements,
      })?> getById(int id) async {
    final bl = await (_db.select(_db.bonsLivraison)
          ..where((b) => b.id.equals(id)))
        .getSingleOrNull();
    if (bl == null) return null;

    final lineRows = await (_db.select(_db.bonLivraisonLignes)
          ..where((l) => l.bLId.equals(id))
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
    final productIds = lineRows.map((l) => l.produitId).toSet();
    final products = productIds.isEmpty
        ? <Produit>[]
        : await (_db.select(_db.produits)
              ..where((p) => p.id.isIn(productIds.toList())))
            .get();
    final productMap = {for (final p in products) p.id: p};

    final paiementRows = await (_db.select(_db.paiementsBonLivraison)
          ..where((p) => p.bonLivraisonId.equals(id))
          ..orderBy([
            (p) => OrderingTerm.desc(p.date),
            (p) => OrderingTerm.desc(p.id),
          ]))
        .get();

    return (
      bl: bl,
      lines: [
        for (final l in lineRows)
          PersonnelDocumentLine(
            produitId: l.produitId,
            reference: productMap[l.produitId]?.reference ?? '',
            designation: l.designation,
            quantite: l.quantiteLivree,
            prixUnitaireHt: l.prixUnitaireHT,
            remise: l.remise,
            tauxTva: l.tauxTVA,
          ),
      ],
      paiements: [
        for (final p in paiementRows)
          BonLivraisonPaiement(
            date: p.date,
            montant: p.montant,
            mode: ModePaiement.fromCode(p.mode),
            reference: p.reference,
          ),
      ],
    );
  }

  /// Creates or updates the BL with its lines and payments, then syncs the
  /// vendeur's car stock. Returns the BL id.
  Future<int> save({
    int? id,
    required int clientId,
    required int vendeurId,
    required DateTime date,
    required DateTime dateEcheance,
    double remiseGlobale = 0,
    String note = '',
    required List<PersonnelDocumentLine> lines,
    List<BonLivraisonPaiement> paiements = const [],
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
    if (paiements.any((p) => p.montant <= 0)) {
      throw StateError('Le montant doit être supérieur à 0.');
    }
    final totalPaye = paiements.fold<double>(0, (s, p) => s + p.montant);
    if (DocumentTotals.paymentsExceedTtc(ttc, totalPaye)) {
      throw StateError(
        'La somme des paiements (${totalPaye.toStringAsFixed(2)} TTC) ne peut pas '
        'dépasser le total du BL (${ttc.toStringAsFixed(2)} TTC).',
      );
    }

    return _db.transaction(() async {
      final vendeur = await _requireVendeur(vendeurId);
      final now = DateTime.now().toUtc();
      final estPayee = _computeEstPayee(ttc, paiements);
      late int blId;
      late String numero;

      if (id == null) {
        numero = await _numbers.nextBonLivraison();
        blId = await _db.into(_db.bonsLivraison).insert(
              BonsLivraisonCompanion.insert(
                numero: numero,
                clientId: clientId,
                vendeurId: Value(vendeurId),
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
        blId = id;
        final existing = await (_db.select(_db.bonsLivraison)
              ..where((b) => b.id.equals(id)))
            .getSingle();
        numero = existing.numero;
        await (_db.update(_db.bonsLivraison)..where((b) => b.id.equals(id)))
            .write(
          BonsLivraisonCompanion(
            clientId: Value(clientId),
            vendeurId: Value(vendeurId),
            date: Value(date),
            dateEcheance: Value(dateEcheance),
            estPayee: Value(estPayee),
            remiseGlobale: Value(remiseGlobale),
            totalTtc: Value(ttc),
            note: Value(note.trim()),
            updatedAt: Value(now),
          ),
        );
        await (_db.delete(_db.bonLivraisonLignes)
              ..where((l) => l.bLId.equals(id)))
            .go();
        await (_db.delete(_db.paiementsBonLivraison)
              ..where((p) => p.bonLivraisonId.equals(id)))
            .go();
      }

      for (final line in validLines) {
        await _db.into(_db.bonLivraisonLignes).insert(
              BonLivraisonLignesCompanion.insert(
                bLId: blId,
                produitId: line.produitId,
                designation: line.designation,
                quantiteCommandee: Value(line.quantite),
                quantiteLivree: Value(line.quantite),
                prixUnitaireHT: line.prixUnitaireHt,
                remise: Value(line.remise),
                tauxTVA: Value(line.tauxTva),
                createdAt: now,
                updatedAt: now,
                createdByUserId: Value(createdByUserId),
              ),
            );
      }

      for (final p in paiements) {
        await _db.into(_db.paiementsBonLivraison).insert(
              PaiementsBonLivraisonCompanion.insert(
                bonLivraisonId: blId,
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

      final car = await _locations.getOrCreateVirtualForUser(vendeur);
      await _stock.resyncBonLivraisonStock(
        bonLivraisonId: blId,
        noteDetail: numero,
        vendeurLocationId: car.id,
        lines: validLines
            .map((l) => (produitId: l.produitId, quantite: l.quantite)),
        createdByUserId: createdByUserId,
      );

      return blId;
    });
  }

  /// Deletes the BL and puts its goods back into the vendeur's car.
  /// Refused when the BL is already invoiced.
  Future<void> delete(int id, {int? createdByUserId}) async {
    await _db.transaction(() async {
      final bl = await (_db.select(_db.bonsLivraison)
            ..where((b) => b.id.equals(id)))
          .getSingle();
      if (bl.factureId != null) {
        final facture = await (_db.select(_db.factures)
              ..where((f) => f.id.equals(bl.factureId!)))
            .getSingleOrNull();
        throw StateError(
          'Impossible de supprimer ${bl.numero} : déjà facturé '
          '(${facture?.numero ?? '#${bl.factureId}'}).',
        );
      }

      final vendeurLocationId = await _vendeurLocationId(bl);
      if (vendeurLocationId != null) {
        await _stock.resyncBonLivraisonStock(
          bonLivraisonId: id,
          noteDetail: bl.numero,
          vendeurLocationId: vendeurLocationId,
          lines: const [],
          createdByUserId: createdByUserId,
        );
      }

      await (_db.delete(_db.paiementsBonLivraison)
            ..where((p) => p.bonLivraisonId.equals(id)))
          .go();
      await (_db.delete(_db.bonLivraisonLignes)..where((l) => l.bLId.equals(id)))
          .go();
      await (_db.delete(_db.bonsLivraison)..where((b) => b.id.equals(id))).go();
    });
  }

  Future<User> _requireVendeur(int vendeurId) async {
    final user = await (_db.select(_db.users)
          ..where(
            (u) => u.id.equals(vendeurId) & u.userType.equals(UserType.vendeur),
          ))
        .getSingleOrNull();
    if (user == null) throw StateError('Sélectionnez un vendeur.');
    return user;
  }

  /// The vendeur's car, or — when the vendeur no longer exists — the location
  /// this BL's stock movements were taken from.
  Future<int?> _vendeurLocationId(BonsLivraisonData bl) async {
    if (bl.vendeurId case final vendeurId?) {
      final user = await (_db.select(_db.users)
            ..where((u) => u.id.equals(vendeurId)))
          .getSingleOrNull();
      if (user != null && user.userType == UserType.vendeur) {
        return (await _locations.getOrCreateVirtualForUser(user)).id;
      }
    }
    final prior = await (_db.select(_db.mouvementsStock)
          ..where(
            (m) =>
                m.origineType
                    .equals(StockMovementService.origineTypeBonLivraison) &
                m.origineId.equals(bl.id) &
                m.fromLocationId.isNotNull(),
          )
          ..limit(1))
        .getSingleOrNull();
    return prior?.fromLocationId;
  }

  /// Credit payments do not count as paid (Peinture `SyncEstPayee`).
  static bool _computeEstPayee(double ttc, List<BonLivraisonPaiement> paiements) {
    final paid = paiements
        .where((p) => p.mode != ModePaiement.credit)
        .fold<double>(0, (s, p) => s + p.montant);
    return ttc > 0 && paid >= ttc - DocumentTotals.paiementTtcTolerance;
  }
}
