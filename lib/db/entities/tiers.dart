import 'package:drift/drift.dart';

class Tiers extends Table {
  @override
  String get tableName => 'Tiers';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get type => integer()();
  TextColumn get nom => text()();
  TextColumn get ice => text()();
  TextColumn get adresse => text()();
  TextColumn get ville => text()();
  TextColumn get telephone => text()();
  TextColumn get email => text()();
  TextColumn get conditionsPaiement => text()();
  RealColumn get maxCredit => real().nullable()();
  BoolColumn get actif => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
