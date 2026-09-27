import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fes_distribution/business/models/produit_input.dart';
import 'package:fes_distribution/business/services/stock/produits/produit_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_balance_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/business/services/distribution/vendeurs/user_service.dart';
import 'package:fes_distribution/db/app_database.dart';

void main() {
  late AppDatabase db;
  late StockLocationService locations;
  late StockBalanceService balance;
  late StockMovementService movements;
  late int productId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    locations = StockLocationService(db);
    balance = StockBalanceService(db);
    movements = StockMovementService(db, balance);
    productId = await ProduitService(db).create(
      const ProduitInput(reference: 'P-1', designation: 'Peinture blanche'),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('adjustment adds and removes stock at one location', () async {
    await movements.applyAdjustment(produitId: productId, locationId: 1, delta: 30);
    expect(await balance.getStock(productId, 1), 30);

    await movements.applyAdjustment(produitId: productId, locationId: 1, delta: -5);
    expect(await balance.getStock(productId, 1), 25);
    expect(await balance.getAllStocksAtLocation(1), {productId: 25});
  });

  test('transfer moves stock between two physical depots', () async {
    final depot2 = await locations.createPhysicalLocation('Dépôt Fès 2');
    await movements.applyAdjustment(produitId: productId, locationId: 1, delta: 40);

    await movements.transfer(
      fromLocationId: 1,
      toLocationId: depot2.id,
      lines: [(produitId: productId, quantite: 15)],
    );

    expect(await balance.getStock(productId, 1), 25);
    expect(await balance.getStock(productId, depot2.id), 15);
  });

  test('transfer rejects same depot and vendor virtual stock', () async {
    await expectLater(
      movements.transfer(
        fromLocationId: 1,
        toLocationId: 1,
        lines: [(produitId: productId, quantite: 1)],
      ),
      throwsStateError,
    );

    final vendeur = await UserService(db, locations)
        .createVendeur(fullName: 'Karim', phone: '0600000001');
    final car = await locations.getOrCreateVirtualForUser(vendeur);
    await expectLater(
      movements.transfer(
        fromLocationId: 1,
        toLocationId: car.id,
        lines: [(produitId: productId, quantite: 1)],
      ),
      throwsStateError,
    );
  });

  test('depot names must be unique', () async {
    await locations.createPhysicalLocation('Dépôt B');
    await expectLater(
      locations.createPhysicalLocation('dépôt b'),
      throwsStateError,
    );
  });
}
