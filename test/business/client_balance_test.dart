import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/models/document_paiement.dart';
import 'package:fes_distribution/business/services/distribution/bons_charge/bon_charge_service.dart';
import 'package:fes_distribution/business/services/distribution/vendeurs/user_service.dart';
import 'package:fes_distribution/business/services/stock/parametres/document_number_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_balance_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/business/services/ventes/bons_livraison/bon_livraison_service.dart';
import 'package:fes_distribution/business/services/ventes/clients/tiers_service.dart';
import 'package:fes_distribution/business/services/ventes/solde_client/client_balance_service.dart';
import 'package:fes_distribution/db/app_database.dart';

void main() {
  late AppDatabase db;
  late StockLocationService locations;
  late StockBalanceService balance;
  late StockMovementService stock;
  late DocumentNumberService numbers;
  late BonLivraisonService bls;
  late ClientBalanceService balances;
  late int productId;

  DocumentLine line(double qty, {double ht = 100, double tva = 20}) =>
      DocumentLine(
        produitId: productId,
        designation: 'Peinture',
        quantite: qty,
        prixUnitaireHt: ht,
        tauxTva: tva,
      );

  /// A vendeur whose car is stocked, so a BL can actually be created.
  Future<int> vendeurAvecStock(String name, double qty) async {
    final vendeur = await UserService(db, locations)
        .createVendeur(fullName: name, phone: '0600${name.hashCode % 1000000}');
    await BonChargeService(db, numbers, locations, stock).save(
      assignedToUserId: vendeur.id,
      depotLocationId: 1,
      date: DateTime.now(),
      note: '',
      lines: [line(qty)],
    );
    return vendeur.id;
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    locations = StockLocationService(db);
    balance = StockBalanceService(db);
    stock = StockMovementService(db, balance);
    numbers = DocumentNumberService(db);
    bls = BonLivraisonService(db, numbers, locations, stock);
    balances = ClientBalanceService(db);

    final now = DateTime.now().toUtc();
    productId = await db.into(db.produits).insert(
          ProduitsCompanion.insert(
            reference: 'P-BAL',
            designation: 'Peinture',
            unite: 'U',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.mouvementsStock).insert(
          MouvementsStockCompanion.insert(
            produitId: productId,
            toLocationId: const Value(1),
            quantite: 1000,
            toApres: const Value(1000),
            origineType: 'Import',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('balance is BL totals minus payments, biggest debt first', () async {
    final client = await TiersService(db).createClient(nom: 'Alpha');
    final vendeurId = await vendeurAvecStock('Ahmed', 100);

    await bls.save(
      clientId: client.id,
      vendeurId: vendeurId,
      date: DateTime.now(),
      dateEcheance: DateTime.now().add(const Duration(days: 30)),
      lines: [line(5, ht: 200, tva: 0)], // 1 000 DH HT, no TVA
      paiements: [
        DocumentPaiement(date: DateTime.now(), montant: 400),
      ],
    );

    final row = (await balances.list()).single;
    expect(row.clientId, client.id);
    expect(row.totalLivraison, 1000);
    expect(row.totalPaye, 400);
    expect(row.totalAvoir, 0);
    expect(row.solde, 600);
    expect(row.doit, isTrue);
    expect(row.nbBl, 1);
  });

  test('settling the BL clears the client from the default list', () async {
    final client = await TiersService(db).createClient(nom: 'Beta');
    final vendeurId = await vendeurAvecStock('Ali', 100);

    await bls.save(
      clientId: client.id,
      vendeurId: vendeurId,
      date: DateTime.now(),
      dateEcheance: DateTime.now().add(const Duration(days: 30)),
      lines: [line(2, ht: 1000, tva: 0)], // 2 000 DH
      paiements: [
        DocumentPaiement(date: DateTime.now(), montant: 2000),
      ],
    );

    // The seeded default client owes nothing, so the debt list stays empty.
    expect(await balances.list(), isEmpty);
    final all = await balances.list(uniquementAvecSolde: false);
    final row = all.firstWhere((b) => b.clientId == client.id);
    expect(row.solde, 0);
    expect(row.doit, isFalse);
  });

  test('TVA is part of the total the client owes', () async {
    final client = await TiersService(db).createClient(nom: 'Gamma');
    final vendeurId = await vendeurAvecStock('Sara', 100);

    await bls.save(
      clientId: client.id,
      vendeurId: vendeurId,
      date: DateTime.now(),
      dateEcheance: DateTime.now().add(const Duration(days: 30)),
      lines: [line(1, ht: 500, tva: 20)], // 600 TTC
      paiements: [
        DocumentPaiement(date: DateTime.now(), montant: 100),
      ],
    );

    final row = (await balances.list()).single;
    expect(row.totalLivraison, 600);
    expect(row.solde, 500);
  });

  test('blDetails lists each BL with what was paid on it', () async {
    final client = await TiersService(db).createClient(nom: 'Delta');
    final vendeurId = await vendeurAvecStock('Nabil', 100);

    final first = await bls.save(
      clientId: client.id,
      vendeurId: vendeurId,
      date: DateTime.now().subtract(const Duration(days: 2)),
      dateEcheance: DateTime.now().add(const Duration(days: 30)),
      lines: [line(1, ht: 300, tva: 0)],
      paiements: [
        DocumentPaiement(date: DateTime.now(), montant: 100),
      ],
    );
    final second = await bls.save(
      clientId: client.id,
      vendeurId: vendeurId,
      date: DateTime.now(),
      dateEcheance: DateTime.now().add(const Duration(days: 30)),
      lines: [line(2, ht: 200, tva: 0)],
    );

    final lines = await balances.blDetails(client.id);
    expect(lines.length, 2);
    // Newest first.
    expect(lines.first.blId, second);
    expect(lines.first.totalTtc, 400);
    expect(lines.first.totalPaye, 0);
    expect(lines.first.reste, 400);

    final older = lines.last;
    expect(older.blId, first);
    expect(older.totalTtc, 300);
    expect(older.totalPaye, 100);
    expect(older.reste, 200);
  });

  test('search filters on the client name and debts sort descending',
      () async {
    final vendeurId = await vendeurAvecStock('Karim', 100);
    final petit = await TiersService(db).createClient(nom: 'Petit');
    final gros = await TiersService(db).createClient(nom: 'Grosalpha');

    for (final entry in {gros: 20.0, petit: 2.0}.entries) {
      await bls.save(
        clientId: entry.key.id,
        vendeurId: vendeurId,
        date: DateTime.now(),
        dateEcheance: DateTime.now().add(const Duration(days: 30)),
        lines: [line(entry.value, ht: 100, tva: 0)],
      );
    }

    final rows = await balances.list();
    expect(rows.first.clientId, gros.id);
    expect(rows.last.clientId, petit.id);

    final filtered = await balances.list(search: 'gros');
    expect(filtered.map((b) => b.clientId), [gros.id]);
  });

  test('a supplier is never part of the client balances', () async {
    await TiersService(db).createFournisseur(nom: 'Fournisseur X');
    final all = await balances.list(uniquementAvecSolde: false);
    expect(all.map((b) => b.clientNom), isNot(contains('Fournisseur X')));
  });
}