import 'academic_year.dart';
import 'attendance.dart';
import 'classroom.dart';
import 'student.dart';

/// What the school's attendance actually looks like on one day.
///
/// The admin's home used to show `present / (present + absent)`, which quietly
/// dropped every child nobody had marked yet. One class of two with one
/// present and one absent read "50%" — and so did a school of two hundred
/// where a single teacher had marked two children. The number was never
/// wrong about the children it counted; it just never said how few that was.
///
/// So coverage is part of the answer here, not a footnote: a rate is only
/// meaningful next to how much of the school it covers.
class DailyAttendance {
  /// Children marked present, on duty or arriving late — all of them are in
  /// school.
  final int present;

  final int absent;

  /// Enrolled children whose class has not been called yet.
  final int unmarked;

  /// Classrooms that hold at least one enrolled child.
  final int classroomsExpected;

  /// Classrooms whose roll has been called.
  final int classroomsMarked;

  /// The classes still to be called, named, so the admin knows who to ask.
  final List<String> classroomsPending;

  /// Enrolled children who are in no class at all.
  ///
  /// They cannot appear in any of the counts above, because attendance is
  /// taken a class at a time and they belong to none — so no teacher will ever
  /// be shown their name. Left implicit, that is a child quietly dropped from
  /// the register; counted here, it is a job for the office.
  final int unplaced;

  const DailyAttendance({
    this.present = 0,
    this.absent = 0,
    this.unmarked = 0,
    this.classroomsExpected = 0,
    this.classroomsMarked = 0,
    this.classroomsPending = const [],
    this.unplaced = 0,
  });

  /// Every enrolled child the day covers, marked or not.
  int get expected => present + absent + unmarked;

  int get marked => present + absent;

  /// Nobody has called a roll yet. The rate is not low — it is unknown, and
  /// the card has to say so rather than show a zero.
  bool get notTakenYet => marked == 0;

  bool get fullyMarked => classroomsExpected > 0 && classroomsMarked >= classroomsExpected;

  bool get partiallyMarked => !notTakenYet && !fullyMarked;

  /// Attendance among the children actually marked — null while none are.
  ///
  /// This is deliberately *not* over [expected]: counting unmarked children as
  /// absent would read as a catastrophe every morning before roll call.
  double? get ratePercent => marked == 0 ? null : present / marked * 100;

  /// How much of the school the rate speaks for.
  double get coveragePercent =>
      classroomsExpected == 0 ? 0 : classroomsMarked / classroomsExpected * 100;

  /// The headline: "—" until there is something to say.
  String get rateLabel {
    final rate = ratePercent;
    return rate == null ? '—' : '${rate.toStringAsFixed(0)}%';
  }

  /// The line under it, which is where the honesty lives.
  String get statusLabel {
    if (classroomsExpected == 0) return 'No classes with students yet';
    if (notTakenYet) return 'Not taken yet · $classroomsExpected classes';
    if (fullyMarked) return 'All $classroomsExpected classes marked';
    final left = classroomsExpected - classroomsMarked;
    return 'Partly marked · $left class${left == 1 ? '' : 'es'} left';
  }

  /// A sentence for the "needs attention" list, or null when nothing is owed.
  String? get attentionLabel {
    if (classroomsExpected == 0 || fullyMarked) return null;
    if (notTakenYet) {
      return "Attendance not taken in any class yet";
    }
    final left = classroomsExpected - classroomsMarked;
    return 'Attendance not taken in $left class${left == 1 ? '' : 'es'}';
  }

  /// A sentence about the children no class covers, or null when there are
  /// none. Kept separate from [attentionLabel] because it is a different job
  /// for a different person — one is "go ask a teacher to call the roll", the
  /// other is "this child has no class".
  String? get unplacedLabel {
    if (unplaced == 0) return null;
    return unplaced == 1
        ? '1 student is not in any class'
        : '$unplaced students are not in any class';
  }

  /// Builds the day from the roll-call rows.
  ///
  /// Only `homeroom` rows count. A subject teacher marking their own period
  /// is a different record with a different meaning, and letting those in made
  /// a child's day status depend on whichever row happened to be read last.
  static DailyAttendance forDay({
    required Iterable<Student> students,
    required Iterable<Classroom> classrooms,
    required Iterable<Attendance> rows,
  }) {
    final onRoll = [
      for (final s in students)
        if (s.isActive && s.lifecycle == StudentLifecycle.enrolled) s,
    ];
    final enrolled = [
      for (final s in onRoll)
        if (s.classroomId.isNotEmpty) s,
    ];

    final statusOf = <String, AttendanceStatus>{};
    final markedClassrooms = <String>{};
    for (final row in rows) {
      if (row.periodId != 'homeroom') continue;
      statusOf[row.studentId] = row.status;
      if (row.classroomId.isNotEmpty) markedClassrooms.add(row.classroomId);
    }

    var present = 0;
    var absent = 0;
    var unmarked = 0;
    for (final student in enrolled) {
      switch (statusOf[student.id]) {
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.present:
        case AttendanceStatus.od:
        case AttendanceStatus.delayed:
          present++;
        case null:
          unmarked++;
      }
    }

    // A classroom counts only when a child is actually enrolled in it — an
    // empty section is not an outstanding roll call.
    final withStudents = <String>{for (final s in enrolled) s.classroomId};
    final nameOf = {for (final c in classrooms) c.id: c.displayName};
    final pending = [
      for (final id in withStudents)
        if (!markedClassrooms.contains(id)) nameOf[id] ?? id,
    ]..sort();

    return DailyAttendance(
      present: present,
      absent: absent,
      unmarked: unmarked,
      classroomsExpected: withStudents.length,
      classroomsMarked: withStudents.where(markedClassrooms.contains).length,
      classroomsPending: pending,
      unplaced: onRoll.length - enrolled.length,
    );
  }
}

/// The staff equivalent, with the same honesty about who has not been marked.
///
/// The old count treated "no row" as present, so a morning before anyone had
/// touched staff attendance reported full attendance.
class DailyStaffAttendance {
  final int present;
  final int absent;
  final int unmarked;

  const DailyStaffAttendance({this.present = 0, this.absent = 0, this.unmarked = 0});

  int get expected => present + absent + unmarked;

  int get marked => present + absent;

  bool get notTakenYet => marked == 0;

  String get label => notTakenYet ? '— / $expected' : '$present / $expected';

  String get statusLabel {
    if (expected == 0) return 'No staff on record';
    if (notTakenYet) return 'Not marked yet';
    if (unmarked == 0) return 'All staff marked';
    return '$unmarked not marked yet';
  }

  static DailyStaffAttendance forDay({
    required Iterable<String> staffIds,
    required Map<String, AttendanceStatus> statusById,
  }) {
    var present = 0;
    var absent = 0;
    var unmarked = 0;
    for (final id in staffIds) {
      switch (statusById[id]) {
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.present:
        case AttendanceStatus.od:
        case AttendanceStatus.delayed:
          present++;
        case null:
          unmarked++;
      }
    }
    return DailyStaffAttendance(present: present, absent: absent, unmarked: unmarked);
  }
}
