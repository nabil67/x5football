import 'package:intl/intl.dart';

/// « samedi 1 novembre · 14:00 »
String formatMatchDate(DateTime date) =>
    '${DateFormat('EEEE d MMMM', 'fr_FR').format(date)} · ${DateFormat.Hm('fr_FR').format(date)}';

/// « 1 h 30 », « 45 min »
String formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest min';
  if (rest == 0) return '$hours h';
  return '$hours h ${rest.toString().padLeft(2, '0')}';
}

/// « 5,50 € »
String formatCost(double amount, String currency) =>
    NumberFormat.simpleCurrency(locale: 'fr_FR', name: currency).format(amount);
