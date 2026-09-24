import 'package:drift/drift.dart';

import 'produits.dart';
import 'stock_locations.dart';

class MouvementsStock extends Table {
  @override
  String get tableName => 'MouvementsStock';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get produitId =>
      integer().references(Produits, #id, onDelete: KeyAction.restrict)();
  IntColumn get fromLocationId => integer()
      .nullable()
      .references(StockLocations, #id, onDelete: KeyAction.restrict)();
  IntColumn get toLocationId => integer()
      .nullable()
      .references(StockLocations, #id, onDelete: KeyAction.restrict)();
  RealColumn get quantite => real()();
  RealColumn get fromApres => real().nullable()();
  RealColumn get toApres => real().nullable()();
  TextColumn get origineType => text()();
  IntColumn get origineId => integer().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
