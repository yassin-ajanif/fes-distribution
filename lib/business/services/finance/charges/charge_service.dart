import 'package:drift/drift.dart';
import 'package:fes_distribution/business/models/charge_list_item.dart';
import 'package:fes_distribution/db/app_database.dart';

/// Expense records (`Charges`), each attached to a `TypesCharges` row.
///
/// Charges are pure accounting: they touch no stock and carry no lines, so
/// everything here is a single-table CRUD over `Charges` plus the type list the
/// edit page offers.
class ChargeService {
  ChargeService(this._db);

  final AppDatabase _db;

  /// Charges newest first, optionally filtered by free text over the libellé and
  /// the type name, and by an inclusive date window.
  Future<List<ChargeListItem>> list({
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final rows =
        await (_db.select(_db.charges)..orderBy([
              (c) => OrderingTerm.desc(c.date),
              (c) => OrderingTerm.desc(c.id),
            ]))
            .get();
    if (rows.isEmpty) return [];

    final types = await _db.select(_db.typesCharges).get();
    final typeNoms = {for (final t in types) t.id: t.nom};

    var filtered = rows;
    if (dateFrom != null) {
      filtered = filtered.where((c) => !c.date.isBefore(dateFrom)).toList();
    }
    if (dateTo != null) {
      filtered = filtered.where((c) => !c.date.isAfter(dateTo)).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      filtered = filtered
          .where(
            (c) =>
                c.libelle.toLowerCase().contains(q) ||
                c.note.toLowerCase().contains(q) ||
                (typeNoms[c.typeChargeId]?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }

    return [
      for (final c in filtered)
        ChargeListItem(charge: c, typeNom: typeNoms[c.typeChargeId] ?? '?'),
    ];
  }

  /// Sum of `montantTtc` over the same window [list] filters on, so the page can
  /// show a total next to the rows it lists.
  Future<double> total({DateTime? dateFrom, DateTime? dateTo}) async {
    final query = _db.selectOnly(_db.charges)
      ..addColumns([_db.charges.montantTtc.sum()]);
    if (dateFrom != null) {
      query.where(_db.charges.date.isBiggerOrEqualValue(dateFrom));
    }
    if (dateTo != null) {
      query.where(_db.charges.date.isSmallerOrEqualValue(dateTo));
    }
    final row = await query.getSingle();
    return row.read(_db.charges.montantTtc.sum()) ?? 0;
  }

  Future<Charge?> getById(int id) => (_db.select(
    _db.charges,
  )..where((c) => c.id.equals(id))).getSingleOrNull();

  /// Creates or updates a charge and returns its id.
  Future<int> save({
    int? id,
    required int typeChargeId,
    required String libelle,
    required DateTime date,
    required double montantTtc,
    String note = '',
    int? createdByUserId,
  }) async {
    if (typeChargeId <= 0) {
      throw StateError('Sélectionnez un type de charge.');
    }
    final trimmed = libelle.trim();
    if (trimmed.isEmpty) {
      throw StateError('Le libellé est obligatoire.');
    }
    if (montantTtc <= 0) {
      throw StateError('Le montant doit être supérieur à 0.');
    }

    final type = await (_db.select(
      _db.typesCharges,
    )..where((t) => t.id.equals(typeChargeId))).getSingleOrNull();
    if (type == null) throw StateError('Type de charge introuvable.');

    final now = DateTime.now().toUtc();
    return _db.transaction(() async {
      if (id == null) {
        return _db
            .into(_db.charges)
            .insert(
              ChargesCompanion.insert(
                typeChargeId: typeChargeId,
                libelle: trimmed,
                date: date,
                montantTtc: montantTtc,
                note: Value(note.trim()),
                createdAt: now,
                updatedAt: now,
                createdByUserId: Value(createdByUserId),
              ),
            );
      }

      await (_db.update(_db.charges)..where((c) => c.id.equals(id))).write(
        ChargesCompanion(
          typeChargeId: Value(typeChargeId),
          libelle: Value(trimmed),
          date: Value(date),
          montantTtc: Value(montantTtc),
          note: Value(note.trim()),
          updatedAt: Value(now),
        ),
      );
      return id;
    });
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.charges)..where((c) => c.id.equals(id))).go();
  }

  /// Charge types for the picker, alphabetical.
  Future<List<TypesCharge>> listActiveTypes() async {
    final rows =
        await (_db.select(_db.typesCharges)
              ..where((t) => t.actif.equals(true))
              ..orderBy([(t) => OrderingTerm.asc(t.nom)]))
            .get();
    return rows;
  }

  Future<TypesCharge?> getTypeById(int id) => (_db.select(
    _db.typesCharges,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Creates a type, or returns the existing one when the name is already
  /// taken. `TypesCharges.nom` is UNIQUE, so the caller can always rely on
  /// getting a usable id back — same convention as `CategorieService`.
  Future<int> createType(String nom, {int? createdByUserId}) async {
    final trimmed = nom.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Le nom du type de charge est obligatoire.');
    }

    // Compared in Dart, not with SQL `lower()`: that builtin only folds ASCII,
    // so `Énergie` never matches an existing `Énergie` and the insert would
    // fail on the UNIQUE index instead of reusing the row. The table holds one
    // row per expense category, so reading it whole is cheap.
    final wanted = trimmed.toLowerCase();
    final all = await _db.select(_db.typesCharges).get();
    for (final t in all) {
      if (t.nom.toLowerCase() == wanted) return t.id;
    }

    final now = DateTime.now().toUtc();
    return _db
        .into(_db.typesCharges)
        .insert(
          TypesChargesCompanion.insert(
            nom: trimmed,
            createdAt: now,
            updatedAt: now,
            createdByUserId: Value(createdByUserId),
          ),
        );
  }
}
