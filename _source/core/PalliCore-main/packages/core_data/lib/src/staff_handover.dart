import 'package:core_models/core_models.dart';
import 'classroom_repository.dart';
import 'teacher_repository.dart';
import 'timetable_repository.dart';

/// What a classroom loses when the teacher running it goes away.
class HandoverImpact {
  /// Classrooms where this teacher is the named class teacher.
  final List<Classroom> homerooms;

  /// Every live period they hold, across every class.
  final List<StaffBooking> periods;

  const HandoverImpact({this.homerooms = const [], this.periods = const []});

  bool get isEmpty => homerooms.isEmpty && periods.isEmpty;

  /// The classes affected at all, homeroom or subject.
  Set<String> get classroomIds => {
        ...homerooms.map((c) => c.id),
        ...periods.map((p) => p.classroomId),
      };

  List<StaffBooking> periodsIn(String classroomId) =>
      periods.where((p) => p.classroomId == classroomId).toList();
}

/// Moving a class from one teacher to another.
///
/// A classroom is not owned by its teacher: its students, marks, attendance,
/// diary and progress all hang off the classroom, so a new class teacher
/// inherits them simply by being named. What does *not* follow automatically
/// is the timetable — periods name a staff id, so unless they are moved too
/// the incoming teacher arrives with no subjects and the outgoing one keeps
/// teaching. That is the gap this fills.
class StaffHandover {
  StaffHandover._();

  /// Everything that would be left dangling if [teacherId] stopped working
  /// here today.
  static Future<HandoverImpact> impactOf(
    String teacherId, {
    required ClassroomRepository classrooms,
    required TimetableRepository timetables,
  }) async {
    final (rooms, schedules) = await (classrooms.getAll(), timetables.getAll()).wait;
    final names = {for (final c in rooms) c.id: c.displayName};
    final bookings = StaffAvailability.bookings(schedules, classroomNames: names)
        .where((b) => b.staffId == teacherId)
        .toList();
    return HandoverImpact(
      homerooms: rooms.where((c) => c.classTeacherId == teacherId).toList(),
      periods: bookings,
    );
  }

  /// Names [toTeacherId] class teacher of [classroom], and keeps the
  /// teachers' own homeroom pointer in step on both sides. Passing null
  /// leaves the class without one.
  static Future<void> setClassTeacher(
    Classroom classroom,
    String? toTeacherId, {
    required ClassroomRepository classrooms,
    required TeacherRepository teachers,
  }) async {
    await classrooms.upsert(classroom.copyWith(classTeacherId: toTeacherId ?? ''));
    final staff = await teachers.getAll();
    final writes = <Future<void>>[];
    for (final teacher in staff) {
      if (teacher.id == toTeacherId && teacher.classroomId != classroom.id) {
        writes.add(teachers.upsert(teacher.copyWith(classroomId: classroom.id)));
      } else if (teacher.id != toTeacherId && teacher.classroomId == classroom.id) {
        writes.add(teachers.upsert(teacher.copyWith(clearClassroom: true)));
      }
    }
    await Future.wait(writes);
  }

  /// Hands every period [fromTeacherId] holds to [toTeacherId], or leaves
  /// them unassigned when that is null.
  ///
  /// [onlyClassroomIds] narrows it to certain classes — a class-teacher
  /// change usually moves only that class's periods, while a teacher leaving
  /// moves all of them. Each timetable is written once: a period-at-a-time
  /// loop would read stale copies and drop all but the last change.
  static Future<int> reassignPeriods({
    required TimetableRepository timetables,
    required String fromTeacherId,
    required String? toTeacherId,
    Set<String>? onlyClassroomIds,
  }) async {
    final all = await timetables.getAll();
    final target = toTeacherId ?? StaffAvailability.noStaffId;
    var moved = 0;
    final writes = <Future<void>>[];
    for (final timetable in all) {
      if (onlyClassroomIds != null && !onlyClassroomIds.contains(timetable.classroomId)) {
        continue;
      }
      var touched = false;
      final periods = [
        for (final period in timetable.periods)
          if (period.staffId == fromTeacherId)
            () {
              touched = true;
              moved++;
              return period.copyWith(staffId: target);
            }()
          else
            period,
      ];
      if (!touched) continue;
      writes.add(timetables.upsert(Timetable(
        id: timetable.id,
        classroomId: timetable.classroomId,
        name: timetable.name,
        isActive: timetable.isActive,
        periods: periods,
        startTime: timetable.startTime,
        endTime: timetable.endTime,
        intervalCount: timetable.intervalCount,
      )));
    }
    await Future.wait(writes);
    return moved;
  }

  /// The periods [toTeacherId] could not take over, because they are already
  /// in another class at that hour. Checked before the move so an admin is
  /// never handed a double-booked timetable.
  static Future<List<(StaffBooking incoming, StaffBooking clash)>> clashesForTakeover({
    required TimetableRepository timetables,
    required ClassroomRepository classrooms,
    required String fromTeacherId,
    required String toTeacherId,
    Set<String>? onlyClassroomIds,
  }) async {
    final (rooms, schedules) = await (classrooms.getAll(), timetables.getAll()).wait;
    final names = {for (final c in rooms) c.id: c.displayName};
    final all = StaffAvailability.bookings(schedules, classroomNames: names);
    final moving = all.where((b) =>
        b.staffId == fromTeacherId &&
        (onlyClassroomIds == null || onlyClassroomIds.contains(b.classroomId)));
    // Their existing load, minus anything that is itself being moved away.
    final existing = all
        .where((b) =>
            b.staffId == toTeacherId &&
            !(b.staffId == fromTeacherId &&
                (onlyClassroomIds == null || onlyClassroomIds.contains(b.classroomId))))
        .toList();

    final out = <(StaffBooking, StaffBooking)>[];
    for (final period in moving) {
      final clash = StaffAvailability.conflictFor(
        existing,
        staffId: toTeacherId,
        dayOfWeek: period.dayOfWeek,
        startTime: period.startTime,
        durationMinutes: period.durationMinutes,
      );
      if (clash != null) out.add((period, clash));
    }
    return out;
  }
}
