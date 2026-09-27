import '../models/document_line.dart';

class DocumentTotals {
  const DocumentTotals({
    required this.totalHt,
    required this.totalTva,
    required this.totalTtc,
  });

  final double totalHt;
  final double totalTva;
  final double totalTtc;

  static const zeroTotalTolerance = 0.005;
  static const paiementTtcTolerance = 0.02;

  /// [remiseGlobale] is a percentage applied to both HT and TVA.
  static DocumentTotals fromLines(
    List<DocumentLine> lines, {
    double remiseGlobale = 0,
  }) {
    var ht = 0.0;
    var tva = 0.0;
    for (final line in lines) {
      if (line.produitId <= 0 || line.quantite <= 0) continue;
      final lineHt = line.montantHt;
      ht += lineHt;
      tva += lineHt * (line.tauxTva / 100);
    }
    if (remiseGlobale > 0) {
      final factor = 1 - remiseGlobale / 100;
      ht *= factor;
      tva *= factor;
    }
    return DocumentTotals(totalHt: ht, totalTva: tva, totalTtc: ht + tva);
  }

  static bool isEffectivelyZero(double totalTtc) =>
      totalTtc.abs() <= zeroTotalTolerance;

  static bool paymentsExceedTtc(double ttc, double totalPayments) =>
      totalPayments > ttc + paiementTtcTolerance;
}
