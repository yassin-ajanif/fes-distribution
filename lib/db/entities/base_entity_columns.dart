import 'package:drift/drift.dart';

/// Audit columns shared by most business tables (see docs/database-design.md).
mixin BaseEntityColumns on Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
