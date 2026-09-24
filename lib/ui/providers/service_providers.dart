import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fes_distribution/business/services/bon_charge_service.dart';
import 'package:fes_distribution/business/services/bon_decharge_service.dart';
import 'package:fes_distribution/business/services/document_number_service.dart';
import 'package:fes_distribution/business/services/produit_service.dart';
import 'package:fes_distribution/business/services/stock_balance_service.dart';
import 'package:fes_distribution/business/services/stock_location_service.dart';
import 'package:fes_distribution/business/services/stock_movement_service.dart';
import 'package:fes_distribution/business/services/user_service.dart';
import 'package:fes_distribution/business/services/vendeur_stock_service.dart';
import 'package:fes_distribution/business/workflows/bon_charge_workflow.dart';
import 'package:fes_distribution/business/workflows/bon_decharge_workflow.dart';
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

final vendeurStockServiceProvider = Provider(
  (ref) => VendeurStockService(
    ref.watch(databaseProvider),
    ref.watch(stockLocationServiceProvider),
    ref.watch(stockBalanceServiceProvider),
  ),
);

final bonChargeServiceProvider = Provider(
  (ref) => BonChargeService(ref.watch(databaseProvider)),
);

final bonDechargeServiceProvider = Provider(
  (ref) => BonDechargeService(ref.watch(databaseProvider)),
);

final bonChargeWorkflowProvider = Provider(
  (ref) => BonChargeWorkflow(
    ref.watch(databaseProvider),
    ref.watch(documentNumberServiceProvider),
    ref.watch(stockLocationServiceProvider),
    ref.watch(stockMovementServiceProvider),
  ),
);

final bonDechargeWorkflowProvider = Provider(
  (ref) => BonDechargeWorkflow(
    ref.watch(databaseProvider),
    ref.watch(documentNumberServiceProvider),
    ref.watch(stockLocationServiceProvider),
    ref.watch(stockMovementServiceProvider),
  ),
);
