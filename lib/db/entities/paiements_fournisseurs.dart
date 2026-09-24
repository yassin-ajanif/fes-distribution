import 'package:drift/drift.dart';

import 'factures_fournisseurs.dart';

class PaiementsFournisseurs extends Table {
  @override
  String get tableName => 'PaiementsFournisseurs';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get factureFournisseurId => integer()
      .references(FacturesFournisseurs, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  RealColumn get montant => real()();
  IntColumn get mode => integer().withDefault(const Constant(0))();
  TextColumn get reference => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
