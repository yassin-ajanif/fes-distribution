import 'package:fes_distribution/db/app_database.dart';

class ChargeListItem {
  const ChargeListItem({required this.charge, required this.typeNom});

  final Charge charge;

  /// Resolved from `TypesCharges`, for display in the list.
  final String typeNom;
}
