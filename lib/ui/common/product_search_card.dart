import 'package:flutter/material.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/product_search_field.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';

/// Catalog autocomplete that adds a product line. [available] (optional)
/// shows the stock at the document's location next to each product.
/// [headerActions] (optional) adds buttons next to the card title.
class ProductSearchCard extends StatelessWidget {
  const ProductSearchCard({
    super.key,
    required this.produits,
    required this.onSelected,
    this.available,
    this.headerActions = const [],
  });

  final List<Produit> produits;
  final ValueChanged<Produit> onSelected;
  final Map<int, double>? available;
  final List<Widget> headerActions;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.addProduct,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ...headerActions,
              ],
            ),
            const SizedBox(height: 8),
            ProductSearchField(
              produits: produits,
              onSelected: onSelected,
              available: available,
            ),
          ],
        ),
      ),
    );
  }
}
