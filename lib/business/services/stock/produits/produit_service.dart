import 'package:drift/drift.dart';
import 'package:fes_distribution/business/models/produit_input.dart';
import 'package:fes_distribution/db/app_database.dart';

class ProduitService {
  ProduitService(this._db);

  final AppDatabase _db;

  Future<List<Produit>> listActive({String? search}) =>
      _list(search: search, activeOnly: true);

  Future<List<Produit>> listCatalog({String? search}) =>
      _list(search: search, activeOnly: false);

  Future<List<Produit>> _list({String? search, required bool activeOnly}) async {
    final query = _db.select(_db.produits);
    Expression<bool> predicate = activeOnly
        ? _db.produits.actif.equals(true)
        : const Constant(true);

    if (search != null && search.trim().isNotEmpty) {
      final t = search.trim().toLowerCase();
      final searchPredicate =
          _db.produits.reference.lower().like('%$t%') |
              _db.produits.designation.lower().like('%$t%') |
              _db.produits.codeBarre.lower().like('%$t%');
      predicate = predicate & searchPredicate;
    }

    final rows = await (query..where((p) => predicate)).get();
    rows.sort((a, b) => a.reference.compareTo(b.reference));
    return rows;
  }

  Future<Produit?> getById(int id) =>
      (_db.select(_db.produits)..where((p) => p.id.equals(id)))
          .getSingleOrNull();

  Future<int> create(ProduitInput input, {int? createdByUserId}) async {
    await _validateUnique(input, excludeId: null);
    final now = DateTime.now().toUtc();
    return _db.into(_db.produits).insert(
          ProduitsCompanion.insert(
            reference: input.reference.trim(),
            codeBarre: Value(_trimOrNull(input.codeBarre)),
            designation: input.designation.trim(),
            unite: _normalizeUnite(input.unite),
            prixAchatHT: Value(input.prixAchatHT),
            prixVenteHT: Value(input.prixVenteHT),
            tauxTVA: Value(input.tauxTVA),
            stockMinimum: Value(input.stockMinimum),
            categorieId: Value(input.categorieId),
            actif: Value(input.actif),
            createdAt: now,
            updatedAt: now,
            createdByUserId: Value(createdByUserId),
          ),
        );
  }

  Future<void> update(int id, ProduitInput input) async {
    await _validateUnique(input, excludeId: id);
    final existing = await getById(id);
    if (existing == null) {
      throw StateError('Produit introuvable.');
    }

    await (_db.update(_db.produits)..where((p) => p.id.equals(id))).write(
          ProduitsCompanion(
            reference: Value(input.reference.trim()),
            codeBarre: Value(_trimOrNull(input.codeBarre)),
            designation: Value(input.designation.trim()),
            unite: Value(_normalizeUnite(input.unite)),
            prixAchatHT: Value(input.prixAchatHT),
            prixVenteHT: Value(input.prixVenteHT),
            tauxTVA: Value(input.tauxTVA),
            stockMinimum: Value(input.stockMinimum),
            categorieId: Value(input.categorieId),
            actif: Value(input.actif),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> deactivate(int id) async {
    final existing = await getById(id);
    if (existing == null) {
      throw StateError('Produit introuvable.');
    }

    await (_db.update(_db.produits)..where((p) => p.id.equals(id))).write(
          ProduitsCompanion(
            actif: const Value(false),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> _validateUnique(ProduitInput input, {required int? excludeId}) async {
    final ref = input.reference.trim();
    final code = _trimOrNull(input.codeBarre);
    final designation = input.designation.trim();

    if (ref.isEmpty || designation.isEmpty) {
      throw ArgumentError('Référence et désignation sont obligatoires.');
    }

    final refQuery = _db.select(_db.produits)
      ..where((p) => p.reference.equals(ref));
    if (excludeId != null) {
      refQuery.where((p) => p.id.equals(excludeId).not());
    }
    if (await refQuery.getSingleOrNull() != null) {
      throw StateError('Cette référence existe déjà.');
    }

    if (code != null) {
      final codeQuery = _db.select(_db.produits)
        ..where((p) => p.codeBarre.equals(code));
      if (excludeId != null) {
        codeQuery.where((p) => p.id.equals(excludeId).not());
      }
      if (await codeQuery.getSingleOrNull() != null) {
        throw StateError('Ce code-barres existe déjà.');
      }
    }
  }

  String? _trimOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _normalizeUnite(String unite) {
    final trimmed = unite.trim();
    return trimmed.isEmpty ? 'U' : trimmed;
  }
}
