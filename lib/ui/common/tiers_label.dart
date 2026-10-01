import 'package:fes_distribution/db/app_database.dart';

/// Label for a client or supplier in a picker.
///
/// The phone is the point: it is required and unique, so it is what tells two
/// tiers sharing a name apart. The city is only a fallback for tiers entered
/// before the phone became mandatory, which may still have an empty one.
String tiersLabel(Tier t) {
  final phone = t.telephone.trim();
  if (phone.isNotEmpty) return '${t.nom} — $phone';
  return t.ville.trim().isEmpty ? t.nom : '${t.nom} — ${t.ville.trim()}';
}

/// Same idea for a vendeur, whose phone was already mandatory and unique.
String vendeurLabel(User u) => '${u.fullName} — ${u.phone}';
