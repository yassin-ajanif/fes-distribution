import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/services/distribution/bons_charge/bon_charge_service.dart';
import 'package:fes_distribution/business/services/distribution/vendeurs/user_service.dart';
import 'package:fes_distribution/business/services/stock/parametres/document_number_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_balance_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/business/services/ventes/bons_livraison/bon_livraison_service.dart';
import 'package:fes_distribution/business/services/ventes/clients/tiers_service.dart';
import 'package:fes_distribution/business/services/ventes/factures/facture_service.dart';
import 'package:fes_distribution/db/app_database.dart';

void main() {
  late AppDatabase db;
  late StockBalanceService balance;
  late BonLivraisonService bls;
  late FactureService factures;
  late int productId;
  late int clientA;
  late int clientB;
  late int vendeurId;
  late int carId;

  DocumentLine line(double qty) => DocumentLine(
    produitId: productId,
    designation: 'Peinture',
    quantite: qty,
    prixUnitaireHt: 100,
    tauxTva: 20,
  );

  Future<int> newBl(int clientId, double qty) => bls.save(
    clientId: clientId,
    vendeurId: vendeurId,
    date: DateTime.now(),
    dateEcheance: DateTime.now(),
    lines: [line(qty)],
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    final locations = StockLocationService(db);
    balance = StockBalanceService(db);
    final stock = StockMovementService(db, balance);
    final numbers = DocumentNumberService(db);
    bls = BonLivraisonService(db, numbers, locations, stock);
    factures = FactureService(db, numbers);

    final now = DateTime.now().toUtc();
    productId = await db
        .into(db.produits)
        .insert(
          ProduitsCompanion.insert(
            reference: 'P-FAC',
            designation: 'Peinture',
            unite: 'U',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.mouvementsStock)
        .insert(
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
    final vendeur = await UserService(
      db,
      locations,
    ).createVendeur(fullName: 'V', phone: '0600000009');
    vendeurId = vendeur.id;
    carId = (await locations.getOrCreateVirtualForUser(vendeur)).id;
    await BonChargeService(db, numbers, locations, stock).save(
      assignedToUserId: vendeurId,
      depotLocationId: 1,
      date: DateTime.now(),
      note: '',
      lines: [line(50)],
    );
    final tiers = TiersService(db);
    clientA = (await tiers.createClient(nom: 'A', telephone: '0601000001')).id;
    clientB = (await tiers.createClient(nom: 'B', telephone: '0601000002')).id;
  });

  tearDown(() async {
    await db.close();
  });

  test('facture groups BLs of one client without touching stock', () async {
    final bl1 = await newBl(clientA, 2);
    final bl2 = await newBl(clientA, 3);
    expect(await balance.getStock(productId, carId), 45);

    final available = await factures.availableBlsForClient(clientA);
    expect(available.map((b) => b.id), [bl1, bl2]);

    final lines = [
      ...await factures.loadBlLines(bl1),
      ...await factures.loadBlLines(bl2),
    ];
    final id = await factures.save(
      clientId: clientA,
      date: DateTime.now(),
      dateEcheance: DateTime.now(),
      lines: lines,
      blIds: [bl1, bl2],
    );

    expect(await balance.getStock(productId, carId), 45);
    final saved = await factures.getById(id);
    expect(saved!.facture.numero, startsWith('FAC-'));
    expect(saved.facture.totalTtc, closeTo(600, 0.001));
    expect(saved.bls.map((b) => b.id), [bl1, bl2]);
    expect(saved.lines.map((l) => l.bonLivraisonId), [bl1, bl2]);
    expect(await factures.availableBlsForClient(clientA), isEmpty);
    expect((await factures.list()).single.blNumeros, hasLength(2));

    await expectLater(bls.delete(bl1), throwsStateError);

    await factures.save(
      id: id,
      clientId: clientA,
      date: DateTime.now(),
      dateEcheance: DateTime.now(),
      lines: await factures.loadBlLines(bl2),
      blIds: [bl2],
    );
    expect((await factures.availableBlsForClient(clientA)).single.id, bl1);

    await factures.delete(id);
    expect(await factures.availableBlsForClient(clientA), hasLength(2));
  });

  test('BL of another client or already invoiced is refused', () async {
    final blA = await newBl(clientA, 1);
    final blB = await newBl(clientB, 1);

    await expectLater(
      factures.save(
        clientId: clientA,
        date: DateTime.now(),
        dateEcheance: DateTime.now(),
        lines: await factures.loadBlLines(blB),
        blIds: [blB],
      ),
      throwsStateError,
    );

    await factures.save(
      clientId: clientA,
      date: DateTime.now(),
      dateEcheance: DateTime.now(),
      lines: await factures.loadBlLines(blA),
      blIds: [blA],
    );
    await expectLater(
      factures.save(
        clientId: clientA,
        date: DateTime.now(),
        dateEcheance: DateTime.now(),
        lines: await factures.loadBlLines(blA),
        blIds: [blA],
      ),
      throwsStateError,
    );
  });

  test('free facture without BL is allowed', () async {
    final id = await factures.save(
      clientId: clientB,
      date: DateTime.now(),
      dateEcheance: DateTime.now(),
      estPayee: true,
      remiseGlobale: 10,
      lines: [line(1)],
    );
    final saved = await factures.getById(id);
    expect(saved!.facture.totalTtc, closeTo(108, 0.001));
    expect(saved.facture.estPayee, isTrue);
    expect(saved.bls, isEmpty);
  });
}
