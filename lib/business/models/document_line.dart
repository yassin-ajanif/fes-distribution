/// Editable product line shared by bon de charge / décharge, BL and facture.
/// [bonLivraisonId] is set on facture lines copied from a BL.
class DocumentLine {
  DocumentLine({
    this.produitId = 0,
    this.reference = '',
    this.designation = '',
    this.quantite = 0,
    this.prixUnitaireHt = 0,
    this.remise = 0,
    this.tauxTva = 0,
    this.bonLivraisonId,
  });

  int produitId;
  String reference;
  String designation;
  double quantite;
  double prixUnitaireHt;
  double remise;
  double tauxTva;
  int? bonLivraisonId;

  /// Stable identity for widgets: the same product may appear once per BL.
  String get key => '${bonLivraisonId ?? 0}-$produitId';

  double get montantHt {
    final brut = quantite * prixUnitaireHt;
    return brut * (1 - remise / 100);
  }

  double get montantTtc => montantHt * (1 + tauxTva / 100);

  DocumentLine copyWith({
    int? produitId,
    String? reference,
    String? designation,
    double? quantite,
    double? prixUnitaireHt,
    double? remise,
    double? tauxTva,
  }) {
    return DocumentLine(
      produitId: produitId ?? this.produitId,
      reference: reference ?? this.reference,
      designation: designation ?? this.designation,
      quantite: quantite ?? this.quantite,
      prixUnitaireHt: prixUnitaireHt ?? this.prixUnitaireHt,
      remise: remise ?? this.remise,
      tauxTva: tauxTva ?? this.tauxTva,
      bonLivraisonId: bonLivraisonId,
    );
  }
}
