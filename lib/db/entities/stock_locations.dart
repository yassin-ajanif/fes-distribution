import 'package:drift/drift.dart';

import 'users.dart';

class StockLocations extends Table {
  @override
  String get tableName => 'StockLocations';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get nom => text().withLength(min: 1, max: 200)();
  BoolColumn get isVirtual => boolean().withDefault(const Constant(false))();
  IntColumn get userId =>
      integer().nullable().references(Users, #id, onDelete: KeyAction.restrict)();
  BoolColumn get actif => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
