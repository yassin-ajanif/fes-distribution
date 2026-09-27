import 'package:fes_distribution/db/app_database.dart';

class AvoirListItem {
  const AvoirListItem({
    required this.avoir,
    required this.clientNom,
    required this.totalTtc,
    this.factureNumero,
  });

  final Avoir avoir;
  final String clientNom;

  /// Computed from the lines (`Avoirs` has no total column).
  final double totalTtc;

  /// Numero of the facture the avoir credits, if any.
  final String? factureNumero;
}
