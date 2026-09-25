import 'package:intl/intl.dart';

String formatInr(int amount) {
  final formatted = NumberFormat.decimalPattern('en_IN').format(amount);
  return '₹$formatted';
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
