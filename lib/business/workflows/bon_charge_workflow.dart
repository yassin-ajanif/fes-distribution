import 'package:drift/drift.dart';
import 'package:fes_distribution/business/models/personnel_document_line.dart';
import 'package:fes_distribution/business/services/document_number_service.dart';
import 'package:fes_distribution/business/services/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock_movement_service.dart';
import 'package:fes_distribution/db/app_database.dart';

class BonChargeWorkflow {
  BonChargeWorkflow(
    this._db,
    this._numbers,
    this._locations,
    this._stock,
  );

  final AppDatabase _db;
  final DocumentNumberService _numbers;
  final StockLocationService _locations;
  final StockMovementService _stock;

  Future<int> save({
    int? id,
    required int assignedToUserId,
    required int depotLocationId,
    required DateTime date,
    required String note,
    required List<PersonnelDocumentLine> lines,
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
