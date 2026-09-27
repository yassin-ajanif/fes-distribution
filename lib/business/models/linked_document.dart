/// A source document shown on an invoice (linked or available to link):
/// a BL on a facture client, a BR on a facture fournisseur.
class LinkedDocument {
  const LinkedDocument({
    required this.id,
    required this.numero,
    required this.date,
    required this.totalTtc,
  });

  final int id;
  final String numero;
  final DateTime date;
  final double totalTtc;
}
