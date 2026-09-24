import 'package:drift/drift.dart';

import 'bons_commande.dart';
import 'factures_fournisseurs.dart';
import 'tiers.dart';

class BonsReception extends Table {
  @override
  String get tableName => 'BonsReception';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get numero => text()();
  IntColumn get fournisseurId =>
      integer().references(Tiers, #id, onDelete: KeyAction.restrict)();
  IntColumn get bonCommandeId => integer()
      .nullable()
      .references(BonsCommande, #id, onDelete: KeyAction.setNull)();
  IntColumn get factureFournisseurId => integer()
      .nullable()
      .references(FacturesFournisseurs, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get date => dateTime()();
  RealColumn get totalTtc => real().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
