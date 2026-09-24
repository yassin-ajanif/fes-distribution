import 'package:drift/drift.dart';

class AppSettings extends Table {
  @override
  String get tableName => 'AppSettings';

  IntColumn get id => integer()();
  TextColumn get societeNom => text().withDefault(const Constant(''))();
  TextColumn get societeAdresse => text().withDefault(const Constant(''))();
  TextColumn get societeICE => text().withDefault(const Constant(''))();
  TextColumn get societeLogoPath => text().nullable()();
  TextColumn get societeMentionsLegales => text().nullable()();
  TextColumn get devise => text().withDefault(const Constant('DH'))();
  TextColumn get tauxTVAJson => text().withDefault(const Constant('[20]'))();
  TextColumn get documentNumberingFloorsJson =>
      text().withDefault(const Constant('{}'))();
  IntColumn get devisValiditeJoursDefaut => integer().withDefault(const Constant(30))();
  BoolColumn get blocageSiStockInsuffisant =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get enableVirtualKeyboard =>
      boolean().withDefault(const Constant(false))();
  TextColumn get uiLanguage => text().withDefault(const Constant('fr'))();
  BoolColumn get backupEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get backupDirectory => text().withDefault(const Constant(''))();
  IntColumn get backupIntervalHours => integer().withDefault(const Constant(24))();
  TextColumn get backupIntervalUnit =>
      text().withDefault(const Constant('Hours'))();
  IntColumn get backupRetentionDays => integer().withDefault(const Constant(30))();
  DateTimeColumn get lastBackupDate => dateTime().nullable()();
  TextColumn get licenseKey => text().nullable()();
  DateTimeColumn get trialStartedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
