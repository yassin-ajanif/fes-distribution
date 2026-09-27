import 'package:fes_distribution/business/enums/mode_paiement.dart';

/// A payment line: client payment on a BL (`PaiementsBonLivraison`) or
/// supplier payment on a facture fournisseur (`PaiementsFournisseurs`).
class DocumentPaiement {
  DocumentPaiement({
    required this.date,
    required this.montant,
    this.mode = ModePaiement.especes,
    this.reference = '',
  });

  DateTime date;
  double montant;
  ModePaiement mode;
  String reference;
}
