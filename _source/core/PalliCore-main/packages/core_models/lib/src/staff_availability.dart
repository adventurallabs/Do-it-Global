import 'period.dart';
import 'schedule.dart';
import 'timetable.dart';

/// One slot a staff member is already committed to, anywhere in the school.
///
/// Bookings are the single source of truth behind "can this teacher take this
/// period?" — every screen that assigns staff to a time (timetable editor,
/// leave cover, same-day reassignment) asks the same question of the same
/// data, so the answer can't differ between them.
class StaffBooking {
  final String staffId;
  final String timetableId;
  final String timetableName;
  final String classroomId;

  /// Human label for the class — falls back to [classroomId] when the
  /// classroom list isn't loaded.
  final String classroomName;
  final String dayOfWeek;
  final String periodId;
  final String periodName;
  final String startTime;
  final int durationMinutes;

  /// Set only for one-day cover periods.
  final DateTime? date;

  const StaffBooking({
    required this.staffId,
    required this.timetableId,
    required this.timetableName,
    required this.classroomId,
    required this.classroomName,
    required this.dayOfWeek,
    required this.periodId,
    required this.periodName,
    required this.startTime,
    required this.durationMinutes,
    this.date,
  });

  int get startMinutes => Schedule.minutesOf(startTime);

  int get endMinutes => startMinutes + durationMinutes;

  String get endTime => Schedule.hhmm(endMinutes);

  /// "9:30 – 10:15 AM"
  String get range => '${Schedule.format12(startTime)} – ${Schedule.format12(endTime)}';

  bool get isCover => date != null;

  /// One line an admin can act on: what the teacher is doing instead.
  String get label => '$periodName · $classroomName';

  /// The same, with the day and clock time spelled out.
  String get detail => '$dayOfWeek $range';
}

/// Two bookings that put one staff member in two places at the same time.
class StaffClash {
  final String staffId;
  final StaffBooking a;
  final StaffBooking b;

  const StaffClash({required this.staffId, required this.a, required this.b});

  String get dayOfWeek => a.dayOfWeek;
}

/// Pure staff-scheduling arithmetic: who is free, who is double-booked, and
/// exactly what they are doing instead. No teacher can stand in two
/// classrooms at once, and this is the one place that rule is enforced.
class StaffAvailability {
  /// The staff id the timetable uses for breaks, lunch and free periods —
  /// it is not a person, so it never clashes with anything.
  static const noStaffId = 'N/A';

  static bool isRealStaff(String? staffId) =>
      staffId != null && staffId.isNotEmpty && staffId != noStaffId;

  /// Every commitment held by real staff across [timetables].
  ///
  /// [activeOnly] keeps drafts out — a timetable nobody activated isn't
  /// running, so it can't book anyone. [on] resolves one-day cover for that
  /// date (and narrows the result to that weekday); without it, cover periods
  /// are ignored and the regular week is used. [excludeTimetableIds] and
  /// [excludeClassroomIds] drop the schedule being edited, so it never
  /// collides with itself.
  static List<StaffBooking> bookings(
    Iterable<Timetable> timetables, {
    bool activeOnly = true,
    DateTime? on,
    Iterable<String>? days,
    Set<String> excludeTimetableIds = const {},
    Set<String> excludeClassroomIds = const {},
    Map<String, String> classroomNames = const {},
  }) {
    final wanted = on != null
        ? [Schedule.dayName(on)]
        : (days?.toList() ?? Schedule.weekdays);
    final out = <StaffBooking>[];
    for (final timetable in timetables) {
      if (activeOnly && !timetable.isActive) continue;
      if (excludeTimetableIds.contains(timetable.id)) continue;
      if (excludeClassroomIds.contains(timetable.classroomId)) continue;
      final classroomName = classroomNames[timetable.classroomId] ?? timetable.classroomId;
      for (final day in wanted) {
        for (final period in Schedule.periodsOn(timetable.periods, day, date: on)) {
          if (!isRealStaff(period.staffId)) continue;
          out.add(StaffBooking(
            staffId: period.staffId,
            timetableId: timetable.id,
            timetableName: timetable.name,
            classroomId: timetable.classroomId,
            classroomName: classroomName,
            dayOfWeek: day,
            periodId: period.id,
            periodName: period.name,
            startTime: period.startTime,
            durationMinutes: period.durationMinutes,
            date: period.date,
          ));
        }
      }
    }
    return out;
  }

  static bool _overlaps(StaffBooking booking, int startMinutes, int endMinutes) =>
      booking.startMinutes < endMinutes && startMinutes < booking.endMinutes;

  /// The first commitment [staffId] holds that runs into the given slot, or
  /// null when they are free for it.
  static StaffBooking? conflictFor(
    Iterable<StaffBooking> bookings, {
    required String staffId,
    required String dayOfWeek,
    required String startTime,
    required int durationMinutes,
    Set<String> ignorePeriodIds = const {},
  }) {
    if (!isRealStaff(staffId)) return null;
    final start = Schedule.minutesOf(startTime);
    final end = start + durationMinutes;
    for (final booking in bookings) {
      if (booking.staffId != staffId) continue;
      if (booking.dayOfWeek != dayOfWeek) continue;
      if (ignorePeriodIds.contains(booking.periodId)) continue;
      if (_overlaps(booking, start, end)) return booking;
    }
    return null;
  }

  /// Every staff member who is *not* free for the given slot, mapped to the
  /// commitment that blocks them. Feed this straight into a staff picker to
  /// grey out the people who cannot take the period.
  static Map<String, StaffBooking> busyDuring(
    Iterable<StaffBooking> bookings, {
    required String dayOfWeek,
    required String startTime,
    required int durationMinutes,
    Set<String> ignorePeriodIds = const {},
  }) {
    final start = Schedule.minutesOf(startTime);
    final end = start + durationMinutes;
    final out = <String, StaffBooking>{};
    for (final booking in bookings) {
      if (booking.dayOfWeek != dayOfWeek) continue;
      if (ignorePeriodIds.contains(booking.periodId)) continue;
      if (!_overlaps(booking, start, end)) continue;
      final existing = out[booking.staffId];
      if (existing == null || booking.startMinutes < existing.startMinutes) {
        out[booking.staffId] = booking;
      }
    }
    return out;
  }

  /// Same as [busyDuring] but across several days at once — what "Repeat
  /// Mon–Fri" needs, since a teacher free on Monday may be booked on Tuesday.
  static Map<String, StaffBooking> busyDuringDays(
    Iterable<StaffBooking> bookings, {
    required Iterable<String> days,
    required String startTime,
    required int durationMinutes,
    Set<String> ignorePeriodIds = const {},
  }) {
    final out = <String, StaffBooking>{};
    for (final day in days) {
      final busy = busyDuring(
        bookings,
        dayOfWeek: day,
        startTime: startTime,
        durationMinutes: durationMinutes,
        ignorePeriodIds: ignorePeriodIds,
      );
      busy.forEach((staffId, booking) => out.putIfAbsent(staffId, () => booking));
    }
    return out;
  }

  /// Where [periods] of one classroom would put their staff into a class
  /// they are already teaching elsewhere. [others] are the bookings of the
  /// rest of the school — build them with [bookings] excluding this
  /// classroom.
  static List<StaffClash> clashesAgainst(
    Iterable<Period> periods, {
    required Iterable<StaffBooking> others,
    required String timetableId,
    required String timetableName,
    required String classroomId,
    required String classroomName,
  }) {
    final out = <StaffClash>[];
    for (final period in periods) {
      if (period.isTemporary) continue;
      if (!isRealStaff(period.staffId)) continue;
      final conflict = conflictFor(
        others,
        staffId: period.staffId,
        dayOfWeek: period.dayOfWeek,
        startTime: period.startTime,
        durationMinutes: period.durationMinutes,
      );
      if (conflict == null) continue;
      out.add(StaffClash(
        staffId: period.staffId,
        a: StaffBooking(
          staffId: period.staffId,
          timetableId: timetableId,
          timetableName: timetableName,
          classroomId: classroomId,
          classroomName: classroomName,
          dayOfWeek: period.dayOfWeek,
          periodId: period.id,
          periodName: period.name,
          startTime: period.startTime,
          durationMinutes: period.durationMinutes,
        ),
        b: conflict,
      ));
    }
    out.sort((x, y) {
      final day = Schedule.weekdays.indexOf(x.dayOfWeek).compareTo(Schedule.weekdays.indexOf(y.dayOfWeek));
      return day != 0 ? day : x.a.startMinutes.compareTo(y.a.startMinutes);
    });
    return out;
  }

  /// Every double-booking already sitting in [bookings] — the audit that
  /// finds damage saved before this rule existed.
  static List<StaffClash> auditClashes(Iterable<StaffBooking> bookings) {
    final byStaff = <String, List<StaffBooking>>{};
    for (final booking in bookings) {
      byStaff.putIfAbsent(booking.staffId, () => []).add(booking);
    }
    final out = <StaffClash>[];
    for (final entry in byStaff.entries) {
      final list = [...entry.value]
        ..sort((a, b) {
          final day = Schedule.weekdays.indexOf(a.dayOfWeek).compareTo(Schedule.weekdays.indexOf(b.dayOfWeek));
          return day != 0 ? day : a.startMinutes.compareTo(b.startMinutes);
        });
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          final a = list[i], b = list[j];
          if (a.dayOfWeek != b.dayOfWeek) continue;
          if (a.timetableId == b.timetableId && a.periodId == b.periodId) continue;
          if (b.startMinutes >= a.endMinutes) break;
          out.add(StaffClash(staffId: entry.key, a: a, b: b));
        }
      }
    }
    return out;
  }
}
