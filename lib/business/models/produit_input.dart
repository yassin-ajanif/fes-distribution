import 'dart:typed_data';

class ProduitInput {
  const ProduitInput({
    required this.reference,
    required this.designation,
    this.codeBarre,
    this.unite = 'U',
    this.prixAchatHT = 0,
    this.prixVenteHT = 0,
    this.tauxTVA = 20,
    this.stockMinimum = 0,
    this.categorieId,
    this.imageData,
    this.clearImage = false,
    this.actif = true,
  });

  final String reference;
  final String designation;
  final String? codeBarre;
  final String unite;
  final double prixAchatHT;
  final double prixVenteHT;
  final double tauxTVA;
  final double stockMinimum;
  final int? categorieId;

  /// New photo bytes to store. When null on an update, the existing photo is
  /// left untouched.
  final Uint8List? imageData;

  /// Set to drop the stored photo. Takes precedence over [imageData].
  final bool clearImage;

  final bool actif;
}
