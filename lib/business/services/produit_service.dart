import 'package:drift/drift.dart';
import 'package:fes_distribution/db/app_database.dart';

class ProduitService {
  ProduitService(this._db);

  final AppDatabase _db;

  Future<List<Produit>> listActive({String? search}) async {
    var query = _db.select(_db.produits)..where((p) => p.actif.equals(true));

    if (search != null && search.trim().isNotEmpty) {
      final t = search.trim().toLowerCase();
      query = _db.select(_db.produits)
        ..where(
          (p) =>
              p.actif.equals(true) &
              (p.reference.lower().like('%$t%') |
                  p.designation.lower().like('%$t%') |
                  p.codeBarre.lower().like('%$t%')),
        );
    }

    final rows = await query.get();
    rows.sort((a, b) => a.reference.compareTo(b.reference));
    return rows;
  }

  Future<Produit?> getById(int id) =>
      (_db.select(_db.produits)..where((p) => p.id.equals(id)))
          .getSingleOrNull();
}
