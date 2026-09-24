import 'package:drift/drift.dart';

import 'tiers.dart';

class AvoirsFournisseurs extends Table {
  @override
  String get tableName => 'AvoirsFournisseurs';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get numero => text()();
  IntColumn get fournisseurId =>
      integer().references(Tiers, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get date => dateTime()();
  TextColumn get motif => text().withDefault(const Constant(''))();
  BoolColumn get retourMarchandise =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
