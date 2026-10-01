import 'package:fes_distribution/db/app_database.dart';

class FactureFournisseurListItem {
  const FactureFournisseurListItem({
    required this.facture,
    required this.fournisseurNom,
    required this.brNumeros,
  });

  final FacturesFournisseur facture;
  final String fournisseurNom;
  final List<String> brNumeros;

  /// [estPayee] is a manual marker on the facture, not derived from payments:
  /// the money sits on the BRs.
  bool get isOverdue {
    if (facture.estPayee) return false;
    final today = DateTime.now();
    final echeance = facture.dateEcheance;
    return DateTime(echeance.year, echeance.month, echeance.day)
        .isBefore(DateTime(today.year, today.month, today.day));
  }
}
