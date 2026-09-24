import 'package:drift/drift.dart';

import 'bons_commande.dart';

class BonCommandeLignes extends Table {
  @override
  String get tableName => 'BonCommandeLignes';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get bonCommandeId =>
      integer().references(BonsCommande, #id, onDelete: KeyAction.cascade)();
  IntColumn get produitId => integer()();
  TextColumn get designation => text()();
  TextColumn get conditionnement => text().withDefault(const Constant(''))();
  RealColumn get quantiteCommandee => real()();
  RealColumn get prixUnitaireHT => real()();
  RealColumn get remise => real().withDefault(const Constant(0))();
  RealColumn get tauxTVA => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
