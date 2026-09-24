import 'package:drift/drift.dart';

import 'avoirs_fournisseurs.dart';

class AvoirFournisseurLignes extends Table {
  @override
  String get tableName => 'AvoirFournisseurLignes';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get avoirFournisseurId => integer()
      .references(AvoirsFournisseurs, #id, onDelete: KeyAction.cascade)();
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
