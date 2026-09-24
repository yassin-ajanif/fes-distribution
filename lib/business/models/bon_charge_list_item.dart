import 'package:fes_distribution/db/app_database.dart';

class BonChargeListItem {
  const BonChargeListItem({
    required this.bon,
    required this.assignedToNom,
    required this.depotNom,
  });

  final BonsChargeData bon;
  final String assignedToNom;
  final String depotNom;
}
