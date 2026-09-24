import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/db/db_seeder.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
  });

  tearDown(() async {
    await db.close();
  });

  test('creates all tables and seeds defaults', () async {
    await db.customSelect('SELECT name FROM sqlite_master WHERE type = ?', variables: [
      Variable.withString('table'),
    ]).get();

    final settings = await (db.select(db.appSettings)
          ..where((t) => t.id.equals(1)))
        .getSingle();
    expect(settings.devise, 'DH');

    final depot = await (db.select(db.stockLocations)
          ..where((t) => t.id.equals(1)))
        .getSingle();
    expect(depot.nom, DbSeeder.depotPrincipalNom);
    expect(depot.isVirtual, isFalse);

    final client = await (db.select(db.tiers)
          ..where((t) => t.nom.equals(DbSeeder.defaultClientName)))
        .getSingle();
    expect(client.type, 0);

    final admin = await (db.select(db.users)
          ..where((t) => t.phone.equals(DbSeeder.depotPrincipalAdminPhone)))
        .getSingle();
    expect(admin.userType, 'Admin');
  });

  test('supports inserting a product with category', () async {
    final now = DateTime.now().toUtc();
    final categoryId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            nom: 'Peinture',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final productId = await db.into(db.produits).insert(
          ProduitsCompanion.insert(
            reference: 'P-001',
            designation: 'Peinture blanche 10L',
            unite: 'U',
            categorieId: Value(categoryId),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final product = await (db.select(db.produits)
          ..where((t) => t.id.equals(productId)))
        .getSingle();
    expect(product.reference, 'P-001');
    expect(product.categorieId, categoryId);
  });
}
