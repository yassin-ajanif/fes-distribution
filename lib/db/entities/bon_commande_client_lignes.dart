import 'package:drift/drift.dart';

import 'bons_commande_client.dart';

class BonCommandeClientLignes extends Table {
  @override
  String get tableName => 'BonCommandeClientLignes';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get bonCommandeClientId => integer()
      .references(BonsCommandeClient, #id, onDelete: KeyAction.cascade)();
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
