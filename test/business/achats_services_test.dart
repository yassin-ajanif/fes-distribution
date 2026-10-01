import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fes_distribution/business/enums/mode_paiement.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/business/models/document_paiement.dart';
import 'package:fes_distribution/business/services/achats/avoirs_fournisseur/avoir_fournisseur_service.dart';
import 'package:fes_distribution/business/services/achats/bons_reception/bon_reception_service.dart';
import 'package:fes_distribution/business/services/achats/factures_fournisseur/facture_fournisseur_service.dart';
import 'package:fes_distribution/business/services/stock/parametres/document_number_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_balance_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/business/services/ventes/clients/tiers_service.dart';
import 'package:fes_distribution/db/app_database.dart';

void main() {
  late AppDatabase db;
  late StockBalanceService balance;
  late StockLocationService locations;
  late BonReceptionService brs;
  late FactureFournisseurService factures;
  late AvoirFournisseurService avoirs;
  late int productId;
  late int fournisseurA;
  late int fournisseurB;
  late int depotId;

  DocumentLine line(double qty, {double prix = 100}) => DocumentLine(
    produitId: productId,
    designation: 'Peinture',
    quantite: qty,
    prixUnitaireHt: prix,
    tauxTva: 20,
  );

  Future<int> newBr(int fournisseurId, double qty, {double prix = 100}) =>
      brs.save(
        fournisseurId: fournisseurId,
        date: DateTime.now(),
        lines: [line(qty, prix: prix)],
      );

  Future<double> prixAchat() async => (await (db.select(
    db.produits,
  )..where((p) => p.id.equals(productId))).getSingle()).prixAchatHT;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    locations = StockLocationService(db);
    balance = StockBalanceService(db);
    final stock = StockMovementService(db, balance);
    final numbers = DocumentNumberService(db);
    brs = BonReceptionService(db, numbers, locations, stock);
    factures = FactureFournisseurService(db, numbers);
    avoirs = AvoirFournisseurService(db, numbers, locations, stock);

    final now = DateTime.now().toUtc();
    productId = await db
        .into(db.produits)
        .insert(
          ProduitsCompanion.insert(
            reference: 'P-ACH',
            designation: 'Peinture',
            unite: 'U',
            createdAt: now,
            updatedAt: now,
          ),
        );
    depotId = (await locations.getOrCreateDefaultDepot()).id;
    final tiers = TiersService(db);
    fournisseurA = (await tiers.createFournisseur(
      nom: 'Fournisseur A',
      telephone: '0601000001',
    )).id;
    fournisseurB = (await tiers.createFournisseur(
      nom: 'Fournisseur B',
      telephone: '0601000002',
    )).id;
  });

  tearDown(() async {
    await db.close();
  });

  test('suppliers are listed apart from clients', () async {
    await TiersService(db).createClient(nom: 'Client', telephone: '0601000003');
    final list = await TiersService(db).listActiveFournisseurs();
    expect(list.map((t) => t.nom), ['Fournisseur A', 'Fournisseur B']);
  });

  test(
    'BR adds stock to the default depot and averages the purchase price',
    () async {
      final id = await newBr(fournisseurA, 10, prix: 100);
      expect(await balance.getStock(productId, depotId), 10);
      expect(await prixAchat(), closeTo(100, 0.001));

      await newBr(fournisseurA, 10, prix: 200);
      expect(await balance.getStock(productId, depotId), 20);
      expect(await prixAchat(), closeTo(150, 0.001));

      final saved = await brs.getById(id);
      expect(saved!.br.numero, startsWith('BR-'));
      expect(saved.br.totalTtc, closeTo(1200, 0.001));

      await brs.save(
        id: id,
        fournisseurId: fournisseurA,
        date: DateTime.now(),
        lines: [line(4)],
      );
      expect(await balance.getStock(productId, depotId), 14);

      await brs.delete(id);
      expect(await balance.getStock(productId, depotId), 10);
      expect(await brs.list(), hasLength(1));
    },
  );

  test(
    'facture fournisseur groups BRs, no stock and no money impact',
    () async {
      final br1 = await newBr(fournisseurA, 2);
      final br2 = await newBr(fournisseurA, 3);
      expect(await balance.getStock(productId, depotId), 5);

      final lines = [
        ...await factures.loadBrLines(br1),
        ...await factures.loadBrLines(br2),
      ];
      final id = await factures.save(
        fournisseurId: fournisseurA,
        date: DateTime.now(),
        dateEcheance: DateTime.now(),
        lines: lines,
        brIds: [br1, br2],
      );

      expect(await balance.getStock(productId, depotId), 5);
      final saved = await factures.getById(id);
      expect(saved!.facture.numero, startsWith('FAF-'));
      expect(saved.facture.totalTtc, closeTo(600, 0.001));
      expect(saved.brs.map((b) => b.id), [br1, br2]);
      expect(saved.lines.map((l) => l.bonReceptionId), [br1, br2]);
      expect(await factures.availableBrsForFournisseur(fournisseurA), isEmpty);
      final row = (await factures.list()).single;
      expect(row.brNumeros, hasLength(2));

      await expectLater(brs.delete(br1), throwsStateError);
      expect((await brs.getById(br1))!.factureNumero, saved.facture.numero);

      await factures.delete(id);
      expect(
        await factures.availableBrsForFournisseur(fournisseurA),
        hasLength(2),
      );
    },
  );

  test(
    'BR carries the supplier payment, so deleting the facture keeps it',
    () async {
      final brId = await brs.save(
        fournisseurId: fournisseurA,
        date: DateTime.now(),
        lines: [line(4)], // 480 TTC, the helper line carries 20 % TVA
        paiements: [DocumentPaiement(date: DateTime.now(), montant: 150)],
      );

      final doc = await brs.getById(brId);
      expect(doc!.br.estPayee, isFalse);
      expect(doc.paiements.single.montant, 150);
      expect(doc.paiements.single.mode, ModePaiement.especes);
      expect((await brs.list()).single.resteAPayer, closeTo(330, 0.001));

      // Paying the rest flips estPayee, like a settled BL.
      await brs.save(
        id: brId,
        fournisseurId: fournisseurA,
        date: DateTime.now(),
        lines: [line(4)],
        paiements: [DocumentPaiement(date: DateTime.now(), montant: 480)],
      );
      final settled = await brs.getById(brId);
      expect(settled!.br.estPayee, isTrue);
      expect((await brs.list()).single.resteAPayer, 0);

      // Invoicing does not touch the money: it lives on the BR now.
      final factureId = await factures.save(
        fournisseurId: fournisseurA,
        date: DateTime.now(),
        dateEcheance: DateTime.now(),
        lines: await factures.loadBrLines(brId),
        brIds: [brId],
      );
      await factures.delete(factureId);
      expect((await brs.getById(brId))!.paiements.single.montant, 480);

      await brs.delete(brId);
      expect(await db.select(db.paiementsFournisseurs).get(), isEmpty);
    },
  );

  test(
    'a BR cannot be overpaid and deleting it takes its payments with it',
    () async {
      await expectLater(
        brs.save(
          fournisseurId: fournisseurA,
          date: DateTime.now(),
          lines: [line(1)], // 120 TTC
          paiements: [DocumentPaiement(date: DateTime.now(), montant: 500)],
        ),
        throwsStateError,
      );

      final brId = await brs.save(
        fournisseurId: fournisseurA,
        date: DateTime.now(),
        lines: [line(1)],
        paiements: [DocumentPaiement(date: DateTime.now(), montant: 120)],
      );
      await brs.delete(brId);
      expect(await db.select(db.paiementsFournisseurs).get(), isEmpty);
    },
  );

  test('BR of another supplier is refused on a supplier facture', () async {
    final brB = await newBr(fournisseurB, 1);
    await expectLater(
      factures.save(
        fournisseurId: fournisseurA,
        date: DateTime.now(),
        dateEcheance: DateTime.now(),
        lines: await factures.loadBrLines(brB),
        brIds: [brB],
      ),
      throwsStateError,
    );
  });

  test(
    'avoir fournisseur with goods return takes stock out of the depot',
    () async {
      await newBr(fournisseurA, 10);

      final id = await avoirs.save(
        fournisseurId: fournisseurA,
        date: DateTime.now(),
        motif: 'Défaut',
        lines: [line(3)],
      );
      expect(await balance.getStock(productId, depotId), 7);
      final saved = await avoirs.getById(id);
      expect(saved!.avoir.numero, startsWith('AVF-'));
      expect((await avoirs.list()).single.totalTtc, closeTo(360, 0.001));

      await avoirs.save(
        id: id,
        fournisseurId: fournisseurA,
        date: DateTime.now(),
        retourMarchandise: false,
        lines: [line(3)],
      );
      expect(await balance.getStock(productId, depotId), 10);

      await avoirs.save(
        id: id,
        fournisseurId: fournisseurA,
        date: DateTime.now(),
        lines: [line(2)],
      );
      expect(await balance.getStock(productId, depotId), 8);

      await avoirs.delete(id);
      expect(await balance.getStock(productId, depotId), 10);
    },
  );
}
