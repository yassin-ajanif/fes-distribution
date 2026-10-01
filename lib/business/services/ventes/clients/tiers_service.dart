import 'package:drift/drift.dart';
import 'package:fes_distribution/business/enums/type_tiers.dart';
import 'package:fes_distribution/db/app_database.dart';

class TiersService {
  TiersService(this._db);

  final AppDatabase _db;

  /// Active tiers that can be sold to (`Client` or `LesDeux`), sorted by name.
  Future<List<Tier>> listActiveClients() =>
      _listActive(const [TypeTiers.client, TypeTiers.lesDeux]);

  /// Active tiers that can be bought from (`Fournisseur` or `LesDeux`),
  /// sorted by name.
  Future<List<Tier>> listActiveFournisseurs() =>
      _listActive(const [TypeTiers.fournisseur, TypeTiers.lesDeux]);

  Future<Tier?> getById(int id) =>
      (_db.select(_db.tiers)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Tier> createClient({
    required String nom,
    String telephone = '',
    String ville = '',
    String adresse = '',
    String ice = '',
    int? createdByUserId,
  }) {
    if (nom.trim().isEmpty) {
      throw StateError('Le nom du client est obligatoire.');
    }
    return _create(
      type: TypeTiers.client,
      nom: nom,
      telephone: telephone,
      ville: ville,
      adresse: adresse,
      ice: ice,
      createdByUserId: createdByUserId,
    );
  }

  Future<Tier> createFournisseur({
    required String nom,
    String telephone = '',
    String ville = '',
    String adresse = '',
    String ice = '',
    int? createdByUserId,
  }) {
    if (nom.trim().isEmpty) {
      throw StateError('Le nom du fournisseur est obligatoire.');
    }
    return _create(
      type: TypeTiers.fournisseur,
      nom: nom,
      telephone: telephone,
      ville: ville,
      adresse: adresse,
      ice: ice,
      createdByUserId: createdByUserId,
    );
  }

  Future<List<Tier>> _listActive(List<int> types) async {
    final rows = await (_db.select(
      _db.tiers,
    )..where((t) => t.actif.equals(true) & t.type.isIn(types))).get();
    rows.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    return rows;
  }

  Future<Tier> _create({
    required int type,
    required String nom,
    required String telephone,
    required String ville,
    required String adresse,
    required String ice,
    int? createdByUserId,
  }) async {
    final phone = _requirePhone(telephone);
    await _ensurePhoneFree(phone);

    final now = DateTime.now().toUtc();
    final id = await _db
        .into(_db.tiers)
        .insert(
          TiersCompanion.insert(
            type: type,
            nom: nom.trim(),
            ice: ice.trim(),
            adresse: adresse.trim(),
            ville: ville.trim(),
            telephone: phone,
            email: '',
            conditionsPaiement: '',
            createdAt: now,
            updatedAt: now,
            createdByUserId: Value(createdByUserId),
          ),
        );
    return (await getById(id))!;
  }

  /// The phone is what tells two same-named tiers apart, so it is required —
  /// and unique, exactly like a vendeur's.
  String _requirePhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) {
      throw StateError('Le téléphone est obligatoire.');
    }
    return trimmed;
  }

  /// Unique across every tier, whatever its type: one phone means one
  /// counterparty. Someone who is both a client and a supplier is a `LesDeux`
  /// tier, not two rows sharing a number.
  Future<void> _ensurePhoneFree(String phone) async {
    final clash =
        await (_db.select(_db.tiers)
              ..where((t) => t.telephone.equals(phone))
              ..limit(1))
            .getSingleOrNull();
    if (clash == null) return;
    throw StateError(
      'Le numéro $phone est déjà utilisé par « ${clash.nom} ». '
      'Sélectionnez ce compte au lieu d\'en créer un second.',
    );
  }
}
