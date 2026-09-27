import 'package:fes_distribution/db/app_database.dart';

class BonReceptionListItem {
  const BonReceptionListItem({
    required this.br,
    required this.fournisseurNom,
    this.factureNumero,
  });

  final BonsReceptionData br;
  final String fournisseurNom;

  /// Numero of the facture fournisseur the BR is invoiced on, if any.
  final String? factureNumero;
}
