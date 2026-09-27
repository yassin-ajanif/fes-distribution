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
  final bool actif;
}
