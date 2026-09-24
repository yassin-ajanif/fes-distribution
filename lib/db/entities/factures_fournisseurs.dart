import 'package:drift/drift.dart';

import 'tiers.dart';

class FacturesFournisseurs extends Table {
  @override
  String get tableName => 'FacturesFournisseurs';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get numero => text()();
  IntColumn get fournisseurId =>
      integer().references(Tiers, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get dateEcheance => dateTime()();
  BoolColumn get estPayee => boolean().withDefault(const Constant(false))();
  RealColumn get remiseGlobale => real().withDefault(const Constant(0))();
  RealColumn get totalTtc => real().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
