import 'package:drift/drift.dart';

import 'factures.dart';
import 'tiers.dart';

class BonsCommandeClient extends Table {
  @override
  String get tableName => 'BonsCommandeClient';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get numero => text()();
  IntColumn get clientId =>
      integer().references(Tiers, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get date => dateTime()();
  IntColumn get devisId => integer().nullable()();
  IntColumn get factureId => integer()
      .nullable()
      .references(Factures, #id, onDelete: KeyAction.setNull)();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
