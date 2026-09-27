import 'package:fes_distribution/db/app_database.dart';

class BonLivraisonListItem {
  const BonLivraisonListItem({
    required this.bl,
    required this.clientNom,
    required this.vendeurNom,
    required this.montantPaye,
  });

  final BonsLivraisonData bl;
  final String clientNom;
  final String vendeurNom;
  final double montantPaye;

  double get resteAPayer {
    final reste = bl.totalTtc - montantPaye;
    return reste > 0 ? reste : 0;
  }
}
