import 'package:drift/drift.dart';

import 'bons_livraison.dart';
import 'factures.dart';

class FactureLignes extends Table {
  @override
  String get tableName => 'FactureLignes';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get factureId =>
      integer().references(Factures, #id, onDelete: KeyAction.cascade)();
  IntColumn get bonLivraisonId => integer()
      .nullable()
      .references(BonsLivraison, #id, onDelete: KeyAction.setNull)();
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
