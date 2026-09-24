/// Document numbering aligned with Peinture [NumberingHelper] / [DocumentNumberingHelper].
class DocumentNumbering {
  DocumentNumbering._();

  static String generate(String prefix, int lastNumber, int year) =>
      '$prefix-$year-${(lastNumber + 1).toString().padLeft(4, '0')}';

  static int maxSequenceFromNumeros(
    Iterable<String> numeros,
    String prefix,
    int year,
  ) {
    var last = 0;
    final prefixYear = '$prefix-$year-';
    for (final n in numeros) {
      if (n.isEmpty || !n.startsWith(prefixYear)) continue;
      final tail = n.substring(prefixYear.length);
      final num = int.tryParse(tail);
      if (num != null && num > last) last = num;
    }
    return last;
  }

  static int resolveNextSequence(int maxInDatabase, int lastUsedOutside) =>
      [maxInDatabase, lastUsedOutside, 0].reduce((a, b) => a > b ? a : b) + 1;
}
