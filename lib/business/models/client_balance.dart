import 'package:fes_distribution/business/helpers/document_totals.dart';

/// Aggregated debt of a single client.
///
/// All sales go through BLs and client payments are recorded on those BLs, so
/// what is owed is the delivered amount, less what was paid, less any credit
/// note (avoir) issued to the client.
class ClientBalance {
  const ClientBalance({
    required this.clientId,
    required this.clientNom,
    required this.totalLivraison,
    required this.totalPaye,
    required this.totalAvoir,
    required this.nbBl,
  });

  final int clientId;
  final String clientNom;

  /// Sum of the TTC totals of the client's BLs.
  final double totalLivraison;

  /// Sum of the payments recorded on those BLs.
  final double totalPaye;

  /// Sum of the TTC totals of the client's avoirs.
  final double totalAvoir;

  /// How many BLs back this figure.
  final int nbBl;

  /// What the client still owes. Negative when the client overpaid or was
  /// credited more than they were billed.
  double get solde => totalLivraison - totalPaye - totalAvoir;

  /// True when there is a real amount left to collect (tolerance-protected so
  /// rounding dust does not show up as a debt).
  bool get doit => solde > DocumentTotals.zeroTotalTolerance;
}

/// One BL behind a client balance, with what has already been paid on it.
class ClientBlLine {
  const ClientBlLine({
    required this.blId,
    required this.numero,
    required this.date,
    required this.totalTtc,
    required this.totalPaye,
  });

  final int blId;
  final String numero;
  final DateTime date;
  final double totalTtc;
  final double totalPaye;

  double get reste => totalTtc - totalPaye;
}