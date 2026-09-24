class VendeurStockLine {
  const VendeurStockLine({
    required this.produitId,
    required this.reference,
    required this.designation,
    required this.quantite,
    required this.prixVenteHt,
    required this.tauxTva,
  });

  final int produitId;
  final String reference;
  final String designation;
  final double quantite;
  final double prixVenteHt;
  final double tauxTva;

  double get valVenteTtc =>
      quantite * prixVenteHt * (1 + tauxTva / 100);
}
