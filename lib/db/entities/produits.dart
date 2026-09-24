import 'package:drift/drift.dart';

import 'categories.dart';

class Produits extends Table {
  @override
  String get tableName => 'Produits';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get reference => text().unique()();
  TextColumn get codeBarre => text().nullable()();
  TextColumn get designation => text()();
  TextColumn get unite => text()();
  RealColumn get prixAchatHT => real().withDefault(const Constant(0))();
  RealColumn get prixVenteHT => real().withDefault(const Constant(0))();
  RealColumn get tauxTVA => real().withDefault(const Constant(0))();
  RealColumn get stockMinimum => real().withDefault(const Constant(0))();
  IntColumn get categorieId =>
      integer().nullable().references(Categories, #id, onDelete: KeyAction.setNull)();
  BlobColumn get imageData => blob().nullable()();
  BoolColumn get actif => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
