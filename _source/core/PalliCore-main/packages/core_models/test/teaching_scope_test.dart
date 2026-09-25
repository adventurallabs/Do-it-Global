import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

Period _p(String id, String staffId, String name, {bool temporary = false}) => Period(
      id: id,
      name: name,
      staffId: staffId,
      startTime: '09:30',
      durationMinutes: 45,
      dayOfWeek: 'Monday',
      isTemporary: temporary,
      date: temporary ? DateTime(2026, 9, 21) : null,
    );

Timetable _tt(String id, String classroomId, List<Period> periods, {bool active = true}) =>
    Timetable(
      id: id,
      classroomId: classroomId,
      name: 'Regular week',
      isActive: active,
      periods: periods,
    );

Classroom _room(String id, String name, {String classTeacherId = ''}) =>
    Classroom(id: id, name: name, classTeacherId: classTeacherId, baseFees: 0);

void main() {
  final lkg = _room('lkg-a', 'LKG A');
  final std1 = _room('std-1', '1 Std', classTeacherId: 'sci-teacher');

  group('forTeacher', () {
    test('grants only the subjects the timetable gives them', () {
      final scopes = TeachingScope.forTeacher(
        teacherId: 'sci-teacher',
        classrooms: [lkg, std1],
        timetables: [
          _tt('tt-lkg', 'lkg-a', [
            _p('p1', 'sci-teacher', 'Science'),
            _p('p2', 'eng-teacher', 'English'),
            _p('p3', StaffAvailability.noStaffId, 'Lunch'),
          ]),
        ],
      );

      expect(scopes['lkg-a']!.subjects, ['Science']);
      expect(scopes['lkg-a']!.canEnterMarksFor('Science'), isTrue);
      expect(scopes['lkg-a']!.canEnterMarksFor('English'), isFalse);
      expect(scopes['lkg-a']!.canEnterMarksFor('Lunch'), isFalse);
    });

    test('subject matching ignores case and stray spacing', () {
      final scope = TeachingScope.forTeacher(
        teacherId: 'sci-teacher',
        classrooms: [lkg],
        timetables: [
          _tt('tt', 'lkg-a', [_p('p1', 'sci-teacher', 'Science')]),
        ],
      )['lkg-a']!;
      expect(scope.canEnterMarksFor(' science '), isTrue);
      expect(scope.canEnterMarksFor(''), isFalse);
    });

    test('a one-day stand-in does not inherit the subject', () {
      final scopes = TeachingScope.forTeacher(
        teacherId: 'cover-teacher',
        classrooms: [lkg],
        timetables: [
          _tt('tt', 'lkg-a', [_p('p1', 'cover-teacher', 'Science', temporary: true)]),
        ],
      );
      expect(scopes, isEmpty);
    });

    test('a draft timetable grants nothing until it is activated', () {
      final scopes = TeachingScope.forTeacher(
        teacherId: 'sci-teacher',
        classrooms: [lkg],
        timetables: [
          _tt('tt', 'lkg-a', [_p('p1', 'sci-teacher', 'Science')], active: false),
        ],
      );
      expect(scopes, isEmpty);
      final relaxed = TeachingScope.forTeacher(
        teacherId: 'sci-teacher',
        classrooms: [lkg],
        timetables: [
          _tt('tt', 'lkg-a', [_p('p1', 'sci-teacher', 'Science')], active: false),
        ],
        activeOnly: false,
      );
      expect(relaxed['lkg-a']!.subjects, ['Science']);
    });

    test('the homeroom appears even when they teach nothing in it', () {
      final scopes = TeachingScope.forTeacher(
        teacherId: 'sci-teacher',
        classrooms: [std1],
        timetables: const [],
      );
      expect(scopes['std-1']!.isClassTeacher, isTrue);
      expect(scopes['std-1']!.subjects, isEmpty);
      expect(scopes['std-1']!.canEnterMarks, isFalse);
    });
  });

  group('attendance', () {
    test('belongs to the class teacher, not to a subject teacher', () {
      final scopes = TeachingScope.forTeacher(
        teacherId: 'sci-teacher',
        classrooms: [lkg, std1],
        timetables: [
          _tt('tt-lkg', 'lkg-a', [_p('p1', 'sci-teacher', 'Science')]),
          _tt('tt-std1', 'std-1', [_p('p2', 'sci-teacher', 'Science')]),
        ],
      );
      // Teaches in both, class teacher of only one.
      expect(scopes['lkg-a']!.canTakeAttendance, isFalse);
      expect(scopes['std-1']!.canTakeAttendance, isTrue);
    });
  });

  group('marksBlockedReason', () {
    test('is null for a subject they own', () {
      final scope = TeachingScope.forTeacher(
        teacherId: 'sci-teacher',
        classrooms: [lkg],
        timetables: [
          _tt('tt', 'lkg-a', [_p('p1', 'sci-teacher', 'Science')]),
        ],
      )['lkg-a']!;
      expect(scope.marksBlockedReason('Science'), isNull);
      expect(scope.marksBlockedReason('English'), contains('taught by another teacher'));
    });

    test('says so plainly when they teach nothing here', () {
      final scope = TeachingScope.none('sci-teacher', lkg);
      expect(scope.marksBlockedReason('English'), contains("don't teach any subject"));
      expect(scope.canTakeAttendance, isFalse);
    });

    test('a section with no timetable blames the timetable, not colleagues', () {
      // LKG B exists and sits the exam, but the admin never built its
      // timetable. Telling its class teacher the marks "belong to the
      // teachers who do" points at nobody — there are no subject teachers.
      final lkgB = _room('lkg-b', 'LKG B', classTeacherId: 'sci-teacher');
      final scope = TeachingScope.asDatabaseSees(
        teacherId: 'sci-teacher',
        classrooms: [lkg, lkgB],
        timetables: [
          _tt('tt-lkg', 'lkg-a', [_p('p1', 'sci-teacher', 'Science')]),
        ],
      )['lkg-b']!;

      expect(scope.classroomHasTimetable, isFalse);
      expect(scope.canEnterMarks, isFalse);
      expect(scope.marksBlockedReason('Science'), contains('no class timetable yet'));
      expect(scope.marksBlockedReason('Science'), isNot(contains('belong to the teachers')));
    });
  });

  group('asDatabaseSees', () {
    test('judges each classroom on its own, as teacher_teaches() does', () {
      // One classroom activated a timetable; the other never did. The
      // database falls back per classroom, so the app must too — judging it
      // school-wide offered sheets that were then refused on save.
      final scopes = TeachingScope.asDatabaseSees(
        teacherId: 'sci-teacher',
        classrooms: [lkg, std1],
        timetables: [
          _tt('tt-lkg', 'lkg-a', [_p('p1', 'sci-teacher', 'Science')]),
          _tt('tt-lkg-draft', 'lkg-a', [_p('p2', 'sci-teacher', 'Maths')], active: false),
          _tt('tt-std1-draft', 'std-1', [_p('p3', 'sci-teacher', 'Science')], active: false),
        ],
      );

      // LKG A has an active timetable: only the active one counts, so the
      // draft's Maths is not theirs.
      expect(scopes['lkg-a']!.subjects, ['Science']);
      // 1 Std never activated one, so its only timetable is what stands.
      expect(scopes['std-1']!.subjects, ['Science']);
      expect(scopes['std-1']!.canEnterMarksFor('Science'), isTrue);
    });
  });
}
