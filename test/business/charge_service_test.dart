import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fes_distribution/business/services/finance/charges/charge_service.dart';
import 'package:fes_distribution/db/app_database.dart';

void main() {
  late AppDatabase db;
  late ChargeService service;
  late int loyerType;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    service = ChargeService(db);
    loyerType = await service.createType('Loyer');
    await service.createType('Énergie');
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> saveCharge({
    String libelle = 'Loyer mars',
    double montant = 25000,
    DateTime? date,
    int? typeChargeId,
    String note = '',
  }) => service.save(
    typeChargeId: typeChargeId ?? loyerType,
    libelle: libelle,
    date: date ?? DateTime.utc(2026, 3, 15),
    montantTtc: montant,
    note: note,
  );

  test('saves a charge and resolves its type name in the list', () async {
    await saveCharge();

    final rows = await service.list();
    expect(rows, hasLength(1));
    expect(rows.first.charge.libelle, 'Loyer mars');
    expect(rows.first.charge.montantTtc, 25000);
    expect(rows.first.typeNom, 'Loyer');
  });

  test('sorts newest first', () async {
    await saveCharge(libelle: 'Ancienne', date: DateTime.utc(2026, 1, 10));
    await saveCharge(libelle: 'Récente', date: DateTime.utc(2026, 5, 20));

    final rows = await service.list();
    expect(rows.first.charge.libelle, 'Récente');
    expect(rows.last.charge.libelle, 'Ancienne');
  });

  test('rejects a charge without a type, label or positive amount', () async {
    expect(() => saveCharge(typeChargeId: 0), throwsA(isA<StateError>()));
    expect(() => saveCharge(libelle: '   '), throwsA(isA<StateError>()));
    expect(() => saveCharge(montant: 0), throwsA(isA<StateError>()));
    expect(() => saveCharge(montant: -5), throwsA(isA<StateError>()));
  });

  test('updates an existing charge in place', () async {
    final id = await saveCharge();

    final sameId = await service.save(
      id: id,
      typeChargeId: await service.createType('Maintenance'),
      libelle: 'Loyer avril',
      date: DateTime.utc(2026, 4, 10),
      montantTtc: 30000,
      note: 'viré',
    );

    expect(sameId, id);
    final rows = await service.list();
    expect(rows, hasLength(1));
    expect(rows.first.charge.libelle, 'Loyer avril');
    expect(rows.first.charge.montantTtc, 30000);
    expect(rows.first.charge.note, 'viré');
    expect(rows.first.typeNom, 'Maintenance');
  });

  test('deletes a charge', () async {
    await saveCharge();
    final id = (await service.list()).first.charge.id;

    await service.delete(id);

    expect(await service.list(), isEmpty);
  });

  test('filters the list by search over libelle, note and type', () async {
    await saveCharge(libelle: 'Loyer mars', note: 'paiement virement');
    await saveCharge(
      libelle: 'Facture ENED',
      typeChargeId: await service.createType('Énergie'),
    );

    expect(
      (await service.list(search: 'loyer')).single.charge.libelle,
      'Loyer mars',
    );
    expect(
      (await service.list(search: 'virement')).single.charge.libelle,
      'Loyer mars',
    );
    // The search folds case in Dart, so the accented type is still reachable.
    expect(
      (await service.list(search: 'énergie')).single.charge.libelle,
      'Facture ENED',
    );
    expect(await service.list(search: 'inexistant'), isEmpty);
  });

  test('filters the list by an inclusive date window', () async {
    await saveCharge(libelle: 'Janvier', date: DateTime.utc(2026, 1, 31));
    await saveCharge(libelle: 'Février', date: DateTime.utc(2026, 2, 1));
    await saveCharge(libelle: 'Mars', date: DateTime.utc(2026, 3, 31));

    final rows = await service.list(
      dateFrom: DateTime.utc(2026, 2, 1),
      dateTo: DateTime.utc(2026, 3, 31),
    );

    expect(rows.map((r) => r.charge.libelle), ['Mars', 'Février']);
  });

  test('totals the whole table and the filtered window separately', () async {
    await saveCharge(montant: 100, date: DateTime.utc(2026, 1, 10));
    await saveCharge(montant: 250, date: DateTime.utc(2026, 2, 10));

    expect(await service.total(), 350);
    expect(
      await service.total(
        dateFrom: DateTime.utc(2026, 2, 1),
        dateTo: DateTime.utc(2026, 2, 28),
      ),
      250,
    );
    expect(await service.total(dateFrom: DateTime.utc(2027, 1, 1)), 0);
  });

  test('lists active types alphabetically and hides inactive ones', () async {
    final types = await service.listActiveTypes();
    expect(types.map((t) => t.nom), ['Loyer', 'Énergie']);

    await (db.update(db.typesCharges)..where((t) => t.id.equals(loyerType)))
        .write(const TypesChargesCompanion(actif: Value(false)));

    final after = await service.listActiveTypes();
    expect(after.map((t) => t.nom), ['Énergie']);
  });
}
