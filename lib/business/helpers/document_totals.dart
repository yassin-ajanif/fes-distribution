import '../models/personnel_document_line.dart';

class DocumentTotals {
  const DocumentTotals({
    required this.totalHt,
    required this.totalTva,
    required this.totalTtc,
  });

  final double totalHt;
  final double totalTva;
  final double totalTtc;

  static DocumentTotals fromLines(List<PersonnelDocumentLine> lines) {
    var ht = 0.0;
    var tva = 0.0;
    for (final line in lines) {
      if (line.produitId <= 0 || line.quantite <= 0) continue;
      final lineHt = line.montantHt;
      ht += lineHt;
      tva += lineHt * (line.tauxTva / 100);
    }
    return DocumentTotals(totalHt: ht, totalTva: tva, totalTtc: ht + tva);
  }

  static bool isEffectivelyZero(double totalTtc) => totalTtc.abs() < 0.0001;
}
