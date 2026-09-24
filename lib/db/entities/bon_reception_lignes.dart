import 'package:drift/drift.dart';

import 'bons_reception.dart';

class BonReceptionLignes extends Table {
  @override
  String get tableName => 'BonReceptionLignes';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get bRId =>
      integer().references(BonsReception, #id, onDelete: KeyAction.cascade)();
  IntColumn get produitId => integer()();
  TextColumn get designation => text()();
  RealColumn get quantiteRecue => real()();
  RealColumn get prixUnitaireHT => real()();
  RealColumn get tauxTVA => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
