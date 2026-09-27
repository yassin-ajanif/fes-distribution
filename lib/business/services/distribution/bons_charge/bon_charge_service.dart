import 'package:drift/drift.dart';
import 'package:fes_distribution/business/models/bon_charge_list_item.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/services/stock/parametres/document_number_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/db/app_database.dart';

class BonChargeService {
  BonChargeService(
    this._db,
    this._numbers,
    this._locations,
    this._stock,
  );

  final AppDatabase _db;
  final DocumentNumberService _numbers;
  final StockLocationService _locations;
  final StockMovementService _stock;

  Future<List<BonChargeListItem>> list({
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await (_db.select(_db.bonsCharge)
          ..orderBy([
            (b) => OrderingTerm.desc(b.date),
            (b) => OrderingTerm.desc(b.id),
          ]))
        .get();

    Iterable<BonsChargeData> filtered = rows;
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
          (d) => BonChargeListItem(
            bon: d,
            assignedToNom: userMap[d.assignedToUserId] ?? '?',
            depotNom: depotMap[d.depotLocationId] ?? '?',
          ),
        )
        .toList();
  }

  Future<({BonsChargeData bon, List<DocumentLine> lines})?> getById(
    int id,
  ) async {
    final bon = await (_db.select(_db.bonsCharge)
          ..where((b) => b.id.equals(id)))
        .getSingleOrNull();
    if (bon == null) return null;

    final lineRows = await (_db.select(_db.bonChargeLignes)
          ..where((l) => l.bonChargeId.equals(id)))
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
          (l) => DocumentLine(
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

  Future<int> save({
    int? id,
    required int assignedToUserId,
    required int depotLocationId,
    required DateTime date,
    required String note,
    required List<DocumentLine> lines,
    int? createdByUserId,
  }) async {
    final validLines =
        lines.where((l) => l.produitId > 0 && l.quantite > 0).toList();
    if (validLines.isEmpty) {
      throw StateError('Ajoutez au moins une ligne avec quantité.');
    }

    return _db.transaction(() async {
      final now = DateTime.now().toUtc();
      late int bonId;
      late String numero;

      if (id == null) {
        numero = await _numbers.nextBonCharge();
        bonId = await _db.into(_db.bonsCharge).insert(
              BonsChargeCompanion.insert(
                numero: numero,
                assignedToUserId: assignedToUserId,
                depotLocationId: Value(depotLocationId),
                date: date,
                note: Value(note),
                createdAt: now,
                updatedAt: now,
                createdByUserId: Value(createdByUserId),
              ),
            );
      } else {
        bonId = id;
        final existing = await (_db.select(_db.bonsCharge)
              ..where((b) => b.id.equals(id)))
            .getSingle();
        numero = existing.numero;

        await (_db.update(_db.bonsCharge)..where((b) => b.id.equals(id))).write(
          BonsChargeCompanion(
            assignedToUserId: Value(assignedToUserId),
            depotLocationId: Value(depotLocationId),
            date: Value(date),
            note: Value(note),
            updatedAt: Value(now),
          ),
        );

        await (_db.delete(_db.bonChargeLignes)
              ..where((l) => l.bonChargeId.equals(id)))
            .go();
      }

      for (final line in validLines) {
        await _db.into(_db.bonChargeLignes).insert(
              BonChargeLignesCompanion.insert(
                bonChargeId: bonId,
                produitId: line.produitId,
                designation: line.designation,
                quantite: line.quantite,
                prixUnitaireHT: line.prixUnitaireHt,
                remise: Value(line.remise),
                tauxTVA: Value(line.tauxTva),
                createdAt: now,
                updatedAt: now,
                createdByUserId: Value(createdByUserId),
              ),
            );
      }

      final user = await (_db.select(_db.users)
            ..where((u) => u.id.equals(assignedToUserId)))
          .getSingle();
      final virtualLoc = await _locations.getOrCreateVirtualForUser(user);

      await _stock.resyncBonChargeStock(
        bonChargeId: bonId,
        noteDetail: numero,
        depotLocationId: depotLocationId,
        virtualLocationId: virtualLoc.id,
        lines: validLines
            .map((l) => (produitId: l.produitId, quantite: l.quantite)),
        createdByUserId: createdByUserId,
      );

      return bonId;
    });
  }

  /// Deletes the bon and returns its goods from the vendor stock to the depot.
  Future<void> delete(int id, {int? createdByUserId}) async {
    await _db.transaction(() async {
      final entity = await (_db.select(_db.bonsCharge)
            ..where((b) => b.id.equals(id)))
          .getSingle();
      final user = await (_db.select(_db.users)
            ..where((u) => u.id.equals(entity.assignedToUserId)))
          .getSingle();
      final virtualLoc = await _locations.getOrCreateVirtualForUser(user);

      await _stock.resyncBonChargeStock(
        bonChargeId: entity.id,
        noteDetail: entity.numero,
        depotLocationId: entity.depotLocationId,
        virtualLocationId: virtualLoc.id,
        lines: const [],
        createdByUserId: createdByUserId,
      );

      await (_db.delete(_db.bonsCharge)..where((b) => b.id.equals(id))).go();
    });
  }
}
