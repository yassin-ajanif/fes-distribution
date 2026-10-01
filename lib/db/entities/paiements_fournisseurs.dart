import 'package:drift/drift.dart';

import 'bons_reception.dart';

/// A payment made to a supplier, recorded on the bon de réception — mirroring
/// `PaiementsBonLivraison`. A BR is the debt (goods received); the facture
/// fournisseur that later groups it carries no money of its own.
class PaiementsFournisseurs extends Table {
  @override
  String get tableName => 'PaiementsFournisseurs';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get bonReceptionId => integer()
      .references(BonsReception, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  RealColumn get montant => real()();
  IntColumn get mode => integer().withDefault(const Constant(0))();
  TextColumn get reference => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
