import 'package:drift/drift.dart';

import 'factures.dart';
import 'tiers.dart';

class Avoirs extends Table {
  @override
  String get tableName => 'Avoirs';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get numero => text()();
  IntColumn get clientId =>
      integer().references(Tiers, #id, onDelete: KeyAction.restrict)();
  IntColumn get factureId => integer()
      .nullable()
      .references(Factures, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get date => dateTime()();
  TextColumn get motif => text().withDefault(const Constant(''))();
  BoolColumn get retourMarchandise =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
