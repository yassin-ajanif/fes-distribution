/// Editable product line shared by bon de charge / décharge, BL, facture and
/// the achats documents. [bonLivraisonId] is set on facture lines copied from
/// a BL, [bonReceptionId] on facture fournisseur lines copied from a BR.
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
    this.bonReceptionId,
  });

  int produitId;
  String reference;
  String designation;
  double quantite;
  double prixUnitaireHt;
  double remise;
  double tauxTva;
  int? bonLivraisonId;
  int? bonReceptionId;

  /// Stable identity for widgets: the same product may appear once per
  /// source BL / BR.
  String get key =>
      '${bonLivraisonId ?? 0}-${bonReceptionId ?? 0}-$produitId';

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
      bonReceptionId: bonReceptionId,
    );
  }
}
