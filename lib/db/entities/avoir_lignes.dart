import 'package:drift/drift.dart';

import 'avoirs.dart';

class AvoirLignes extends Table {
  @override
  String get tableName => 'AvoirLignes';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get avoirId =>
      integer().references(Avoirs, #id, onDelete: KeyAction.cascade)();
  IntColumn get produitId => integer()();
  TextColumn get designation => text()();
  TextColumn get conditionnement => text().withDefault(const Constant(''))();
  RealColumn get quantite => real()();
  RealColumn get prixUnitaireHT => real()();
  RealColumn get remise => real().withDefault(const Constant(0))();
  RealColumn get tauxTVA => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
