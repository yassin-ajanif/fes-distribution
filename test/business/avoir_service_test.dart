import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/services/distribution/bons_charge/bon_charge_service.dart';
import 'package:fes_distribution/business/services/distribution/vendeurs/user_service.dart';
import 'package:fes_distribution/business/services/stock/parametres/document_number_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_balance_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/business/services/ventes/avoirs/avoir_service.dart';
import 'package:fes_distribution/business/services/ventes/bons_livraison/bon_livraison_service.dart';
import 'package:fes_distribution/business/services/ventes/clients/tiers_service.dart';
import 'package:fes_distribution/business/services/ventes/factures/facture_service.dart';
import 'package:fes_distribution/db/app_database.dart';

void main() {
  late AppDatabase db;
  late StockBalanceService balance;
  late StockLocationService locations;
  late AvoirService avoirs;
  late FactureService factures;
  late int productId;
  late int clientId;
  late int vendeurA;
  late int vendeurB;
  late int carA;
  late int carB;
  late int factureId;

  DocumentLine line(double qty) => DocumentLine(
        produitId: productId,
        designation: 'Peinture',
        quantite: qty,
        prixUnitaireHt: 100,
        tauxTva: 20,
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    locations = StockLocationService(db);
    balance = StockBalanceService(db);
    final stock = StockMovementService(db, balance);
    final numbers = DocumentNumberService(db);
    avoirs = AvoirService(db, numbers, locations, stock);
    factures = FactureService(db, numbers);
    final bls = BonLivraisonService(db, numbers, locations, stock);

    final now = DateTime.now().toUtc();
    productId = await db.into(db.produits).insert(
          ProduitsCompanion.insert(
            reference: 'P-AVO',
            designation: 'Peinture',
            unite: 'U',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.mouvementsStock).insert(
          MouvementsStockCompanion.insert(
            produitId: productId,
            toLocationId: const Value(1),
            quantite: 100,
            toApres: const Value(100),
            origineType: 'Import',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final users = UserService(db, locations);
    final a = await users.createVendeur(fullName: 'A', phone: '0600000011');
    final b = await users.createVendeur(fullName: 'B', phone: '0600000012');
    vendeurA = a.id;
    vendeurB = b.id;
    carA = (await locations.getOrCreateVirtualForUser(a)).id;
    carB = (await locations.getOrCreateVirtualForUser(b)).id;
    await BonChargeService(db, numbers, locations, stock).save(
      assignedToUserId: vendeurA,
      depotLocationId: 1,
      date: DateTime.now(),
      note: '',
      lines: [line(10)],
    );
    clientId = (await TiersService(db).createClient(nom: 'Client')).id;
    final blId = await bls.save(
      clientId: clientId,
      vendeurId: vendeurA,
      date: DateTime.now(),
      dateEcheance: DateTime.now(),
      lines: [line(5)],
    );
    factureId = await factures.save(
      clientId: clientId,
      date: DateTime.now(),
      dateEcheance: DateTime.now(),
      lines: await factures.loadBlLines(blId),
      blIds: [blId],
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('returned goods go back to the vendeur car; edit, switch, delete',
      () async {
    expect(await balance.getStock(productId, carA), 5);
    expect(await avoirs.vendeurForFacture(factureId), vendeurA);
    final lines = await avoirs.loadFactureLines(factureId);
    expect(lines.single.quantite, 1);

    final id = await avoirs.save(
      clientId: clientId,
      factureId: factureId,
      date: DateTime.now(),
      vendeurId: vendeurA,
      lines: [line(2)],
    );
    expect(await balance.getStock(productId, carA), 7);
    final saved = await avoirs.getById(id);
    expect(saved!.avoir.numero, startsWith('AVO-'));
    expect(saved.vendeurId, vendeurA);
    final row = (await avoirs.list()).single;
    expect(row.totalTtc, closeTo(240, 0.001));
    expect(row.factureNumero, startsWith('FAC-'));

    await avoirs.save(
      id: id,
      clientId: clientId,
      factureId: factureId,
      date: DateTime.now(),
      vendeurId: vendeurB,
      lines: [line(2)],
    );
    expect(await balance.getStock(productId, carA), 5);
    expect(await balance.getStock(productId, carB), 2);
    expect((await avoirs.getById(id))!.vendeurId, vendeurB);

    await avoirs.save(
      id: id,
      clientId: clientId,
      date: DateTime.now(),
      retourMarchandise: false,
      lines: [line(2)],
    );
    expect(await balance.getStock(productId, carB), 0);
    expect((await avoirs.getById(id))!.vendeurId, isNull);

    await expectLater(factures.delete(factureId), completes);
  });

  test('avoirs on a facture cannot exceed its TTC', () async {
    expect(await avoirs.remainingOnFacture(factureId), closeTo(600, 0.001));
    await avoirs.save(
      clientId: clientId,
      factureId: factureId,
      date: DateTime.now(),
      retourMarchandise: false,
      lines: [line(4)],
    );
    expect(await avoirs.remainingOnFacture(factureId), closeTo(120, 0.001));
    await expectLater(
      avoirs.save(
        clientId: clientId,
        factureId: factureId,
        date: DateTime.now(),
        retourMarchandise: false,
        lines: [line(2)],
      ),
      throwsStateError,
    );
    await expectLater(factures.delete(factureId), throwsStateError);
  });

  test('delete takes returned goods back out of the car', () async {
    final id = await avoirs.save(
      clientId: clientId,
      date: DateTime.now(),
      vendeurId: vendeurA,
      lines: [line(3)],
    );
    expect(await balance.getStock(productId, carA), 8);
    await avoirs.delete(id);
    expect(await balance.getStock(productId, carA), 5);
    expect(await avoirs.list(), isEmpty);
  });
}
