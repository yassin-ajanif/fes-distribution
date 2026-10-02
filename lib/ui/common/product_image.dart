import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

/// Indexes the catalog photos by product id so document line widgets can show
/// them without holding the whole `Produit` row.
Map<int, Uint8List> productImagesById(Iterable<Produit> produits) => {
  for (final p in produits)
    if (p.imageData != null && p.imageData!.isNotEmpty) p.id: p.imageData!,
};

/// Small product photo with a neutral fallback when the product has none.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({super.key, required this.bytes, this.size = 40});

  final Uint8List? bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = bytes;
    if (image == null) {
      return _box(
        context,
        const Icon(
          Icons.inventory_2_outlined,
          size: 20,
          color: AppColors.muted,
        ),
      );
    }
    return _box(
      context,
      Image.memory(
        image,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const Icon(
          Icons.broken_image_outlined,
          size: 20,
          color: AppColors.muted,
        ),
      ),
    );
  }

  Widget _box(BuildContext context, Widget child) => Container(
    width: size,
    height: size,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.brandSoft,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: child,
  );
}

/// Tappable icon that opens [showProductImageDialog]. Renders nothing when the
/// product has no stored photo, so a line never shows a dead button.
class ProductImageButton extends StatelessWidget {
  const ProductImageButton({
    super.key,
    required this.reference,
    required this.designation,
    required this.bytes,
  });

  final String reference;
  final String designation;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final image = bytes;
    if (image == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: context.s.viewPhoto,
      icon: const Icon(Icons.image_outlined, size: 20),
      onPressed: () => showProductImageDialog(
        context,
        reference: reference,
        designation: designation,
        bytes: image,
      ),
    );
  }
}

/// Full-size viewer for a product photo.
Future<void> showProductImageDialog(
  BuildContext context, {
  required String reference,
  required String designation,
  required Uint8List bytes,
}) {
  // Read the strings from the caller's context: a dialog route sits above the
  // StringsScope, so looking them up inside the builder would throw.
  final s = context.s;
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          reference,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          designation,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: Theme.of(ctx).textTheme.bodySmall
                                ?.fontSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: s.close,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                maxScale: 6,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
