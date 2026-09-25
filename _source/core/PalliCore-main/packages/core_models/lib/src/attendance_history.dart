import 'attendance.dart';

/// One person's attendance across a stretch of the year.
///
/// Built for a child or a teacher alike: both are "a run of days, each either
/// present, absent, or never marked". Keeping unmarked days separate matters
/// as much here as it does on the dashboard — a term where nobody called the
/// roll for three weeks is not a term of perfect attendance, and a rate that
/// quietly treats those days as present would say it was.
class AttendanceHistory {
  /// Every day that has a record, oldest first.
  final List<AttendanceDay> days;

  /// The window asked for, so a screen can name it.
  final DateTime from;
  final DateTime to;

  const AttendanceHistory({
    required this.days,
    required this.from,
    required this.to,
  });

  int get present => days.where((d) => d.inSchool).length;

  int get absent => days.where((d) => !d.inSchool).length;

  /// Days with a record at all. There is no "unmarked" count here because a
  /// day nobody marked simply has no row — the school does not record
  /// non-attendance, and inventing a denominator of calendar days would count
  /// holidays as absences.
  int get recorded => days.length;

  /// Null until there is something to average.
  double? get ratePercent => recorded == 0 ? null : present / recorded * 100;

  String get rateLabel {
    final rate = ratePercent;
    return rate == null ? '—' : '${rate.toStringAsFixed(0)}%';
  }

  /// The dates they were away, newest first — what an admin scans for.
  List<DateTime> get absentDates =>
      [for (final d in days.where((d) => !d.inSchool)) d.date].reversed.toList();

  /// The longest run of consecutive *recorded* absences. A child away for
  /// eight straight days is a different conversation from one who misses
  /// eight scattered Mondays, and the single rate cannot tell them apart.
  int get longestAbsenceRun {
    var best = 0;
    var run = 0;
    for (final day in days) {
      if (day.inSchool) {
        run = 0;
      } else {
        run++;
        if (run > best) best = run;
      }
    }
    return best;
  }

  /// Consecutive absences ending on the most recent recorded day — an ongoing
  /// absence, which is the one worth acting on today.
  int get currentAbsenceRun {
    var run = 0;
    for (final day in days.reversed) {
      if (day.inSchool) break;
      run++;
    }
    return run;
  }

  /// Month by month, oldest first, for the year view.
  List<AttendanceMonth> get months {
    final buckets = <String, List<AttendanceDay>>{};
    for (final day in days) {
      final key = '${day.date.year}-${day.date.month.toString().padLeft(2, '0')}';
      buckets.putIfAbsent(key, () => []).add(day);
    }
    final keys = buckets.keys.toList()..sort();
    return [
      for (final key in keys)
        AttendanceMonth(
          year: int.parse(key.split('-').first),
          month: int.parse(key.split('-').last),
          days: buckets[key]!,
        ),
    ];
  }

  /// True when they have missed enough to be worth a word. The school's own
  /// threshold lives in `school_settings.attendance_warning_threshold`; this
  /// takes it as an argument rather than guessing.
  bool isBelow(int thresholdPercent) {
    final rate = ratePercent;
    return rate != null && rate < thresholdPercent;
  }

  static AttendanceHistory fromRows({
    required Iterable<Attendance> rows,
    required DateTime from,
    required DateTime to,
  }) {
    // One row per day. A day marked twice keeps the later record, which is
    // the correction a teacher made.
    final byDay = <String, AttendanceDay>{};
    for (final row in rows) {
      if (row.periodId != 'homeroom') continue;
      final date = DateTime(row.date.year, row.date.month, row.date.day);
      final key = date.toIso8601String();
      final existing = byDay[key];
      if (existing == null || !row.date.isBefore(existing.markedAt)) {
        byDay[key] = AttendanceDay(
          date: date,
          status: row.status,
          markedAt: row.date,
        );
      }
    }
    final days = byDay.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return AttendanceHistory(days: days, from: from, to: to);
  }

  /// The staff table has no period column — every row is the whole day.
  static AttendanceHistory fromStaffRows({
    required Iterable<({DateTime date, AttendanceStatus status})> rows,
    required DateTime from,
    required DateTime to,
  }) {
    final byDay = <String, AttendanceDay>{};
    for (final row in rows) {
      final date = DateTime(row.date.year, row.date.month, row.date.day);
      final key = date.toIso8601String();
      final existing = byDay[key];
      if (existing == null || !row.date.isBefore(existing.markedAt)) {
        byDay[key] = AttendanceDay(date: date, status: row.status, markedAt: row.date);
      }
    }
    final days = byDay.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return AttendanceHistory(days: days, from: from, to: to);
  }
}

/// One recorded day.
class AttendanceDay {
  final DateTime date;
  final AttendanceStatus status;

  /// When the row was written — used only to settle a day marked twice.
  final DateTime markedAt;

  const AttendanceDay({
    required this.date,
    required this.status,
    required this.markedAt,
  });

  /// Present, on duty and arriving late all mean the person was in school.
  bool get inSchool => status != AttendanceStatus.absent;

  String get statusLabel => switch (status) {
        AttendanceStatus.present => 'Present',
        AttendanceStatus.absent => 'Absent',
        AttendanceStatus.od => 'On duty',
        AttendanceStatus.delayed => 'Late',
      };
}

/// One month of a person's year.
class AttendanceMonth {
  final int year;
  final int month;
  final List<AttendanceDay> days;

  const AttendanceMonth({required this.year, required this.month, required this.days});

  int get present => days.where((d) => d.inSchool).length;
  int get absent => days.where((d) => !d.inSchool).length;
  int get recorded => days.length;

  double? get ratePercent => recorded == 0 ? null : present / recorded * 100;

  /// The day-of-month numbers they were away — what the calendar strip draws.
  Set<int> get absentDayNumbers =>
      {for (final d in days.where((d) => !d.inSchool)) d.date.day};

  Set<int> get presentDayNumbers =>
      {for (final d in days.where((d) => d.inSchool)) d.date.day};

  static const _names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String get label => '${_names[month - 1]} $year';
  String get shortLabel => _names[month - 1].substring(0, 3);
}
