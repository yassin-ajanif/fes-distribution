import 'package:drift/drift.dart' hide isNull;
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

    expect(await db.select(db.users).get(), isEmpty);
  });

  test('existing databases drop the legacy DEPOT-PRINCIPAL pseudo-vendeur', () async {
    await db.into(db.users).insert(
          UsersCompanion.insert(
            fullName: 'admin',
            phone: 'DEPOT-PRINCIPAL',
            userType: const Value('Admin'),
            createdAt: DateTime.now().toUtc(),
          ),
        );

    await DbSeeder.removeLegacyDepotAdmin(db);

    final legacy = await (db.select(db.users)
          ..where((t) => t.phone.equals('DEPOT-PRINCIPAL')))
        .getSingleOrNull();
    expect(legacy, isNull);
  });

  test('migrating v1 moves supplier payments onto the oldest BR of the facture',
      () async {
    final now = DateTime.now().toUtc();
    // A v1 database: no est_payee on BonsReception, payments keyed to the
    // facture, and one facture grouping two BRs.
    await db.customStatement('DROP TABLE PaiementsFournisseurs');
    await db.customStatement('''
      CREATE TABLE PaiementsFournisseurs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        facture_fournisseur_id INTEGER NOT NULL,
        date INTEGER NOT NULL,
        montant REAL NOT NULL,
        mode INTEGER NOT NULL DEFAULT 0,
        reference TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        created_by_user_id INTEGER NULL
      )
    ''');
    await db.customStatement('DROP TABLE BonsReception');
    await db.customStatement('''
      CREATE TABLE BonsReception (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        numero TEXT NOT NULL,
        fournisseur_id INTEGER NOT NULL,
        bon_commande_id INTEGER NULL,
        facture_fournisseur_id INTEGER NULL,
        date INTEGER NOT NULL,
        total_ttc REAL NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        created_by_user_id INTEGER NULL
      )
    ''');

    final tiersId = await db.into(db.tiers).insert(
          TiersCompanion.insert(
            nom: 'Fournisseur A',
            type: 1,
            ice: '',
            adresse: '',
            ville: '',
            telephone: '',
            email: '',
            conditionsPaiement: '',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final factureId = await db.into(db.facturesFournisseurs).insert(
          FacturesFournisseursCompanion.insert(
            numero: 'FAF-001',
            fournisseurId: tiersId,
            date: now,
            dateEcheance: now,
            totalTtc: const Value(1000),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final oldBr = await db.into(db.bonsReception).insert(
          BonsReceptionCompanion.insert(
            numero: 'BR-001',
            fournisseurId: tiersId,
            factureFournisseurId: Value(factureId),
            date: now.subtract(const Duration(days: 2)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.bonsReception).insert(
          BonsReceptionCompanion.insert(
            numero: 'BR-002',
            fournisseurId: tiersId,
            factureFournisseurId: Value(factureId),
            date: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    final produitId = await db.into(db.produits).insert(
          ProduitsCompanion.insert(
            reference: 'P-MIG',
            designation: 'Peinture',
            unite: 'U',
            createdAt: now,
            updatedAt: now,
          ),
        );
    // Only the first line carries the BR link, as the real flow does.
    for (final brId in [oldBr, oldBr + 1]) {
      await db.into(db.factureFournisseurLignes).insert(
            FactureFournisseurLignesCompanion.insert(
              factureFournisseurId: factureId,
              bonReceptionId: Value(brId),
              produitId: produitId,
              designation: 'Peinture',
              quantite: 1,
              prixUnitaireHT: 500,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    await db.customStatement(
      'INSERT INTO PaiementsFournisseurs '
      '(id, facture_fournisseur_id, date, montant, mode, reference, '
      'created_at, updated_at) VALUES '
      "(1, $factureId, ${now.millisecondsSinceEpoch ~/ 1000}, 250, 2, 'virement', "
      '${now.millisecondsSinceEpoch ~/ 1000}, ${now.millisecondsSinceEpoch ~/ 1000})',
    );

    await db.migrateSupplierPaymentsToBrForTest();

    final columns = await db
        .customSelect("SELECT name FROM pragma_table_info('PaiementsFournisseurs')")
        .get();
    expect(
      columns.map((c) => c.read<String>('name')),
      contains('bon_reception_id'),
    );
    expect(
      columns.map((c) => c.read<String>('name')),
      isNot(contains('facture_fournisseur_id')),
    );

    final payment =
        await (db.select(db.paiementsFournisseurs)..where((p) => p.id.equals(1)))
            .getSingle();
    // Attached to the oldest BR of the facture, with the amount preserved.
    expect(payment.bonReceptionId, oldBr);
    expect(payment.montant, 250);
    expect(payment.reference, 'virement');
    expect(payment.mode, 2);

    final br = await (db.select(db.bonsReception)
          ..where((b) => b.id.equals(oldBr)))
        .getSingle();
    expect(br.estPayee, isFalse);
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
