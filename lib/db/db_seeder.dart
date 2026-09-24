import 'package:drift/drift.dart';

import 'app_database.dart';

/// Initial data aligned with Peinture distribution [DbSeeder].
class DbSeeder {
  DbSeeder._();

  static const defaultClientName = 'Client Comptoire';
  static const depotPrincipalNom = 'Dépôt principal';
  static const depotPrincipalAdminPhone = 'DEPOT-PRINCIPAL';
  static const depotPrincipalAdminName = 'admin';

  static bool isDepotPrincipalAdminPhone(String phone) =>
      phone.trim() == depotPrincipalAdminPhone;

  static bool isDepotPrincipalAdmin(User user) =>
      isDepotPrincipalAdminPhone(user.phone);

  static Future<void> seed(AppDatabase db) async {
    await _seedAppSettings(db);
    await _seedDefaultDepot(db);
    await _seedDefaultClient(db);
    await _seedDepotPrincipalAdmin(db);
  }

  static Future<void> _seedAppSettings(AppDatabase db) async {
    final existing = await (db.select(db.appSettings)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (existing != null) return;

    await db.into(db.appSettings).insert(
          AppSettingsCompanion.insert(
            id: const Value(1),
          ),
        );
  }

  static Future<void> _seedDefaultDepot(AppDatabase db) async {
    final existing = await (db.select(db.stockLocations)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (existing != null) return;

    final now = DateTime.now().toUtc();
    await db.into(db.stockLocations).insert(
          StockLocationsCompanion.insert(
            id: const Value(1),
            nom: depotPrincipalNom,
            isVirtual: const Value(false),
            actif: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  static Future<void> _seedDefaultClient(AppDatabase db) async {
    final count = await (db.select(db.tiers)
          ..where((t) => t.nom.equals(defaultClientName)))
        .get();
    if (count.isNotEmpty) return;

    final now = DateTime.now().toUtc();
    await db.into(db.tiers).insert(
          TiersCompanion.insert(
            type: 0,
            nom: defaultClientName,
            ice: '',
            adresse: '',
            ville: '',
            telephone: '',
            email: '',
            conditionsPaiement: '',
            actif: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  static Future<void> _seedDepotPrincipalAdmin(AppDatabase db) async {
    final existing = await (db.select(db.users)
          ..where((t) => t.phone.equals(depotPrincipalAdminPhone)))
        .getSingleOrNull();
    if (existing != null) return;

    await db.into(db.users).insert(
          UsersCompanion.insert(
            fullName: depotPrincipalAdminName,
            phone: depotPrincipalAdminPhone,
            userType: const Value('Admin'),
            actif: const Value(true),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }
}
