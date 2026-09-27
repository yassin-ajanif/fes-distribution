/// Stored as INTEGER in `PaiementsBonLivraison.Mode` (Peinture `ModePaiement`).
enum ModePaiement {
  credit(0),
  cheque(1),
  especes(2),
  tpe(3),
  virement(4),
  effet(5);

  const ModePaiement(this.code);

  final int code;

  static ModePaiement fromCode(int code) =>
      values.firstWhere((m) => m.code == code, orElse: () => especes);
}
