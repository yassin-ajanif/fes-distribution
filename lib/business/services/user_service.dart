import 'package:drift/drift.dart';
import 'package:fes_distribution/business/enums/user_type.dart';
import 'package:fes_distribution/business/services/stock_location_service.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/db/db_seeder.dart';

class UserService {
  UserService(this._db, this._locations);

  final AppDatabase _db;
  final StockLocationService _locations;

  Future<List<User>> listVendeurs({String? search}) async {
    final depotPhone = DbSeeder.depotPrincipalAdminPhone;
    var query = _db.select(_db.users)
      ..where(
        (u) =>
            u.userType.equals(UserType.vendeur) |
            u.phone.equals(depotPhone),
      );

    if (search != null && search.trim().isNotEmpty) {
      final t = search.trim().toLowerCase();
      query = _db.select(_db.users)
        ..where(
          (u) =>
              (u.userType.equals(UserType.vendeur) |
                  u.phone.equals(depotPhone)) &
              (u.fullName.lower().like('%$t%') | u.phone.lower().like('%$t%')),
        );
    }

    final rows = await query.get();
    rows.sort((a, b) {
      final aDepot = a.phone == depotPhone ? 0 : 1;
      final bDepot = b.phone == depotPhone ? 0 : 1;
      if (aDepot != bDepot) return aDepot.compareTo(bDepot);
      final nameCmp = a.fullName.compareTo(b.fullName);
      if (nameCmp != 0) return nameCmp;
      return a.phone.compareTo(b.phone);
    });
    return rows;
  }

  Future<List<User>> listActiveVendeurs() async {
    final rows = await listVendeurs();
    return rows.where((u) => u.actif && u.userType == UserType.vendeur).toList();
  }

  Future<User?> getById(int id) async {
    final depotPhone = DbSeeder.depotPrincipalAdminPhone;
    return (_db.select(_db.users)
          ..where(
            (u) =>
                u.id.equals(id) &
                (u.userType.equals(UserType.vendeur) |
                    u.phone.equals(depotPhone)),
          ))
        .getSingleOrNull();
  }

  Future<User> createVendeur({
    required String fullName,
    required String phone,
    bool actif = true,
  }) async {
    final phoneTrim = _requirePhone(phone);
    final nameTrim = _requireName(fullName);

    if (DbSeeder.isDepotPrincipalAdminPhone(phoneTrim)) {
      throw StateError('Ce numéro est réservé au dépôt principal.');
    }

    final exists = await (_db.select(_db.users)
          ..where((u) => u.phone.equals(phoneTrim)))
        .getSingleOrNull();
    if (exists != null) {
      throw StateError('Ce numéro est déjà utilisé.');
    }

    final now = DateTime.now().toUtc();
    final id = await _db.into(_db.users).insert(
          UsersCompanion.insert(
            fullName: nameTrim,
            phone: phoneTrim,
            userType: const Value(UserType.vendeur),
            actif: Value(actif),
            createdAt: now,
          ),
        );
    final user = await (_db.select(_db.users)..where((u) => u.id.equals(id)))
        .getSingle();
    await _locations.getOrCreateVirtualForUser(user);
    return user;
  }

  Future<void> updateVendeur({
    required int id,
    required String fullName,
    required String phone,
    required bool actif,
  }) async {
    final phoneTrim = _requirePhone(phone);
    final nameTrim = _requireName(fullName);

    final user = await (_db.select(_db.users)..where((u) => u.id.equals(id)))
        .getSingleOrNull();
    if (user == null) throw StateError('Vendeur introuvable.');
    if (DbSeeder.isDepotPrincipalAdmin(user)) {
      throw StateError('Le dépôt principal ne peut pas être modifié.');
    }
    if (user.userType != UserType.vendeur) {
      throw StateError('Vendeur introuvable.');
    }
    if (DbSeeder.isDepotPrincipalAdminPhone(phoneTrim)) {
      throw StateError('Ce numéro est réservé au dépôt principal.');
    }

    final duplicate = await (_db.select(_db.users)
          ..where((u) => u.phone.equals(phoneTrim) & u.id.equals(id).not()))
        .getSingleOrNull();
    if (duplicate != null) {
      throw StateError('Ce numéro est déjà utilisé.');
    }

    await (_db.update(_db.users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(
        fullName: Value(nameTrim),
        phone: Value(phoneTrim),
        actif: Value(actif),
      ),
    );

    final virtualStock = await (_db.select(_db.stockLocations)
          ..where((l) => l.isVirtual.equals(true) & l.userId.equals(id)))
        .getSingleOrNull();
    if (virtualStock != null) {
      await (_db.update(_db.stockLocations)
            ..where((l) => l.id.equals(virtualStock.id)))
          .write(
        StockLocationsCompanion(
          nom: Value(nameTrim),
          actif: Value(actif),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    } else {
      final updated = await (_db.select(_db.users)..where((u) => u.id.equals(id)))
          .getSingle();
      await _locations.getOrCreateVirtualForUser(updated);
    }
  }

  Future<void> deleteVendeur(int id) async {
    final user = await (_db.select(_db.users)..where((u) => u.id.equals(id)))
        .getSingleOrNull();
    if (user == null) throw StateError('Vendeur introuvable.');
    if (DbSeeder.isDepotPrincipalAdmin(user)) {
      throw StateError('Le dépôt principal ne peut pas être supprimé.');
    }
    if (user.userType != UserType.vendeur) {
      throw StateError('Vendeur introuvable.');
    }

    final usedInCharge = await (_db.select(_db.bonsCharge)
          ..where((b) => b.assignedToUserId.equals(id)))
        .getSingleOrNull();
    if (usedInCharge != null) {
      throw StateError('Ce vendeur est utilisé par des bons de charge.');
    }

    final usedInDecharge = await (_db.select(_db.bonsDecharge)
          ..where((b) => b.assignedToUserId.equals(id)))
        .getSingleOrNull();
    if (usedInDecharge != null) {
      throw StateError('Ce vendeur est utilisé par des bons de décharge.');
    }

    await (_db.delete(_db.users)..where((u) => u.id.equals(id))).go();
  }

  String _requirePhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) throw StateError('Le téléphone est obligatoire.');
    return trimmed;
  }

  String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw StateError('Le nom est obligatoire.');
    return trimmed;
  }
}
