import 'package:drift/drift.dart';

import 'tiers.dart';

class BonsCommande extends Table {
  @override
  String get tableName => 'BonsCommande';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get numero => text()();
  IntColumn get fournisseurId =>
      integer().references(Tiers, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
