import 'package:drift/drift.dart';

import 'tiers.dart';

class Devis extends Table {
  @override
  String get tableName => 'Devis';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get numero => text()();
  IntColumn get clientId =>
      integer().references(Tiers, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get dateValidite => dateTime()();
  RealColumn get remiseGlobale => real().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
