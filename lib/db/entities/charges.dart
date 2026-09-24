import 'package:drift/drift.dart';

import 'types_charges.dart';

class Charges extends Table {
  @override
  String get tableName => 'Charges';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get typeChargeId =>
      integer().references(TypesCharges, #id, onDelete: KeyAction.restrict)();
  TextColumn get libelle => text().withLength(min: 1, max: 256)();
  DateTimeColumn get date => dateTime()();
  RealColumn get montantTtc => real()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
