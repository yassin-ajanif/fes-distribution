import 'package:drift/drift.dart';

class Categories extends Table {
  @override
  String get tableName => 'Categories';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get nom => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
