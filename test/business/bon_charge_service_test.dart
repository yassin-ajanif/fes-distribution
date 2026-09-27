import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fes_distribution/business/models/personnel_document_line.dart';
import 'package:fes_distribution/business/services/distribution/bons_charge/bon_charge_service.dart';
import 'package:fes_distribution/business/services/distribution/bons_decharge/bon_decharge_service.dart';
import 'package:fes_distribution/business/services/stock/parametres/document_number_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_balance_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/business/services/distribution/vendeurs/user_service.dart';
import 'package:fes_distribution/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
  });

  tearDown(() async {
    await db.close();
  });

  test('bon charge transfers stock from depot to vendeur virtual location', () async {
    final now = DateTime.now().toUtc();
    final productId = await db.into(db.produits).insert(
          ProduitsCompanion.insert(
            reference: 'P-100',
            designation: 'Test paint',
            unite: 'U',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.mouvementsStock).insert(
          MouvementsStockCompanion.insert(
            produitId: productId,
            toLocationId: const Value(1),
            quantite: 50,
            toApres: const Value(50),
            origineType: 'Import',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final locations = StockLocationService(db);
    final balance = StockBalanceService(db);
    final users = UserService(db, locations);
    final vendeur = await users.createVendeur(
      fullName: 'Ahmed',
      phone: '0612345678',
    );
    final virtualLoc = await locations.getOrCreateVirtualForUser(vendeur);

    final service = BonChargeService(
      db,
      DocumentNumberService(db),
      locations,
      StockMovementService(db, balance),
    );

    await service.save(
      assignedToUserId: vendeur.id,
      depotLocationId: 1,
      date: DateTime.now(),
      note: '',
      lines: [
        PersonnelDocumentLine(
          produitId: productId,
          designation: 'Test paint',
          quantite: 10,
          prixUnitaireHt: 100,
          tauxTva: 20,
        ),
      ],
    );

    expect(await balance.getStock(productId, 1), 40);
    expect(await balance.getStock(productId, virtualLoc.id), 10);

    final list = await service.list();
    expect(list, hasLength(1));
    await service.delete(list.first.bon.id);

    expect(await balance.getStock(productId, 1), 50);
    expect(await balance.getStock(productId, virtualLoc.id), 0);
  });

  test('bon décharge returns unsold goods from the car to a depot', () async {
    final now = DateTime.now().toUtc();
    final productId = await db.into(db.produits).insert(
          ProduitsCompanion.insert(
            reference: 'P-200',
            designation: 'Vernis',
            unite: 'U',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.mouvementsStock).insert(
          MouvementsStockCompanion.insert(
            produitId: productId,
            toLocationId: const Value(1),
            quantite: 30,
            toApres: const Value(30),
            origineType: 'Import',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final locations = StockLocationService(db);
    final balance = StockBalanceService(db);
    final stock = StockMovementService(db, balance);
    final numbers = DocumentNumberService(db);
    final vendeur = await UserService(db, locations)
        .createVendeur(fullName: 'Salah', phone: '0611558899');
    final car = await locations.getOrCreateVirtualForUser(vendeur);
    final depot2 = await locations.createPhysicalLocation('Dépôt 2');

    final line = PersonnelDocumentLine(
      produitId: productId,
      designation: 'Vernis',
      quantite: 12,
      prixUnitaireHt: 50,
      tauxTva: 20,
    );
    await BonChargeService(db, numbers, locations, stock).save(
      assignedToUserId: vendeur.id,
      depotLocationId: 1,
      date: DateTime.now(),
      note: '',
      lines: [line],
    );
    expect(await balance.getStock(productId, car.id), 12);

    final decharges = BonDechargeService(db, numbers, locations, stock);
    final id = await decharges.save(
      assignedToUserId: vendeur.id,
      depotLocationId: depot2.id,
      date: DateTime.now(),
      note: 'fin de tournée',
      lines: [line.copyWith(quantite: 5)],
    );
    expect(await balance.getStock(productId, car.id), 7);
    expect(await balance.getStock(productId, depot2.id), 5);
    expect(await balance.getStock(productId, 1), 18);

    await decharges.save(
      id: id,
      assignedToUserId: vendeur.id,
      depotLocationId: depot2.id,
      date: DateTime.now(),
      note: '',
      lines: [line.copyWith(quantite: 7)],
    );
    expect(await balance.getStock(productId, car.id), 5);
    expect(await balance.getStock(productId, depot2.id), 7);

    await decharges.delete(id);
    expect(await balance.getStock(productId, car.id), 12);
    expect(await balance.getStock(productId, depot2.id), 0);
  });
}
