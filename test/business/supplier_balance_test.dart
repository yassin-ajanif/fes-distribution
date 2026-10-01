import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/models/document_paiement.dart';
import 'package:fes_distribution/business/models/supplier_balance.dart';
import 'package:fes_distribution/business/services/achats/avoirs_fournisseur/avoir_fournisseur_service.dart';
import 'package:fes_distribution/business/services/achats/bons_reception/bon_reception_service.dart';
import 'package:fes_distribution/business/services/achats/factures_fournisseur/facture_fournisseur_service.dart';
import 'package:fes_distribution/business/services/achats/solde_fournisseur/supplier_balance_service.dart';
import 'package:fes_distribution/business/services/stock/parametres/document_number_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_balance_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/business/services/ventes/clients/tiers_service.dart';
import 'package:fes_distribution/db/app_database.dart';

void main() {
  late AppDatabase db;
  late BonReceptionService brs;
  late FactureFournisseurService factures;
  late AvoirFournisseurService avoirs;
  late SupplierBalanceService balances;
  late int productId;

  DocumentLine line(double qty, {double ht = 100, double tva = 0}) =>
      DocumentLine(
        produitId: productId,
        designation: 'Peinture',
        quantite: qty,
        prixUnitaireHt: ht,
        tauxTva: tva,
      );

  /// Receives goods without paying anything.
  Future<int> newBr(int fournisseurId, double qty, {double ht = 100}) =>
      brs.save(
        fournisseurId: fournisseurId,
        date: DateTime.now(),
        lines: [line(qty, ht: ht)],
      );

  /// Groups the given BRs onto one facture. The money stays on the BRs, so
  /// this must not change any balance.
  Future<int> invoiceBrs(int fournisseurId, List<int> brIds) async {
    final lines = <DocumentLine>[];
    for (final brId in brIds) {
      lines.addAll(await factures.loadBrLines(brId));
    }
    return factures.save(
      fournisseurId: fournisseurId,
      date: DateTime.now(),
      dateEcheance: DateTime.now().add(const Duration(days: 30)),
      lines: lines,
      brIds: brIds,
    );
  }

  Future<SupplierBalance> rowOf(int fournisseurId) async {
    final all = await balances.list(uniquementAvecSolde: false);
    return all.firstWhere((b) => b.fournisseurId == fournisseurId);
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    final locations = StockLocationService(db);
    final balance = StockBalanceService(db);
    final stock = StockMovementService(db, balance);
    final numbers = DocumentNumberService(db);
    brs = BonReceptionService(db, numbers, locations, stock);
    factures = FactureFournisseurService(db, numbers);
    avoirs = AvoirFournisseurService(db, numbers, locations, stock);
    balances = SupplierBalanceService(db);

    final now = DateTime.now().toUtc();
    productId = await db.into(db.produits).insert(
          ProduitsCompanion.insert(
            reference: 'P-SOLDE',
            designation: 'Peinture',
            unite: 'U',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('balance is BR totals minus payments, biggest debt first', () async {
    final a = await TiersService(db).createFournisseur(nom: 'Fournisseur A');
    final b = await TiersService(db).createFournisseur(nom: 'Fournisseur B');
    await brs.save(
      fournisseurId: a.id,
      date: DateTime.now(),
      lines: [line(5, ht: 200)], // 1 000 DH
      paiements: [DocumentPaiement(date: DateTime.now(), montant: 400)],
    );
    await newBr(b.id, 3); // 300 DH

    final list = await balances.list();
    expect(list.map((r) => r.fournisseurNom), ['Fournisseur A', 'Fournisseur B']);
    expect(list.first.solde, 600);
    expect(list.first.totalLivraison, 1000);
    expect(list.first.totalPaye, 400);
    expect(list.first.nbBr, 1);
    expect(list.first.doit, isTrue);
    expect(list.last.solde, 300);
  });

  test('invoicing a BR does not change the balance', () async {
    final a = await TiersService(db).createFournisseur(nom: 'Alpha');
    final brId = await newBr(a.id, 10); // 1 000 DH
    final before = await rowOf(a.id);

    await invoiceBrs(a.id, [brId]);

    // The facture groups the BR but carries no money of its own, so the debt is
    // still the BR's 1 000 — not 2 000, and not dropped either.
    final after = await rowOf(a.id);
    expect(after.solde, 1000);
    expect(after.totalLivraison, 1000);
    expect(after.nbBr, 1);
    expect(after.solde, before.solde);
  });

  test('a BR with no facture is still owed', () async {
    final a = await TiersService(db).createFournisseur(nom: 'Beta');
    await newBr(a.id, 4); // 400 DH, not invoiced yet

    final row = await rowOf(a.id);
    expect(row.totalLivraison, 400);
    expect(row.nbBr, 1);
    expect(row.solde, 400);
  });

  test('settling the BR clears the supplier from the default list', () async {
    final a = await TiersService(db).createFournisseur(nom: 'Gamma');
    await brs.save(
      fournisseurId: a.id,
      date: DateTime.now(),
      lines: [line(2)], // 200 DH
      paiements: [DocumentPaiement(date: DateTime.now(), montant: 200)],
    );

    expect(await balances.list(), isEmpty);
    final row = await rowOf(a.id);
    expect(row.solde, 0);
    expect(row.doit, isFalse);
  });

  test('TVA counts in the debt and credit notes reduce it', () async {
    final a = await TiersService(db).createFournisseur(nom: 'Delta');
    await brs.save(
      fournisseurId: a.id,
      date: DateTime.now(),
      lines: [line(1, ht: 500, tva: 20)], // 600 TTC
      paiements: [DocumentPaiement(date: DateTime.now(), montant: 100)],
    );
    await avoirs.save(
      fournisseurId: a.id,
      date: DateTime.now(),
      motif: 'Retour',
      retourMarchandise: false,
      lines: [line(1, ht: 200, tva: 0)], // 200 TTC
    );

    final row = await rowOf(a.id);
    expect(row.totalLivraison, 600);
    expect(row.totalPaye, 100);
    expect(row.totalAvoir, 200);
    expect(row.solde, 300);
  });

  test('details list BRs with their payments and invoice info', () async {
    final a = await TiersService(db).createFournisseur(nom: 'Epsilon');
    final br1 = await brs.save(
      fournisseurId: a.id,
      date: DateTime.now(),
      lines: [line(1)],
      paiements: [DocumentPaiement(date: DateTime.now(), montant: 40)],
    );
    await invoiceBrs(a.id, [br1]);
    final br2 = await newBr(a.id, 6); // 600 DH, not invoiced

    final lines = await balances.documentDetails(a.id);
    expect(lines, hasLength(2));

    final paid = lines.firstWhere((l) => l.brId == br1);
    expect(paid.totalTtc, 100);
    expect(paid.totalPaye, 40);
    expect(paid.reste, 60);
    expect(paid.factureNumero, startsWith('FAF-'));

    final unpaid = lines.firstWhere((l) => l.brId == br2);
    expect(unpaid.totalTtc, 600);
    expect(unpaid.totalPaye, 0);
    expect(unpaid.reste, 600);
    expect(unpaid.factureNumero, isNull);
  });

  test('search narrows the list and the all-toggle shows settled suppliers',
      () async {
    final a = await TiersService(db).createFournisseur(nom: 'Zeta');
    final b = await TiersService(db).createFournisseur(nom: 'Eta');
    await newBr(a.id, 5); // 500 DH, still owed
    await brs.save(
      fournisseurId: b.id,
      date: DateTime.now(),
      lines: [line(1)],
      paiements: [DocumentPaiement(date: DateTime.now(), montant: 100)],
    );

    expect((await balances.list(search: 'zet')).single.fournisseurId, a.id);
    expect(await balances.list(search: 'zzz'), isEmpty);

    final all = await balances.list(uniquementAvecSolde: false);
    expect(all.map((r) => r.solde), [500, 0]);
  });
}
