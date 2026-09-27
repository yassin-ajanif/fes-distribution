import 'package:fes_distribution/business/enums/mode_paiement.dart';

/// Client payment recorded on a BL (`PaiementsBonLivraison`).
class BonLivraisonPaiement {
  BonLivraisonPaiement({
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
