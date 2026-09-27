import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fes_distribution/business/services/distribution/bons_charge/bon_charge_service.dart';
import 'package:fes_distribution/business/services/distribution/bons_decharge/bon_decharge_service.dart';
import 'package:fes_distribution/business/services/stock/produits/categorie_service.dart';
import 'package:fes_distribution/business/services/stock/parametres/document_number_service.dart';
import 'package:fes_distribution/business/services/stock/produits/produit_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_balance_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_movement_service.dart';
import 'package:fes_distribution/business/services/distribution/vendeurs/user_service.dart';
import 'package:fes_distribution/business/services/distribution/vendeurs/vendeur_stock_service.dart';
import 'package:fes_distribution/business/services/ventes/bons_livraison/bon_livraison_service.dart';
import 'package:fes_distribution/business/services/ventes/clients/tiers_service.dart';
import 'package:fes_distribution/business/services/ventes/factures/facture_service.dart';
import 'package:fes_distribution/db/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden in main.dart');
});

final stockLocationServiceProvider = Provider(
  (ref) => StockLocationService(ref.watch(databaseProvider)),
);

final stockBalanceServiceProvider = Provider(
  (ref) => StockBalanceService(ref.watch(databaseProvider)),
);

final stockMovementServiceProvider = Provider(
  (ref) => StockMovementService(
    ref.watch(databaseProvider),
    ref.watch(stockBalanceServiceProvider),
  ),
);

final documentNumberServiceProvider = Provider(
  (ref) => DocumentNumberService(ref.watch(databaseProvider)),
);

final userServiceProvider = Provider(
  (ref) => UserService(
    ref.watch(databaseProvider),
    ref.watch(stockLocationServiceProvider),
  ),
);

final produitServiceProvider = Provider(
  (ref) => ProduitService(ref.watch(databaseProvider)),
);

final categorieServiceProvider = Provider(
  (ref) => CategorieService(ref.watch(databaseProvider)),
);

final vendeurStockServiceProvider = Provider(
  (ref) => VendeurStockService(
    ref.watch(databaseProvider),
    ref.watch(stockLocationServiceProvider),
    ref.watch(stockBalanceServiceProvider),
  ),
);

final bonChargeServiceProvider = Provider(
  (ref) => BonChargeService(
    ref.watch(databaseProvider),
    ref.watch(documentNumberServiceProvider),
    ref.watch(stockLocationServiceProvider),
    ref.watch(stockMovementServiceProvider),
  ),
);

final tiersServiceProvider = Provider(
  (ref) => TiersService(ref.watch(databaseProvider)),
);

final bonLivraisonServiceProvider = Provider(
  (ref) => BonLivraisonService(
    ref.watch(databaseProvider),
    ref.watch(documentNumberServiceProvider),
    ref.watch(stockLocationServiceProvider),
    ref.watch(stockMovementServiceProvider),
  ),
);

final factureServiceProvider = Provider(
  (ref) => FactureService(
    ref.watch(databaseProvider),
    ref.watch(documentNumberServiceProvider),
  ),
);

final bonDechargeServiceProvider = Provider(
  (ref) => BonDechargeService(
    ref.watch(databaseProvider),
    ref.watch(documentNumberServiceProvider),
    ref.watch(stockLocationServiceProvider),
    ref.watch(stockMovementServiceProvider),
  ),
);
