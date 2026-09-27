import 'package:fes_distribution/db/app_database.dart';

class FactureListItem {
  const FactureListItem({
    required this.facture,
    required this.clientNom,
    required this.blNumeros,
  });

  final Facture facture;
  final String clientNom;
  final List<String> blNumeros;

  bool get isOverdue {
    if (facture.estPayee) return false;
    final today = DateTime.now();
    final echeance = facture.dateEcheance;
    return DateTime(echeance.year, echeance.month, echeance.day)
        .isBefore(DateTime(today.year, today.month, today.day));
  }
}
