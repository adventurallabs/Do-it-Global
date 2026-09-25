import 'period.dart';

/// Pure timetable arithmetic shared by every screen that shows or edits a
/// schedule — so "what happens on Monday the 14th" has exactly one answer.
class Schedule {
  static const weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  static String dayName(DateTime date) => weekdays[date.weekday - 1];

  static int minutesOf(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  static String hhmm(int minutes) {
    final m = minutes % (24 * 60);
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  /// "08:05" -> "8:05 AM"
  static String format12(String value) {
    final total = minutesOf(value);
    final hour = total ~/ 60;
    final minute = (total % 60).toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:$minute $suffix';
  }

  /// The empty week an admin starts from: [count] equal slots laid end to
  /// end from [dayStart], so a brand-new timetable is a full grid of cells to
  /// tap rather than a blank page you have to insert rows into one at a time.
  ///
  /// Slot length is rounded *down* to five minutes, so the last slot never
  /// runs past the end of the school day — better to leave a few minutes
  /// spare than to schedule a class after everyone has gone home. The admin
  /// sets each period's real length when they fill the slot in.
  static List<ScheduleSlot> slotPlan({
    required String dayStart,
    required String dayEnd,
    required int count,
  }) {
    if (count <= 0) return const [];
    final start = minutesOf(dayStart);
    final span = minutesOf(dayEnd) - start;
    if (span <= 0) return const [];
    final slot = (span ~/ count ~/ 5) * 5;
    final length = slot < 5 ? 5 : slot;
    return [
      for (var i = 0; i < count; i++)
        ScheduleSlot(startTime: hhmm(start + i * length), durationMinutes: length),
    ];
  }

  static int endMinutes(Period p) => minutesOf(p.startTime) + p.durationMinutes;

  static String endTime(Period p) => hhmm(endMinutes(p));

  static bool isBreak(Period p) {
    final n = p.name.toLowerCase();
    return n.contains('break') || n.contains('lunch') || n.contains('interval') || p.staffId == 'N/A';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// The periods that actually run on [day]. When [date] is given, one-day
  /// cover periods for that date replace the regular period in their slot;
  /// cover periods for any other date are ignored (they used to leak into
  /// every week).
  static List<Period> periodsOn(List<Period> all, String day, {DateTime? date}) {
    final regular = all.where((p) => p.dayOfWeek == day && !p.isTemporary).toList();
    if (date != null) {
      final covers = all.where((p) =>
          p.isTemporary && p.dayOfWeek == day && p.date != null && _sameDay(p.date!, date));
      for (final c in covers) {
        regular.removeWhere((p) => p.startTime == c.startTime);
        regular.add(c);
      }
    }
    regular.sort((a, b) {
      final t = minutesOf(a.startTime).compareTo(minutesOf(b.startTime));
      return t != 0 ? t : a.durationMinutes.compareTo(b.durationMinutes);
    });
    return regular;
  }

  /// Days that have at least one regular period, Monday first.
  static List<String> activeDays(List<Period> all) {
    final used = {for (final p in all) if (!p.isTemporary) p.dayOfWeek};
    return weekdays.where(used.contains).toList();
  }

  /// Regular periods on [day] that overlap in time, as pairs.
  static List<(Period, Period)> overlapsOn(List<Period> all, String day) {
    final list = periodsOn(all, day);
    final out = <(Period, Period)>[];
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        if (minutesOf(list[j].startTime) < endMinutes(list[i])) out.add((list[i], list[j]));
      }
    }
    return out;
  }

  /// Regular periods on [day] bundled into groups whose times chain-overlap
  /// (A overlaps B, B overlaps C → one group). Only groups with 2+ periods
  /// are returned, earliest first — each one is a single thing to fix.
  static List<List<Period>> clashGroupsOn(List<Period> all, String day) {
    final list = periodsOn(all, day);
    final groups = <List<Period>>[];
    List<Period>? current;
    var currentEnd = -1;
    for (final p in list) {
      final start = minutesOf(p.startTime);
      if (current != null && start < currentEnd) {
        current.add(p);
        if (endMinutes(p) > currentEnd) currentEnd = endMinutes(p);
      } else {
        if (current != null && current.length > 1) groups.add(current);
        current = [p];
        currentEnd = endMinutes(p);
      }
    }
    if (current != null && current.length > 1) groups.add(current);
    return groups;
  }

  /// Regular periods on [day] (other than [period] itself) that overlap it.
  static List<Period> clashesWith(List<Period> all, Period period) {
    final start = minutesOf(period.startTime);
    final end = endMinutes(period);
    return [
      for (final p in periodsOn(all, period.dayOfWeek))
        if (p.id != period.id && minutesOf(p.startTime) < end && start < endMinutes(p)) p,
    ];
  }

  /// "8:00 – 8:45 AM"-style range for a period.
  static String range(Period p) => '${format12(p.startTime)} – ${format12(endTime(p))}';

  /// The first regular period on [day] (other than [ignoreId]) that
  /// [candidate]'s time range would collide with, if any.
  static Period? clashFor(List<Period> all, Period candidate, String day, {String? ignoreId}) {
    final start = minutesOf(candidate.startTime);
    final end = start + candidate.durationMinutes;
    for (final p in periodsOn(all, day)) {
      if (p.id == ignoreId) continue;
      final ps = minutesOf(p.startTime);
      if (start < endMinutes(p) && ps < end) return p;
    }
    return null;
  }
}

/// One row of the blank weekly grid: when a period would start, and how long
/// it would run. It is a proposal, not a period — nothing exists on the
/// timetable until the admin fills the slot in.
class ScheduleSlot {
  final String startTime;
  final int durationMinutes;

  const ScheduleSlot({required this.startTime, required this.durationMinutes});

  String get endTime => Schedule.hhmm(Schedule.minutesOf(startTime) + durationMinutes);

  String get label => '${Schedule.format12(startTime)} – ${Schedule.format12(endTime)}';
}
