class StockShortage {
  const StockShortage({
    required this.produitId,
    required this.reference,
    required this.designation,
    required this.locationName,
    required this.requested,
    required this.available,
    required this.shortage,
  });

  final int produitId;
  final String reference;
  final String designation;
  final String locationName;
  final double requested;
  final double available;
  final double shortage;
}
