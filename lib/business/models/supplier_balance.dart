import 'package:fes_distribution/business/helpers/document_totals.dart';

/// Aggregated debt of a single supplier: what we still owe them.
///
/// Unlike clients — whose payments sit on the BL — supplier payments are
/// recorded on the facture fournisseur, and a facture's total already includes
/// the BRs it groups. So the balance is:
/// factures + BRs not yet invoiced − payments − credit notes.
class SupplierBalance {
  const SupplierBalance({
    required this.fournisseurId,
    required this.fournisseurNom,
    required this.totalFacture,
    required this.totalBrNonFacture,
    required this.totalPaye,
    required this.totalAvoir,
    required this.nbFacture,
    required this.nbBrNonFacture,
  });

  final int fournisseurId;
  final String fournisseurNom;

  /// Sum of the TTC totals of their factures.
  final double totalFacture;

  /// Sum of the TTC totals of their BRs that no facture covers yet.
  final double totalBrNonFacture;

  /// Sum of the payments recorded on those factures.
  final double totalPaye;

  /// Sum of the TTC totals of their avoirs.
  final double totalAvoir;

  final int nbFacture;
  final int nbBrNonFacture;

  /// Goods received but not yet paid for, invoiced or not.
  double get totalRecu => totalFacture + totalBrNonFacture;

  /// What we still owe the supplier. Negative when we overpaid.
  double get solde => totalRecu - totalPaye - totalAvoir;

  bool get doit => solde > DocumentTotals.zeroTotalTolerance;
}

/// Which kind of document a [SupplierBalanceLine] row stands for.
enum SupplierDocumentKind { facture, bonReception }

/// One document behind a supplier balance, with what has been paid on it.
/// Only factures carry payments; a bare BR is always fully outstanding.
class SupplierBalanceLine {
  const SupplierBalanceLine({
    required this.documentId,
    required this.kind,
    required this.numero,
    required this.date,
    required this.totalTtc,
    required this.totalPaye,
  });

  final int documentId;
  final SupplierDocumentKind kind;
  final String numero;
  final DateTime date;
  final double totalTtc;
  final double totalPaye;

  double get reste => totalTtc - totalPaye;
}