import 'package:fes_distribution/business/helpers/document_totals.dart';

/// Aggregated debt of a single supplier: what we still owe them.
///
/// This is now the exact mirror of `ClientBalance` — BR totals − payments −
/// credit notes — because supplier payments moved onto the BR, like BL payments
/// on the ventes side. A BR is a debt whether or not it has been invoiced yet.
class SupplierBalance {
  const SupplierBalance({
    required this.fournisseurId,
    required this.fournisseurNom,
    required this.totalLivraison,
    required this.totalPaye,
    required this.totalAvoir,
    required this.nbBr,
  });

  final int fournisseurId;
  final String fournisseurNom;

  /// Sum of the TTC totals of their BRs.
  final double totalLivraison;

  /// Sum of the payments recorded on those BRs.
  final double totalPaye;

  /// Sum of the TTC totals of their avoirs.
  final double totalAvoir;

  final int nbBr;

  /// What we still owe the supplier. Negative when we overpaid.
  double get solde => totalLivraison - totalPaye - totalAvoir;

  bool get doit => solde > DocumentTotals.zeroTotalTolerance;
}

/// One BR behind a supplier balance, with what has been paid on it.
class SupplierBalanceLine {
  const SupplierBalanceLine({
    required this.brId,
    required this.numero,
    required this.date,
    required this.totalTtc,
    required this.totalPaye,
    this.factureNumero,
  });

  final int brId;
  final String numero;
  final DateTime date;
  final double totalTtc;
  final double totalPaye;

  /// Invoice the BR was grouped on, for context.
  final String? factureNumero;

  double get reste => totalTtc - totalPaye;
}
