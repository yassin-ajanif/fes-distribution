import 'package:drift/drift.dart';
import 'package:fes_distribution/business/models/bon_decharge_list_item.dart';
import 'package:fes_distribution/business/models/personnel_document_line.dart';
import 'package:fes_distribution/db/app_database.dart';

class BonDechargeService {
  BonDechargeService(this._db);

  final AppDatabase _db;

  Future<List<BonDechargeListItem>> list({
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await (_db.select(_db.bonsDecharge)
          ..orderBy([
            (b) => OrderingTerm.desc(b.date),
            (b) => OrderingTerm.desc(b.id),
          ]))
        .get();

    Iterable<BonsDechargeData> filtered = rows;
    if (dateFrom != null) {
      filtered = filtered.where((b) => !b.date.isBefore(dateFrom));
    }
    if (dateTo != null) {
      filtered = filtered.where((b) => !b.date.isAfter(dateTo));
    }
    if (search != null && search.trim().isNotEmpty) {
      final t = search.trim().toLowerCase();
      final users = await _db.select(_db.users).get();
      final userNames = {
        for (final u in users) u.id: '${u.fullName} ${u.phone}'.toLowerCase(),
      };
      filtered = filtered.where(
        (b) =>
            b.numero.toLowerCase().contains(t) ||
            b.note.toLowerCase().contains(t) ||
            (userNames[b.assignedToUserId]?.contains(t) ?? false),
      );
    }

    final docs = filtered.skip(offset).take(limit).toList();
    if (docs.isEmpty) return [];

    final userIds = docs.map((d) => d.assignedToUserId).toSet();
    final depotIds = docs.map((d) => d.depotLocationId).toSet();

    final users = await (_db.select(_db.users)
          ..where((u) => u.id.isIn(userIds.toList())))
        .get();
    final depots = await (_db.select(_db.stockLocations)
          ..where((l) => l.id.isIn(depotIds.toList())))
        .get();

    final userMap = {for (final u in users) u.id: u.fullName};
    final depotMap = {for (final l in depots) l.id: l.nom};

    return docs
        .map(
          (d) => BonDechargeListItem(
            bon: d,
            assignedToNom: userMap[d.assignedToUserId] ?? '?',
            depotNom: depotMap[d.depotLocationId] ?? '?',
          ),
        )
        .toList();
  }

  Future<({BonsDechargeData bon, List<PersonnelDocumentLine> lines})?> getById(
    int id,
  ) async {
    final bon = await (_db.select(_db.bonsDecharge)
          ..where((b) => b.id.equals(id)))
        .getSingleOrNull();
    if (bon == null) return null;

    final lineRows = await (_db.select(_db.bonDechargeLignes)
          ..where((l) => l.bonDechargeId.equals(id)))
        .get();

    final productIds = lineRows.map((l) => l.produitId).toSet();
    final products = productIds.isEmpty
        ? <Produit>[]
        : await (_db.select(_db.produits)
              ..where((p) => p.id.isIn(productIds.toList())))
            .get();
    final productMap = {for (final p in products) p.id: p};

    final lines = lineRows
        .map(
          (l) => PersonnelDocumentLine(
            produitId: l.produitId,
            reference: productMap[l.produitId]?.reference ?? '',
            designation: l.designation,
            quantite: l.quantite,
            prixUnitaireHt: l.prixUnitaireHT,
            remise: l.remise,
            tauxTva: l.tauxTVA,
          ),
        )
        .toList();

    return (bon: bon, lines: lines);
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.bonsDecharge)..where((b) => b.id.equals(id))).go();
  }
}
