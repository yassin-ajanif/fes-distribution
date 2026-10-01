import 'package:drift/drift.dart';

import 'app_database.dart';

/// Initial data aligned with Peinture distribution [DbSeeder].
class DbSeeder {
  DbSeeder._();

  static const defaultClientName = 'Client Comptoire';

  /// Counter placeholder client. The phone column is unique and mandatory, so
  /// it needs a number of its own; the format is deliberately not dialable so
  /// nobody mistakes it for a real contact.
  static const defaultClientPhone = 'INTERNAL-COMPTOIRE';
  static const depotPrincipalNom = 'Dépôt principal';

  /// Pseudo-vendeur Peinture uses for counter sales from the depot.
  /// FesDistribution sells only through vendeurs, so it is removed.
  static const _legacyDepotAdminPhone = 'DEPOT-PRINCIPAL';

  static Future<void> seed(AppDatabase db) async {
    await _seedAppSettings(db);
    await _seedDefaultDepot(db);
    await _seedDefaultClient(db);
  }

  static Future<void> _seedAppSettings(AppDatabase db) async {
    final existing = await (db.select(
      db.appSettings,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (existing != null) return;

    await db
        .into(db.appSettings)
        .insert(AppSettingsCompanion.insert(id: const Value(1)));
  }

  static Future<void> _seedDefaultDepot(AppDatabase db) async {
    final existing = await (db.select(
      db.stockLocations,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (existing != null) return;

    final now = DateTime.now().toUtc();
    await db
        .into(db.stockLocations)
        .insert(
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
    final count = await (db.select(
      db.tiers,
    )..where((t) => t.nom.equals(defaultClientName))).get();
    if (count.isNotEmpty) return;

    final now = DateTime.now().toUtc();
    await db
        .into(db.tiers)
        .insert(
          TiersCompanion.insert(
            type: 0,
            nom: defaultClientName,
            ice: '',
            adresse: '',
            ville: '',
            telephone: defaultClientPhone,
            email: '',
            conditionsPaiement: '',
            actif: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  static Future<void> removeLegacyDepotAdmin(AppDatabase db) async {
    try {
      await (db.delete(
        db.users,
      )..where((t) => t.phone.equals(_legacyDepotAdminPhone))).go();
    } on Object {
      // Still referenced by a document: keep the row. It is not a vendeur,
      // so it never shows up in vendeur lists.
    }
  }
}
