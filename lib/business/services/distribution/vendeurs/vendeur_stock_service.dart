import 'package:fes_distribution/business/models/vendeur_stock_line.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_balance_service.dart';
import 'package:fes_distribution/business/services/stock/stock/stock_location_service.dart';
import 'package:fes_distribution/db/app_database.dart';

class VendeurStockService {
  VendeurStockService(this._db, this._locations, this._balance);

  final AppDatabase _db;
  final StockLocationService _locations;
  final StockBalanceService _balance;

  Future<List<VendeurStockLine>> getStockLines(User user) async {
    final location = await _locations.getOrCreateVirtualForUser(user);
    final products = await (_db.select(_db.produits)
          ..where((p) => p.actif.equals(true)))
        .get();

    final lines = <VendeurStockLine>[];
    for (final product in products) {
      final qty = await _balance.getStock(product.id, location.id);
      if (qty <= 0) continue;
      lines.add(
        VendeurStockLine(
          produitId: product.id,
          reference: product.reference,
          designation: product.designation,
          quantite: qty,
          prixVenteHt: product.prixVenteHT,
          tauxTva: product.tauxTVA,
        ),
      );
    }

    lines.sort((a, b) => a.reference.compareTo(b.reference));
    return lines;
  }

  Future<({double qtyTotal, double valVenteTtc})> getStockTotals(
    User user,
  ) async {
    final lines = await getStockLines(user);
    var qty = 0.0;
    var val = 0.0;
    for (final line in lines) {
      qty += line.quantite;
      val += line.valVenteTtc;
    }
    return (qtyTotal: qty, valVenteTtc: val);
  }
}
