import 'package:drift/drift.dart';

import 'bons_charge.dart';
import 'produits.dart';

class BonChargeLignes extends Table {
  @override
  String get tableName => 'BonChargeLignes';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get bonChargeId =>
      integer().references(BonsCharge, #id, onDelete: KeyAction.cascade)();
  IntColumn get produitId =>
      integer().references(Produits, #id, onDelete: KeyAction.restrict)();
  TextColumn get designation => text().withLength(min: 1, max: 300)();
  RealColumn get quantite => real()();
  RealColumn get prixUnitaireHT => real()();
  RealColumn get remise => real().withDefault(const Constant(0))();
  RealColumn get tauxTVA => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
