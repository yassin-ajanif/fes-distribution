import 'package:fes_distribution/db/app_database.dart';

class BonReceptionListItem {
  const BonReceptionListItem({
    required this.br,
    required this.fournisseurNom,
    required this.montantPaye,
    this.factureNumero,
  });

  final BonsReceptionData br;
  final String fournisseurNom;

  /// Sum of the payments recorded on the BR.
  final double montantPaye;

  /// Numero of the facture fournisseur the BR is invoiced on, if any.
  final String? factureNumero;

  double get resteAPayer {
    final reste = br.totalTtc - montantPaye;
    return reste > 0 ? reste : 0;
  }
}
