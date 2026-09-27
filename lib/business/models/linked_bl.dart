/// A bon de livraison shown on a facture (linked or available to link).
class LinkedBl {
  const LinkedBl({
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
