import 'package:flutter/material.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';

/// Catalog autocomplete that adds a product line. [available] (optional)
/// shows the stock at the document's location next to each product.
class ProductSearchCard extends StatelessWidget {
  const ProductSearchCard({
    super.key,
    required this.produits,
    required this.onSelected,
    this.available,
  });

  final List<Produit> produits;
  final ValueChanged<Produit> onSelected;
  final Map<int, double>? available;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.addProduct, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Autocomplete<Produit>(
              optionsBuilder: (text) {
                final t = text.text.toLowerCase();
                if (t.isEmpty) return produits.take(20);
                return produits.where(
                  (p) =>
                      p.reference.toLowerCase().contains(t) ||
                      p.designation.toLowerCase().contains(t) ||
                      (p.codeBarre?.toLowerCase().contains(t) ?? false),
                );
              },
              displayStringForOption: (p) => available == null
                  ? '${p.reference} — ${p.designation}'
                  : '${p.reference} — ${p.designation} '
                      '(${s.available(formatQty(available![p.id] ?? 0))})',
              onSelected: onSelected,
              fieldViewBuilder: (context, controller, focusNode, _) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: s.searchProduct,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onTap: controller.clear,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
