import 'package:drift/drift.dart';
import 'package:fes_distribution/db/app_database.dart';

class CategorieService {
  CategorieService(this._db);

  final AppDatabase _db;

  Future<List<Category>> listAll() async {
    final rows = await _db.select(_db.categories).get();
    rows.sort((a, b) => a.nom.compareTo(b.nom));
    return rows;
  }

  Future<int> create(String nom, {int? createdByUserId}) async {
    final trimmed = nom.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Le nom de la catégorie est obligatoire.');
    }

    final existing = await (_db.select(_db.categories)
          ..where((c) => c.nom.lower().equals(trimmed.toLowerCase())))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    final now = DateTime.now().toUtc();
    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            nom: trimmed,
            createdAt: now,
            updatedAt: now,
            createdByUserId: Value(createdByUserId),
          ),
        );
  }
}
