import 'package:drift/drift.dart';
import 'package:fes_distribution/db/app_database.dart';

class StockBalanceService {
  StockBalanceService(this._db);

  final AppDatabase _db;

  Future<double> getStock(int produitId, int locationId) async {
    final latest = await (_db.select(_db.mouvementsStock)
          ..where(
            (m) =>
                m.produitId.equals(produitId) &
                (m.fromLocationId.equals(locationId) |
                    m.toLocationId.equals(locationId)),
          )
          ..orderBy([
            (m) => OrderingTerm.desc(m.createdAt),
            (m) => OrderingTerm.desc(m.id),
          ])
          ..limit(1))
        .getSingleOrNull();

    if (latest == null) return 0;

    if (latest.toLocationId == locationId) return latest.toApres ?? 0;
    if (latest.fromLocationId == locationId) return latest.fromApres ?? 0;
    return 0;
  }

  Future<Map<int, double>> getStocks(
    Iterable<int> produitIds,
    int locationId,
  ) async {
    final ids = produitIds.toSet();
    final result = <int, double>{};
    for (final id in ids) {
      result[id] = await getStock(id, locationId);
    }
    return result;
  }
}
