import 'package:drift/drift.dart';

import 'bons_reception.dart';
import 'factures_fournisseurs.dart';

class FactureFournisseurLignes extends Table {
  @override
  String get tableName => 'FactureFournisseurLignes';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get factureFournisseurId => integer()
      .references(FacturesFournisseurs, #id, onDelete: KeyAction.cascade)();
  IntColumn get bonReceptionId => integer()
      .nullable()
      .references(BonsReception, #id, onDelete: KeyAction.setNull)();
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
