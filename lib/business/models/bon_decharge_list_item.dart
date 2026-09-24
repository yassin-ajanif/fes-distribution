import 'package:fes_distribution/db/app_database.dart';

class BonDechargeListItem {
  const BonDechargeListItem({
    required this.bon,
    required this.assignedToNom,
    required this.depotNom,
  });

  final BonsDechargeData bon;
  final String assignedToNom;
  final String depotNom;
}
