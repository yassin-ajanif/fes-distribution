import 'package:drift/drift.dart';
import 'package:fes_distribution/business/enums/type_tiers.dart';
import 'package:fes_distribution/db/app_database.dart';

class TiersService {
  TiersService(this._db);

  final AppDatabase _db;

  /// Active tiers that can be sold to (`Client` or `LesDeux`), sorted by name.
  Future<List<Tier>> listActiveClients() async {
    final rows = await (_db.select(_db.tiers)
          ..where(
            (t) =>
                t.actif.equals(true) &
                t.type.isIn(const [TypeTiers.client, TypeTiers.lesDeux]),
          ))
        .get();
    rows.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    return rows;
  }

  Future<Tier?> getById(int id) =>
      (_db.select(_db.tiers)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Tier> createClient({
    required String nom,
    String telephone = '',
    String ville = '',
    String adresse = '',
    String ice = '',
    int? createdByUserId,
  }) async {
    final nomTrim = nom.trim();
    if (nomTrim.isEmpty) throw StateError('Le nom du client est obligatoire.');

    final now = DateTime.now().toUtc();
    final id = await _db.into(_db.tiers).insert(
          TiersCompanion.insert(
            type: TypeTiers.client,
            nom: nomTrim,
            ice: ice.trim(),
            adresse: adresse.trim(),
            ville: ville.trim(),
            telephone: telephone.trim(),
            email: '',
            conditionsPaiement: '',
            createdAt: now,
            updatedAt: now,
            createdByUserId: Value(createdByUserId),
          ),
        );
    return (await getById(id))!;
  }
}
