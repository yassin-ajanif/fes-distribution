import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fes_distribution/business/models/personnel_document_line.dart';
import 'package:fes_distribution/business/services/distribution/bons_charge/bon_charge_service.dart';
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
}
