import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/barcode_scanner_page.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/product_image.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';

/// Catalog lookup used by every document that adds product lines: a text
/// autocomplete over reference / designation / barcode, plus a camera scan
/// button that adds the scanned product directly.
/// [available] (optional) shows the stock at the document's location next to
/// each product.
class ProductSearchField extends ConsumerStatefulWidget {
  const ProductSearchField({
    super.key,
    required this.produits,
    required this.onSelected,
    this.available,
  });

  final List<Produit> produits;
  final ValueChanged<Produit> onSelected;
  final Map<int, double>? available;

  @override
  ConsumerState<ProductSearchField> createState() =>
      _ProductSearchFieldState();
}

class _ProductSearchFieldState extends ConsumerState<ProductSearchField> {
  /// Owned here so the field can be emptied after a scan, ready for the next
  /// barcode without the user re-focusing it. Autocomplete requires
  /// `focusNode` and `textEditingController` to be passed together or not at
  /// all, hence the focus node.
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    // Close the options list and drop the keyboard before the camera opens.
    _focusNode.unfocus();

    final code = await scanBarcode(context);
    if (code == null || code.trim().isEmpty || !mounted) return;

    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);

    Produit? scanned;
    try {
      scanned = await ref
          .read(produitServiceProvider)
          .findByCodeBarre(code);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(s.scanFailed('$e'))));
      return;
    }

    if (scanned == null) {
      messenger.showSnackBar(SnackBar(content: Text(s.barcodeNotFound)));
      return;
    }

    _controller.clear();
    widget.onSelected(scanned);
    messenger.showSnackBar(
      SnackBar(content: Text(s.barcodeFound(scanned.designation))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final available = widget.available;

    return Autocomplete<Produit>(
      focusNode: _focusNode,
      textEditingController: _controller,
      optionsBuilder: (text) {
        final t = text.text.toLowerCase();
        if (t.isEmpty) return widget.produits.take(20);
        return widget.produits.where(
          (p) =>
              p.reference.toLowerCase().contains(t) ||
              p.designation.toLowerCase().contains(t) ||
              (p.codeBarre?.toLowerCase().contains(t) ?? false),
        );
      },
      displayStringForOption: (p) => available == null
          ? '${p.reference} — ${p.designation}'
          : '${p.reference} — ${p.designation} '
                '(${s.available(formatQty(available[p.id] ?? 0))})',
      onSelected: widget.onSelected,
      optionsViewBuilder: (ctx, onSelected, options) {
        final items = options.toList();
        final muted = Theme.of(ctx).colorScheme.outline;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 520),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final p = items[i];
                  return InkWell(
                    onTap: () => onSelected(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          ProductThumbnail(bytes: p.imageData),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${p.reference} — ${p.designation}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                // No price here: purchase documents type
                                // their own unit price, so showing the sale
                                // price would mislead.
                                if (available != null)
                                  Text(
                                    s.available(
                                      formatQty(available[p.id] ?? 0),
                                    ),
                                    style: TextStyle(color: muted),
                                  ),
                              ],
                            ),
                          ),
                          if (p.codeBarre?.isNotEmpty ?? false)
                            Icon(
                              Icons.qr_code_2_outlined,
                              size: 18,
                              color: muted,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, _) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: s.searchProduct,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: scannerSupported
                ? IconButton(
                    tooltip: s.scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner_outlined),
                    onPressed: _scan,
                  )
                : null,
          ),
          onTap: controller.clear,
        );
      },
    );
  }
}
