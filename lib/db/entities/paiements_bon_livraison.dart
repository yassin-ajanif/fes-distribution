import 'package:drift/drift.dart';

import 'bons_livraison.dart';

class PaiementsBonLivraison extends Table {
  @override
  String get tableName => 'PaiementsBonLivraison';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get bonLivraisonId => integer()
      .references(BonsLivraison, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  RealColumn get montant => real()();
  IntColumn get mode => integer().withDefault(const Constant(0))();
  TextColumn get reference => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
