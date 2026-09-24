import 'package:drift/drift.dart';

import 'bons_commande_client.dart';
import 'factures.dart';
import 'tiers.dart';
import 'users.dart';

class BonsLivraison extends Table {
  @override
  String get tableName => 'BonsLivraison';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get numero => text()();
  IntColumn get clientId =>
      integer().references(Tiers, #id, onDelete: KeyAction.restrict)();
  IntColumn get vendeurId => integer()
      .nullable()
      .references(Users, #id, onDelete: KeyAction.restrict)();
  IntColumn get bonCommandeClientId => integer()
      .nullable()
      .references(BonsCommandeClient, #id, onDelete: KeyAction.setNull)();
  IntColumn get factureId => integer()
      .nullable()
      .references(Factures, #id, onDelete: KeyAction.setNull)();
  IntColumn get devisId => integer().nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get dateEcheance => dateTime()();
  BoolColumn get estPayee => boolean().withDefault(const Constant(false))();
  RealColumn get remiseGlobale => real().withDefault(const Constant(0))();
  RealColumn get totalTtc => real().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
