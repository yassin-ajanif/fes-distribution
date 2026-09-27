import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fes_distribution/business/enums/mode_paiement.dart';
import 'package:fes_distribution/business/models/bon_livraison_paiement.dart';
import 'package:fes_distribution/business/models/personnel_document_line.dart';
import 'package:fes_distribution/business/services/distribution/bons_charge/bon_charge_service.dart';
import 'package:fes_distribution/business/services/distribution/vendeurs/user_service.dart';
import 'package:fes_distribution/business/services/stock/parametres/document_number_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_balance_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/business/services/ventes/bons_livraison/bon_livraison_service.dart';
import 'package:fes_distribution/business/services/ventes/clients/tiers_service.dart';
import 'package:fes_distribution/db/app_database.dart';

void main() {
  late AppDatabase db;
  late StockLocationService locations;
  late StockBalanceService balance;
  late StockMovementService stock;
  late DocumentNumberService numbers;
  late BonLivraisonService service;
  late int productId;
  late int clientId;

  PersonnelDocumentLine line(double qty) => PersonnelDocumentLine(
        produitId: productId,
        designation: 'Peinture blanche',
        quantite: qty,
        prixUnitaireHt: 100,
        tauxTva: 20,
      );

  Future<User> vendeurWithCar(String name, String phone, double qty) async {
    final vendeur = await UserService(db, locations)
        .createVendeur(fullName: name, phone: phone);
    await BonChargeService(db, numbers, locations, stock).save(
      assignedToUserId: vendeur.id,
      depotLocationId: 1,
      date: DateTime.now(),
      note: '',
      lines: [line(qty)],
    );
    return vendeur;
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    locations = StockLocationService(db);
    balance = StockBalanceService(db);
    stock = StockMovementService(db, balance);
    numbers = DocumentNumberService(db);
    service = BonLivraisonService(db, numbers, locations, stock);

    final now = DateTime.now().toUtc();
    productId = await db.into(db.produits).insert(
          ProduitsCompanion.insert(
            reference: 'P-BL',
            designation: 'Peinture blanche',
            unite: 'U',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.mouvementsStock).insert(
          MouvementsStockCompanion.insert(
            produitId: productId,
            toLocationId: const Value(1),
            quantite: 100,
            toApres: const Value(100),
            origineType: 'Import',
            createdAt: now,
            updatedAt: now,
          ),
        );
    clientId = (await TiersService(db).createClient(nom: 'Client A')).id;
  });

  tearDown(() async {
    await db.close();
  });

  test('BL takes goods from the vendeur car, edit and delete resync it',
      () async {
    final vendeur = await vendeurWithCar('Ahmed', '0600000001', 20);
    final car = await locations.getOrCreateVirtualForUser(vendeur);
    expect(await balance.getStock(productId, car.id), 20);

    final id = await service.save(
      clientId: clientId,
      vendeurId: vendeur.id,
      date: DateTime.now(),
      dateEcheance: DateTime.now().add(const Duration(days: 30)),
      lines: [line(6)],
    );
    expect(await balance.getStock(productId, car.id), 14);
    expect(await balance.getStock(productId, 1), 80);

    final saved = await service.getById(id);
    expect(saved!.bl.numero, startsWith('BL-'));
    expect(saved.bl.totalTtc, closeTo(720, 0.001));

    await service.save(
      id: id,
      clientId: clientId,
      vendeurId: vendeur.id,
      date: DateTime.now(),
      dateEcheance: DateTime.now(),
      lines: [line(4)],
    );
    expect(await balance.getStock(productId, car.id), 16);

    await service.delete(id);
    expect(await balance.getStock(productId, car.id), 20);
    expect(await service.list(), isEmpty);
  });

  test('changing the vendeur returns goods to the old car', () async {
    final a = await vendeurWithCar('A', '0600000002', 10);
    final b = await vendeurWithCar('B', '0600000003', 10);
    final carA = await locations.getOrCreateVirtualForUser(a);
    final carB = await locations.getOrCreateVirtualForUser(b);

    final id = await service.save(
      clientId: clientId,
      vendeurId: a.id,
      date: DateTime.now(),
      dateEcheance: DateTime.now(),
      lines: [line(3)],
    );
    expect(await balance.getStock(productId, carA.id), 7);

    await service.save(
      id: id,
      clientId: clientId,
      vendeurId: b.id,
      date: DateTime.now(),
      dateEcheance: DateTime.now(),
      lines: [line(3)],
    );
    expect(await balance.getStock(productId, carA.id), 10);
    expect(await balance.getStock(productId, carB.id), 7);
  });

  test('payments: EstPayee ignores credit, total cannot exceed TTC', () async {
    final vendeur = await vendeurWithCar('C', '0600000004', 10);
    final today = DateTime.now();

    final id = await service.save(
      clientId: clientId,
      vendeurId: vendeur.id,
      date: today,
      dateEcheance: today,
      lines: [line(1)],
      paiements: [
        BonLivraisonPaiement(date: today, montant: 100),
        BonLivraisonPaiement(
          date: today,
          montant: 20,
          mode: ModePaiement.credit,
        ),
      ],
    );
    var saved = await service.getById(id);
    expect(saved!.paiements, hasLength(2));
    expect(saved.bl.estPayee, isFalse);

    await service.save(
      id: id,
      clientId: clientId,
      vendeurId: vendeur.id,
      date: today,
      dateEcheance: today,
      lines: [line(1)],
      paiements: [BonLivraisonPaiement(date: today, montant: 120)],
    );
    saved = await service.getById(id);
    expect(saved!.bl.estPayee, isTrue);
    expect((await service.list()).single.montantPaye, 120);

    expect(
      () => service.save(
        id: id,
        clientId: clientId,
        vendeurId: vendeur.id,
        date: today,
        dateEcheance: today,
        lines: [line(1)],
        paiements: [BonLivraisonPaiement(date: today, montant: 200)],
      ),
      throwsStateError,
    );
  });
}
