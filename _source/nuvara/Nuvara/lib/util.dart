import 'package:intl/intl.dart';

// Dates travel as 'yyyy-MM-dd' and times as 'HH:mm' strings: they sort and compare correctly as text.

// These run thousands of times per screen (every session, bill and message), so they avoid building
// formatters: dates are assembled by hand and every DateFormat / NumberFormat is created once and reused.

String _two(int n) => n < 10 ? '0$n' : '$n';
String iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';
String todayISO() => iso(DateTime.now());
DateTime parseD(String d) => DateTime.parse(d);

final _dateFormats = <String, DateFormat>{};
DateFormat _df(String pattern) => _dateFormats[pattern] ??= DateFormat(pattern);
final _inr = NumberFormat.decimalPattern('en_IN');
final _inrPaise = NumberFormat('#,##,##0.00', 'en_IN');
String addDays(String d, int n) {
  final x = parseD(d);
  return iso(DateTime(x.year, x.month, x.day + n));
}

/// 0 = Sunday, matching Postgres `extract(dow)`.
int weekdayOf(String d) => parseD(d).weekday % 7;
String weekStart(String d) {
  final x = parseD(d);
  return iso(DateTime(x.year, x.month, x.day - (x.weekday - 1)));
}

String nowHM() {
  final n = DateTime.now();
  return '${_two(n.hour)}:${_two(n.minute)}';
}
String hm(dynamic t) => (t as String).substring(0, 5);

int toMin(String t) {
  final p = t.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String fromMin(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
String endTime(String start, int duration) => fromMin(toMin(start) + duration);

String fmtTime(String t) {
  final m = toMin(t);
  final h = m ~/ 60;
  return '${(h + 11) % 12 + 1}:${(m % 60).toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

String fmtTimeShort(String t) => fmtTime(t).replaceAll(RegExp(r' (AM|PM)'), '');
String fmtRange(String start, int duration) => '${fmtTime(start)} – ${fmtTime(endTime(start, duration))}';
String fmtDate(String d, [String pattern = 'd MMM yyyy']) => _df(pattern).format(parseD(d));
String fmtDateTime(DateTime d) => _df('d MMM, h:mm a').format(d.toLocal());

String relDay(String d) {
  final t = todayISO();
  if (d == t) return 'Today';
  if (d == addDays(t, 1)) return 'Tomorrow';
  if (d == addDays(t, -1)) return 'Yesterday';
  return fmtDate(d, 'EEE, d MMM');
}

const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const dayLong = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

String inr(num n) => '₹${_inr.format(n.round())}';

String ageOf(String dob) {
  final b = parseD(dob);
  final n = DateTime.now();
  var months = (n.year - b.year) * 12 + n.month - b.month;
  if (n.day < b.day) months--;
  return months >= 12 ? '${months ~/ 12} yrs' : '$months mo';
}

String initials(String name) =>
    name.trim().split(RegExp(r'\s+')).take(2).map((p) => p.isEmpty ? '' : p[0]).join().toUpperCase();
String firstWord(String name) => name.split(' ').first;

String greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
}

String timeAgo(DateTime at) {
  final d = DateTime.now().difference(at.toLocal());
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return DateFormat('d MMM').format(at.toLocal());
}

String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// "4 years, 3 months old" — exact, for profiles and forms.
String ageLong(String dob) {
  final b = parseD(dob);
  final n = DateTime.now();
  var months = (n.year - b.year) * 12 + n.month - b.month;
  if (n.day < b.day) months--;
  if (months < 0) return 'Not born yet';
  final y = months ~/ 12, m = months % 12;
  final parts = [if (y > 0) plural(y, 'year'), if (m > 0 || y == 0) plural(m, 'month')];
  return '${parts.join(', ')} old';
}

/// Billing month key, 'yyyy-MM'.
String periodOf(String date) => date.substring(0, 7);
String currentPeriod() => periodOf(todayISO());
String periodLabel(String period, [String pattern = 'MMMM yyyy']) => _df(pattern).format(DateTime.parse('$period-01'));
String addMonths(String period, int n) {
  final d = DateTime.parse('$period-01');
  return iso(DateTime(d.year, d.month + n)).substring(0, 7);
}

bool overlaps(String aStart, String aEnd, String bStart, String bEnd) => aStart.compareTo(bEnd) < 0 && bStart.compareTo(aEnd) < 0;

String minutesLabel(int m) {
  if (m < 60) return '$m min';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '$h hr' : '$h hr $r min';
}

String fmtSpan(String start, String end) => '${fmtTimeShort(start)} – ${fmtTime(end)}';

/// Monday-first list of the 7 dates of the week containing [d].
List<String> weekDates(String d) {
  final m = weekStart(d);
  return [for (var i = 0; i < 7; i++) addDays(m, i)];
}

String weekLabel(String monday) {
  final sun = addDays(monday, 6);
  final sameMonth = monday.substring(0, 7) == sun.substring(0, 7);
  return '${fmtDate(monday, sameMonth ? 'd' : 'd MMM')} – ${fmtDate(sun, 'd MMM yyyy')}';
}

String money(num n) {
  final v = (n * 100).round() / 100;
  return v == v.roundToDouble() ? inr(v) : '₹${_inrPaise.format(v)}';
}

/// Last 10 digits, so '+91 98765 43210' and '9876543210' compare equal.
String digits10(String p) {
  final d = p.replaceAll(RegExp(r'\D'), '');
  return d.length <= 10 ? d : d.substring(d.length - 10);
}

/// Formats [d] with a cached [DateFormat] for [pattern] (creating formatters is slow).
String fmtAt(DateTime d, String pattern) => _df(pattern).format(d);
