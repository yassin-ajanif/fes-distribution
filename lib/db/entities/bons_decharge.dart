import 'package:drift/drift.dart';

import 'stock_locations.dart';
import 'users.dart';

class BonsDecharge extends Table {
  @override
  String get tableName => 'BonsDecharge';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get numero => text().withLength(min: 1, max: 50).unique()();
  IntColumn get assignedToUserId =>
      integer().references(Users, #id, onDelete: KeyAction.restrict)();
  IntColumn get depotLocationId => integer()
      .withDefault(const Constant(1))
      .references(StockLocations, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withLength(max: 1000).withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
