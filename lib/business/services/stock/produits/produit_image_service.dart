import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Product photos are stored as BLOBs inside the `Produits` table, so the
/// bytes must be kept small. Full-resolution phone photos are 3-8 MB each,
/// which would bloat the SQLite file and slow every catalog query, since
/// every list read pulls the whole row back.
class ProduitImageService {
  const ProduitImageService();

  /// Longest edge of the stored thumbnail, in pixels.
  static const maxDimension = 800;

  /// JPEG quality used when re-encoding. 80 keeps product photos visually
  /// clean at thumbnail size while staying around 60-120 KB.
  static const jpegQuality = 80;

  /// Downscales [bytes] and re-encodes them as JPEG.
  ///
  /// Returns the original bytes untouched if they are already small enough,
  /// so re-saving a product without touching the photo does not degrade it.
  Future<Uint8List> prepare(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Image illisible.');
    }

    if (decoded.width <= maxDimension && decoded.height <= maxDimension) {
      return bytes;
    }

    final resized = decoded.width >= decoded.height
        ? img.copyResize(
            decoded,
            width: maxDimension,
            height: (decoded.height * maxDimension / decoded.width).round(),
          )
        : img.copyResize(
            decoded,
            height: maxDimension,
            width: (decoded.width * maxDimension / decoded.height).round(),
          );

    return Uint8List.fromList(img.encodeJpg(resized, quality: jpegQuality));
  }
}
