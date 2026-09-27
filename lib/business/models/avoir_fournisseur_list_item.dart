import 'package:fes_distribution/db/app_database.dart';

class AvoirFournisseurListItem {
  const AvoirFournisseurListItem({
    required this.avoir,
    required this.fournisseurNom,
    required this.totalTtc,
  });

  final AvoirsFournisseur avoir;
  final String fournisseurNom;

  /// Computed from the lines (`AvoirsFournisseurs` has no total column).
  final double totalTtc;
}
