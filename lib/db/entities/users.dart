import 'package:drift/drift.dart';

class Users extends Table {
  @override
  String get tableName => 'Users';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get fullName => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().withLength(min: 1, max: 50).unique()();
  TextColumn get userType =>
      text().withLength(max: 20).withDefault(const Constant('Vendeur'))();
  BoolColumn get actif => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
}
