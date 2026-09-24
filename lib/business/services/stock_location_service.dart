import 'package:drift/drift.dart';
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
          ..where((l) => l.isVirtual.equals(false) & l.actif.equals(true)))
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

  Future<StockLocation> getOrCreateVirtualForUser(User user) async {
    if (DbSeeder.isDepotPrincipalAdmin(user)) {
      return getOrCreateDefaultDepot();
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
}
