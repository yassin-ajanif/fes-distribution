import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fes_distribution/business/enums/type_tiers.dart';
import 'package:fes_distribution/business/services/ventes/clients/tiers_service.dart';
import 'package:fes_distribution/db/app_database.dart';

void main() {
  late AppDatabase db;
  late TiersService tiers;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tiers = TiersService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('a client needs a phone', () async {
    await expectLater(tiers.createClient(nom: 'Ali'), throwsStateError);
    await expectLater(
      tiers.createFournisseur(nom: 'Societe Atlas'),
      throwsStateError,
    );
    // Whitespace is not a phone either.
    await expectLater(
      tiers.createClient(nom: 'Ali', telephone: '   '),
      throwsStateError,
    );
  });

  test('the phone is trimmed on the way in', () async {
    final client = await tiers.createClient(
      nom: 'Ali',
      telephone: ' 0661234567 ',
    );

    expect(client.telephone, '0661234567');
  });

  test(
    'one phone means one counterparty, across client and supplier',
    () async {
      await tiers.createClient(nom: 'Ali', telephone: '0661234567');

      // Same type: refused.
      await expectLater(
        tiers.createClient(nom: 'Ali Benali', telephone: '0661234567'),
        throwsStateError,
      );
      // And across types too, since it is the same real counterparty.
      await expectLater(
        tiers.createFournisseur(nom: 'Ali', telephone: '0661234567'),
        throwsStateError,
      );
      // A different phone is fine, same name or not.
      final other = await tiers.createFournisseur(
        nom: 'Ali',
        telephone: '0669999999',
      );
      expect(other.nom, 'Ali');
    },
  );

  test('the same name twice is allowed as long as the phones differ', () async {
    final a = await tiers.createClient(nom: 'Ali', telephone: '0661111111');
    final b = await tiers.createClient(nom: 'Ali', telephone: '0662222222');

    expect(a.id, isNot(b.id));

    // Both stay selectable, which is exactly why the pickers show the phone.
    final clients = await tiers.listActiveClients();
    expect(
      clients.where((c) => c.nom == 'Ali').map((c) => c.telephone),
      containsAll(['0661111111', '0662222222']),
    );
  });

  test('active lists still split clients from suppliers', () async {
    await tiers.createClient(nom: 'Client A', telephone: '0661111111');
    await tiers.createFournisseur(
      nom: 'Fournisseur B',
      telephone: '0662222222',
    );

    expect(
      (await tiers.listActiveClients()).map((c) => c.nom),
      contains('Client A'),
    );
    expect(
      (await tiers.listActiveClients()).map((c) => c.nom),
      isNot(contains('Fournisseur B')),
    );
    expect((await tiers.listActiveFournisseurs()).map((f) => f.nom), [
      'Fournisseur B',
    ]);
  });

  test('a LesDeux tier is listed on both sides', () async {
    await db
        .into(db.tiers)
        .insert(
          TiersCompanion.insert(
            type: TypeTiers.lesDeux,
            nom: 'Grand Comptoir',
            ice: '',
            adresse: '',
            ville: '',
            telephone: '0663333333',
            email: '',
            conditionsPaiement: '',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );

    expect(
      (await tiers.listActiveClients()).map((c) => c.nom),
      contains('Grand Comptoir'),
    );
    expect((await tiers.listActiveFournisseurs()).map((f) => f.nom), [
      'Grand Comptoir',
    ]);
  });
}
