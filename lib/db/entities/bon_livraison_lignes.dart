import 'package:drift/drift.dart';

import 'bons_livraison.dart';

class BonLivraisonLignes extends Table {
  @override
  String get tableName => 'BonLivraisonLignes';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get bLId =>
      integer().references(BonsLivraison, #id, onDelete: KeyAction.cascade)();
  IntColumn get produitId => integer()();
  TextColumn get designation => text()();
  RealColumn get quantiteCommandee => real().withDefault(const Constant(0))();
  RealColumn get quantiteLivree => real().withDefault(const Constant(0))();
  RealColumn get prixUnitaireHT => real()();
  RealColumn get remise => real().withDefault(const Constant(0))();
  RealColumn get tauxTVA => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get createdByUserId => integer().nullable()();
}
