import 'package:drift/drift.dart';
import 'package:fes_distribution/business/enums/user_type.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/db/db_seeder.dart';

class StockLocationService {
  StockLocationService(this._db);

  final AppDatabase _db;

  Future<StockLocation> getOrCreateDefaultDepot() async {
    final byName = await (_db.select(_db.stockLocations)
          ..where(
            (l) =>
                l.isVirtual.equals(false) &
                l.nom.equals(DbSeeder.depotPrincipalNom),
          ))
        .getSingleOrNull();
    if (byName != null) return byName;

    final anyActive = await (_db.select(_db.stockLocations)
          ..where((l) => l.isVirtual.equals(false) & l.actif.equals(true))
          ..orderBy([(l) => OrderingTerm.asc(l.id)])
          ..limit(1))
        .getSingleOrNull();
    if (anyActive != null) return anyActive;

    final now = DateTime.now().toUtc();
    final id = await _db.into(_db.stockLocations).insert(
          StockLocationsCompanion.insert(
            nom: DbSeeder.depotPrincipalNom,
            isVirtual: const Value(false),
            actif: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return await (_db.select(_db.stockLocations)..where((l) => l.id.equals(id)))
        .getSingle();
  }

  /// The vendeur's car. Sales happen only from vendeur stock, never from a
  /// physical depot.
  Future<StockLocation> getOrCreateVirtualForUser(User user) async {
    if (user.userType != UserType.vendeur) {
      throw StateError('Seul un vendeur possède un stock véhicule.');
    }

    final existing = await (_db.select(_db.stockLocations)
          ..where(
            (l) => l.isVirtual.equals(true) & l.userId.equals(user.id),
          ))
        .getSingleOrNull();
    if (existing != null) return existing;

    final nom = user.fullName.trim().isEmpty ? user.phone : user.fullName.trim();
    final now = DateTime.now().toUtc();
    final id = await _db.into(_db.stockLocations).insert(
          StockLocationsCompanion.insert(
            nom: nom,
            isVirtual: const Value(true),
            userId: Value(user.id),
            actif: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return await (_db.select(_db.stockLocations)..where((l) => l.id.equals(id)))
        .getSingle();
  }

  Future<List<StockLocation>> getActiveLocations() async {
    final rows = await (_db.select(_db.stockLocations)
          ..where((l) => l.actif.equals(true))
          ..orderBy([
            (l) => OrderingTerm.asc(l.isVirtual),
            (l) => OrderingTerm.asc(l.nom),
          ]))
        .get();
    return rows;
  }

  Future<List<StockLocation>> getActivePhysicalLocations() async {
    final all = await getActiveLocations();
    return all.where((l) => !l.isVirtual).toList();
  }

  Future<StockLocation> createPhysicalLocation(
    String nom, {
    int? createdByUserId,
  }) async {
    final trimmed = nom.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Le nom du dépôt est obligatoire.');
    }

    final duplicate = await (_db.select(_db.stockLocations)
          ..where(
            (l) =>
                l.isVirtual.equals(false) &
                l.nom.lower().equals(trimmed.toLowerCase()),
          ))
        .getSingleOrNull();
    if (duplicate != null) {
      throw StateError('Un dépôt porte déjà ce nom.');
    }

    final now = DateTime.now().toUtc();
    final id = await _db.into(_db.stockLocations).insert(
          StockLocationsCompanion.insert(
            nom: trimmed,
            isVirtual: const Value(false),
            actif: const Value(true),
            createdAt: now,
            updatedAt: now,
            createdByUserId: Value(createdByUserId),
          ),
        );
    return await (_db.select(_db.stockLocations)..where((l) => l.id.equals(id)))
        .getSingle();
  }
}
