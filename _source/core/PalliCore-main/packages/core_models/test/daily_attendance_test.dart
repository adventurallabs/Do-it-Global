import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

Student _student(String id, String classroomId, {StudentLifecycle life = StudentLifecycle.enrolled}) =>
    Student(
      id: id,
      name: 'Child $id',
      rollNumber: id,
      fatherName: '',
      motherName: '',
      contactNumber: '',
      address: '',
      fees: 0,
      admissionNo: id,
      classroomId: classroomId,
      lifecycle: life,
    );

Classroom _room(String id, String name) =>
    Classroom(id: id, name: name, classTeacherId: '', baseFees: 0);

Attendance _mark(String studentId, String classroomId, AttendanceStatus status,
        {String periodId = 'homeroom'}) =>
    Attendance(
      id: '$studentId-$periodId',
      studentId: studentId,
      classroomId: classroomId,
      periodId: periodId,
      date: DateTime(2026, 9, 28),
      status: status,
      markedBy: 't1',
    );

void main() {
  group('DailyAttendance — children in no class', () {
    test('a class-less child is counted and named, never silently dropped', () {
      // Three real children were sitting in the live database with a blank
      // classroom. Attendance is taken a class at a time, so no teacher would
      // ever have been shown their names, and every count on the admin's home
      // screen skipped them — which made the school look smaller than it was
      // rather than showing there was a job to do.
      final day = DailyAttendance.forDay(
        students: [
          _student('a', 'r1'),
          _student('b', ''),
          _student('c', ''),
          // A leaver with no class is not an outstanding job.
          _student('d', '', life: StudentLifecycle.discontinued),
        ],
        classrooms: [_room('r1', 'LKG A')],
        rows: [_mark('a', 'r1', AttendanceStatus.present)],
      );

      expect(day.unplaced, 2);
      expect(day.unplacedLabel, '2 students are not in any class');
      // They must not distort the rate: the one child who was marked is still
      // 100%, because a class-less child was never absent — just unplaced.
      expect(day.ratePercent, 100);
      expect(day.fullyMarked, isTrue);
    });

    test('one child reads as one, and none says nothing at all', () {
      final one = DailyAttendance.forDay(
        students: [_student('a', 'r1'), _student('b', '')],
        classrooms: [_room('r1', 'LKG A')],
        rows: const [],
      );
      expect(one.unplacedLabel, '1 student is not in any class');

      final none = DailyAttendance.forDay(
        students: [_student('a', 'r1')],
        classrooms: [_room('r1', 'LKG A')],
        rows: const [],
      );
      expect(none.unplaced, 0);
      expect(none.unplacedLabel, isNull);
    });
  });

  group('DailyAttendance', () {
    test('a rate never speaks for children nobody has marked', () {
      // The reported confusion: one class of two, one present and one absent,
      // read "50%" — while three other classes had not been called at all.
      final day = DailyAttendance.forDay(
        students: [
          _student('s1', 'c1'), _student('s2', 'c1'),
          _student('s3', 'c2'), _student('s4', 'c3'),
        ],
        classrooms: [_room('c1', 'LKG A'), _room('c2', 'LKG B'), _room('c3', 'UKG')],
        rows: [
          _mark('s1', 'c1', AttendanceStatus.present),
          _mark('s2', 'c1', AttendanceStatus.absent),
        ],
      );

      expect(day.present, 1);
      expect(day.absent, 1);
      expect(day.unmarked, 2, reason: 'c2 and c3 were never called');
      expect(day.expected, 4);
      expect(day.ratePercent, 50);
      // The rate is still 50 — but the card can no longer show it alone.
      expect(day.classroomsExpected, 3);
      expect(day.classroomsMarked, 1);
      expect(day.partiallyMarked, isTrue);
      expect(day.statusLabel, 'Partly marked · 2 classes left');
      expect(day.classroomsPending, ['LKG B', 'UKG']);
    });

    test('before anyone calls a roll the rate is unknown, not zero', () {
      final day = DailyAttendance.forDay(
        students: [_student('s1', 'c1'), _student('s2', 'c2')],
        classrooms: [_room('c1', 'LKG A'), _room('c2', 'UKG')],
        rows: const [],
      );

      expect(day.notTakenYet, isTrue);
      expect(day.ratePercent, isNull);
      expect(day.rateLabel, '—', reason: 'a zero would read as nobody turned up');
      expect(day.statusLabel, 'Not taken yet · 2 classes');
      expect(day.attentionLabel, 'Attendance not taken in any class yet');
    });

    test('a fully marked day says so and owes nothing', () {
      final day = DailyAttendance.forDay(
        students: [_student('s1', 'c1'), _student('s2', 'c1')],
        classrooms: [_room('c1', 'LKG A')],
        rows: [
          _mark('s1', 'c1', AttendanceStatus.present),
          _mark('s2', 'c1', AttendanceStatus.present),
        ],
      );

      expect(day.fullyMarked, isTrue);
      expect(day.rateLabel, '100%');
      expect(day.statusLabel, 'All 1 classes marked');
      expect(day.attentionLabel, isNull);
      expect(day.classroomsPending, isEmpty);
    });

    test('a subject period is not the day\'s roll call', () {
      // A science teacher marking their own period must not decide whether the
      // child was in school that day — nor make the class look called.
      final day = DailyAttendance.forDay(
        students: [_student('s1', 'c1')],
        classrooms: [_room('c1', 'LKG A')],
        rows: [_mark('s1', 'c1', AttendanceStatus.present, periodId: 'p7')],
      );

      expect(day.marked, 0);
      expect(day.unmarked, 1);
      expect(day.notTakenYet, isTrue);
      expect(day.classroomsMarked, 0);
    });

    test('on duty and arriving late are in school', () {
      final day = DailyAttendance.forDay(
        students: [_student('s1', 'c1'), _student('s2', 'c1'), _student('s3', 'c1')],
        classrooms: [_room('c1', 'LKG A')],
        rows: [
          _mark('s1', 'c1', AttendanceStatus.od),
          _mark('s2', 'c1', AttendanceStatus.delayed),
          _mark('s3', 'c1', AttendanceStatus.absent),
        ],
      );

      expect(day.present, 2);
      expect(day.absent, 1);
      expect(day.ratePercent, closeTo(66.67, 0.01));
    });

    test('children who have left are not owed a roll call', () {
      final day = DailyAttendance.forDay(
        students: [
          _student('s1', 'c1'),
          _student('s2', 'c1', life: StudentLifecycle.transferred),
          _student('s3', 'c1', life: StudentLifecycle.graduated),
          _student('s4', ''), // unassigned
        ],
        classrooms: [_room('c1', 'LKG A')],
        rows: [_mark('s1', 'c1', AttendanceStatus.present)],
      );

      expect(day.expected, 1);
      expect(day.fullyMarked, isTrue);
    });

    test('an empty section is not an outstanding roll call', () {
      final day = DailyAttendance.forDay(
        students: [_student('s1', 'c1')],
        classrooms: [_room('c1', 'LKG A'), _room('c2', 'LKG B')],
        rows: [_mark('s1', 'c1', AttendanceStatus.present)],
      );

      expect(day.classroomsExpected, 1, reason: 'LKG B has nobody in it');
      expect(day.fullyMarked, isTrue);
    });

    test('a school with no students reads as nothing to do', () {
      final day = DailyAttendance.forDay(students: const [], classrooms: const [], rows: const []);
      expect(day.statusLabel, 'No classes with students yet');
      expect(day.attentionLabel, isNull);
      expect(day.rateLabel, '—');
    });
  });

  group('DailyStaffAttendance', () {
    test('an unmarked teacher is not counted as present', () {
      final day = DailyStaffAttendance.forDay(
        staffIds: ['t1', 't2', 't3'],
        statusById: {'t1': AttendanceStatus.present, 't2': AttendanceStatus.absent},
      );

      expect(day.present, 1);
      expect(day.absent, 1);
      expect(day.unmarked, 1);
      expect(day.label, '1 / 3');
      expect(day.statusLabel, '1 not marked yet');
    });

    test('before staff attendance is touched it says so', () {
      final day = DailyStaffAttendance.forDay(staffIds: ['t1', 't2'], statusById: const {});
      expect(day.notTakenYet, isTrue);
      expect(day.label, '— / 2');
      expect(day.statusLabel, 'Not marked yet');
    });
  });
}
