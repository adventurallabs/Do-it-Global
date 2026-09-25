import 'classroom.dart';
import 'schedule.dart';
import 'timetable.dart';

/// What one teacher is allowed to do in one classroom.
///
/// The timetable is the only thing that grants a teacher anything: the
/// subjects they are given periods for are the subjects whose marks they own,
/// and the homeroom they are named class teacher of is the only place they
/// take roll call. Every teacher screen asks this, so "can I touch this?" has
/// one answer rather than one per screen.
class TeachingScope {
  final String teacherId;
  final String classroomId;
  final String classroomName;

  /// Subjects this teacher has live periods for here — sorted, de-duped,
  /// breaks and one-day cover excluded.
  final List<String> subjects;

  /// True when the admin named them class teacher of this classroom.
  final bool isClassTeacher;

  /// False when this classroom has no timetable at all. Then nobody teaches
  /// a subject here, so nobody owns its marks — and the honest thing to tell
  /// a teacher is that the timetable is missing, not that the marks belong
  /// to colleagues who do not exist.
  final bool classroomHasTimetable;

  const TeachingScope({
    required this.teacherId,
    required this.classroomId,
    required this.classroomName,
    this.subjects = const [],
    this.isClassTeacher = false,
    this.classroomHasTimetable = true,
  });

  bool get teachesHere => subjects.isNotEmpty;

  /// Daily roll call belongs to the homeroom teacher. A subject teacher sees
  /// the class for forty-five minutes; the attendance a parent reads is the
  /// school day, marked once, by the one person responsible for it.
  bool get canTakeAttendance => isClassTeacher;

  /// Marks follow the subject, never the classroom — the science teacher
  /// cannot touch the English column, and neither can the class teacher
  /// unless they also teach it.
  bool canEnterMarksFor(String subject) {
    final wanted = subject.trim().toLowerCase();
    if (wanted.isEmpty) return false;
    return subjects.any((s) => s.trim().toLowerCase() == wanted);
  }

  bool get canEnterMarks => subjects.isNotEmpty;

  /// Null when the subject is theirs; otherwise a sentence saying why not.
  String? marksBlockedReason(String subject) {
    if (canEnterMarksFor(subject)) return null;
    if (!classroomHasTimetable) {
      return '$classroomName has no class timetable yet, so no teacher owns '
          'its marks — not even you. Ask the admin to build it, then this '
          'opens by itself.';
    }
    if (subjects.isEmpty) {
      return "You don't teach any subject in $classroomName, so its marks "
          'belong to the teachers who do.';
    }
    return '$subject is taught by another teacher in $classroomName. '
        'You can record ${_list(subjects)}.';
  }

  static String _list(List<String> items) {
    if (items.length == 1) return items.single;
    return '${items.take(items.length - 1).join(', ')} and ${items.last}';
  }

  /// Every classroom this teacher has any standing in, keyed by classroom id:
  /// the ones they teach a subject in, plus their own homeroom even when they
  /// teach nothing in it.
  static Map<String, TeachingScope> forTeacher({
    required String teacherId,
    required Iterable<Classroom> classrooms,
    required Iterable<Timetable> timetables,
    bool activeOnly = true,
  }) {
    final subjectsByClassroom = <String, Set<String>>{};
    for (final timetable in timetables) {
      if (activeOnly && !timetable.isActive) continue;
      for (final period in timetable.periods) {
        // A one-day stand-in covers the lesson; they don't inherit the
        // subject's marks.
        if (period.isTemporary) continue;
        if (period.staffId != teacherId) continue;
        if (Schedule.isBreak(period)) continue;
        final name = period.name.trim();
        if (name.isEmpty) continue;
        subjectsByClassroom.putIfAbsent(timetable.classroomId, () => {}).add(name);
      }
    }

    final timetabled = {for (final t in timetables) t.classroomId};
    final out = <String, TeachingScope>{};
    for (final classroom in classrooms) {
      final subjects = subjectsByClassroom[classroom.id];
      final isClassTeacher = classroom.classTeacherId == teacherId;
      if (subjects == null && !isClassTeacher) continue;
      out[classroom.id] = TeachingScope(
        teacherId: teacherId,
        classroomId: classroom.id,
        classroomName: classroom.displayName,
        subjects: (subjects?.toList() ?? <String>[])..sort(),
        isClassTeacher: isClassTeacher,
        classroomHasTimetable: timetabled.contains(classroom.id),
      );
    }
    return out;
  }

  /// Every classroom this teacher has standing in, decided exactly as the
  /// database's `teacher_teaches()` decides it: per classroom, its active
  /// timetable — or any timetable when that classroom has never activated
  /// one.
  ///
  /// This is the only builder screens should use. Deciding "active or not"
  /// school-wide instead (the old fallback) let a teacher be offered a mark
  /// sheet the database then refused, and hid sheets it would have accepted.
  static Map<String, TeachingScope> asDatabaseSees({
    required String teacherId,
    required Iterable<Classroom> classrooms,
    required Iterable<Timetable> timetables,
  }) {
    final rooms = classrooms.toList();
    final tts = timetables.toList();
    final active = forTeacher(teacherId: teacherId, classrooms: rooms, timetables: tts);
    final any = forTeacher(teacherId: teacherId, classrooms: rooms, timetables: tts, activeOnly: false);
    final hasActive = {for (final t in tts) if (t.isActive) t.classroomId};
    return <String, TeachingScope>{
      for (final c in rooms) c.id: ?(hasActive.contains(c.id) ? active : any)[c.id],
    };
  }

  /// A scope for a classroom that isn't in the map — no subjects, no roll
  /// call. Keeps callers from having to null-check everywhere.
  static TeachingScope none(
    String teacherId,
    Classroom classroom, {
    bool classroomHasTimetable = true,
  }) =>
      TeachingScope(
        teacherId: teacherId,
        classroomId: classroom.id,
        classroomName: classroom.displayName,
        classroomHasTimetable: classroomHasTimetable,
      );
}
