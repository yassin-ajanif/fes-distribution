class PersonnelDocumentLine {
  PersonnelDocumentLine({
    this.produitId = 0,
    this.reference = '',
    this.designation = '',
    this.quantite = 0,
    this.prixUnitaireHt = 0,
    this.remise = 0,
    this.tauxTva = 0,
  });

  int produitId;
  String reference;
  String designation;
  double quantite;
  double prixUnitaireHt;
  double remise;
  double tauxTva;

  double get montantHt {
    final brut = quantite * prixUnitaireHt;
    return brut * (1 - remise / 100);
  }

  double get montantTtc => montantHt * (1 + tauxTva / 100);

  PersonnelDocumentLine copyWith({
    int? produitId,
    String? reference,
    String? designation,
    double? quantite,
    double? prixUnitaireHt,
    double? remise,
    double? tauxTva,
  }) {
    return PersonnelDocumentLine(
      produitId: produitId ?? this.produitId,
      reference: reference ?? this.reference,
      designation: designation ?? this.designation,
      quantite: quantite ?? this.quantite,
      prixUnitaireHt: prixUnitaireHt ?? this.prixUnitaireHt,
      remise: remise ?? this.remise,
      tauxTva: tauxTva ?? this.tauxTva,
    );
  }
}
