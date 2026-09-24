import 'package:drift/drift.dart';

import 'users.dart';

class RemisesCaisse extends Table {
  @override
  String get tableName => 'RemisesCaisse';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get numero => text().withLength(min: 1, max: 50).unique()();
  IntColumn get assignedToUserId =>
      integer().references(Users, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get date => dateTime()();
  RealColumn get montant => real()();
  IntColumn get mode => integer().withDefault(const Constant(0))();
  TextColumn get note => text().withLength(max: 1000).withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
