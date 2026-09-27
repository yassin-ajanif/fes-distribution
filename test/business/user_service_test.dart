import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fes_distribution/business/services/distribution/vendeurs/user_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/db/app_database.dart';

void main() {
  late AppDatabase db;
  late StockLocationService locations;
  late UserService users;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    locations = StockLocationService(db);
    users = UserService(db, locations);
  });

  tearDown(() async {
    await db.close();
  });

  test('a new vendeur gets his own virtual car stock', () async {
    final vendeur = await users.createVendeur(fullName: 'Salah', phone: '0611558899');

    final car = await locations.getOrCreateVirtualForUser(vendeur);
    expect(car.isVirtual, isTrue);
    expect(car.userId, vendeur.id);
    expect(car.nom, 'Salah');
    expect(car.id, isNot(1));
  });

  test('vendeur list contains only real vendeurs', () async {
    await users.createVendeur(fullName: 'Salah', phone: '0611558899');
    await users.createVendeur(fullName: 'Karim', phone: '0600000001');

    final list = await users.listVendeurs();
    expect(list.map((u) => u.fullName), ['Karim', 'Salah']);
  });
}
