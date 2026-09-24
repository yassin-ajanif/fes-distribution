import 'package:intl/intl.dart';

final dateFormat = DateFormat('dd/MM/yyyy');
final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
final numberFormat = NumberFormat('#,##0.00', 'fr_FR');
final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'DH');

String formatQty(double value) => numberFormat.format(value);
String formatMoney(double value) => currencyFormat.format(value);
