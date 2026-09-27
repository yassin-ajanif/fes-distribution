import 'package:fes_distribution/db/app_database.dart';

class FactureFournisseurListItem {
  const FactureFournisseurListItem({
    required this.facture,
    required this.fournisseurNom,
    required this.brNumeros,
    required this.montantPaye,
  });

  final FacturesFournisseur facture;
  final String fournisseurNom;
  final List<String> brNumeros;
  final double montantPaye;

  double get resteAPayer {
    final reste = facture.totalTtc - montantPaye;
    return reste > 0 ? reste : 0;
  }

  bool get isOverdue {
    if (facture.estPayee) return false;
    final today = DateTime.now();
    final echeance = facture.dateEcheance;
    return DateTime(echeance.year, echeance.month, echeance.day)
        .isBefore(DateTime(today.year, today.month, today.day));
  }
}
