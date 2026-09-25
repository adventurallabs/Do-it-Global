import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

Period _period(
  String id,
  String staffId,
  String start, {
  int minutes = 45,
  String day = 'Monday',
  String name = 'Mathematics',
  bool temporary = false,
  DateTime? date,
}) =>
    Period(
      id: id,
      name: name,
      staffId: staffId,
      startTime: start,
      durationMinutes: minutes,
      dayOfWeek: day,
      isTemporary: temporary,
      date: date,
    );

Timetable _timetable(
  String id,
  String classroomId,
  List<Period> periods, {
  bool active = true,
}) =>
    Timetable(
      id: id,
      classroomId: classroomId,
      name: 'Regular week',
      isActive: active,
      periods: periods,
    );

void main() {
  group('StaffAvailability.bookings', () {
    test('skips breaks, drafts and the excluded classroom', () {
      final timetables = [
        _timetable('tt-lkg', 'lkg-a', [
          _period('p1', 't1', '09:30'),
          _period('p2', StaffAvailability.noStaffId, '10:15', name: 'Break', minutes: 15),
        ]),
        _timetable('tt-draft', 'std-1', [_period('p3', 't1', '09:30')], active: false),
        _timetable('tt-own', 'std-2', [_period('p4', 't2', '09:30')]),
      ];

      final bookings = StaffAvailability.bookings(
        timetables,
        excludeClassroomIds: {'std-2'},
        classroomNames: {'lkg-a': 'LKG A'},
      );

      expect(bookings.map((b) => b.periodId), ['p1']);
      expect(bookings.single.classroomName, 'LKG A');
    });
  });

  group('conflictFor', () {
    final bookings = StaffAvailability.bookings([
      _timetable('tt-lkg', 'lkg-a', [_period('p1', 't1', '09:30')]),
    ], classroomNames: {'lkg-a': 'LKG A'});

    test('catches the exact slot the same teacher already runs', () {
      final conflict = StaffAvailability.conflictFor(
        bookings,
        staffId: 't1',
        dayOfWeek: 'Monday',
        startTime: '09:30',
        durationMinutes: 45,
      );
      expect(conflict?.classroomName, 'LKG A');
      expect(conflict?.range, '9:30 AM – 10:15 AM');
    });

    test('catches a partial overlap at either edge', () {
      for (final start in ['09:00', '10:00']) {
        expect(
          StaffAvailability.conflictFor(
            bookings,
            staffId: 't1',
            dayOfWeek: 'Monday',
            startTime: start,
            durationMinutes: 45,
          ),
          isNotNull,
          reason: 'a period starting $start runs into 9:30 – 10:15',
        );
      }
    });

    test('lets a back-to-back period through', () {
      expect(
        StaffAvailability.conflictFor(
          bookings,
          staffId: 't1',
          dayOfWeek: 'Monday',
          startTime: '10:15',
          durationMinutes: 45,
        ),
        isNull,
      );
    });

    test('is per teacher and per day', () {
      expect(
        StaffAvailability.conflictFor(
          bookings,
          staffId: 't2',
          dayOfWeek: 'Monday',
          startTime: '09:30',
          durationMinutes: 45,
        ),
        isNull,
      );
      expect(
        StaffAvailability.conflictFor(
          bookings,
          staffId: 't1',
          dayOfWeek: 'Tuesday',
          startTime: '09:30',
          durationMinutes: 45,
        ),
        isNull,
      );
    });

    test('never blocks the no-staff placeholder', () {
      final breaks = StaffAvailability.bookings([
        _timetable('tt', 'lkg-a', [
          _period('p1', StaffAvailability.noStaffId, '09:30', name: 'Lunch'),
        ]),
      ]);
      expect(breaks, isEmpty);
      expect(
        StaffAvailability.conflictFor(
          breaks,
          staffId: StaffAvailability.noStaffId,
          dayOfWeek: 'Monday',
          startTime: '09:30',
          durationMinutes: 45,
        ),
        isNull,
      );
    });
  });

  group('busyDuringDays', () {
    test('a teacher free on Monday but booked on Thursday still blocks Mon–Fri', () {
      final bookings = StaffAvailability.bookings([
        _timetable('tt', 'lkg-a', [_period('p1', 't1', '09:30', day: 'Thursday')]),
      ], classroomNames: {'lkg-a': 'LKG A'});

      expect(
        StaffAvailability.busyDuring(
          bookings,
          dayOfWeek: 'Monday',
          startTime: '09:30',
          durationMinutes: 45,
        ),
        isEmpty,
      );
      final busy = StaffAvailability.busyDuringDays(
        bookings,
        days: const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        startTime: '09:30',
        durationMinutes: 45,
      );
      expect(busy.keys, ['t1']);
      expect(busy['t1']!.dayOfWeek, 'Thursday');
    });
  });

  group('clashesAgainst', () {
    test('finds the LKG A / 1 Std double-booking and names both sides', () {
      final others = StaffAvailability.bookings([
        _timetable('tt-lkg', 'lkg-a', [_period('p1', 't1', '09:30', name: 'English')]),
      ], classroomNames: {'lkg-a': 'LKG A'});

      final clashes = StaffAvailability.clashesAgainst(
        [
          _period('q1', 't1', '09:30', name: 'Mathematics'),
          _period('q2', 't2', '10:15', name: 'Science'),
        ],
        others: others,
        timetableId: 'tt-std1',
        timetableName: 'Regular week',
        classroomId: 'std-1',
        classroomName: '1 Std',
      );

      expect(clashes, hasLength(1));
      expect(clashes.single.staffId, 't1');
      expect(clashes.single.a.classroomName, '1 Std');
      expect(clashes.single.b.classroomName, 'LKG A');
      expect(clashes.single.b.periodName, 'English');
    });

    test('ignores one-day cover rows in the schedule being checked', () {
      final others = StaffAvailability.bookings([
        _timetable('tt-lkg', 'lkg-a', [_period('p1', 't1', '09:30')]),
      ]);
      final clashes = StaffAvailability.clashesAgainst(
        [_period('q1', 't1', '09:30', temporary: true, date: DateTime(2026, 9, 21))],
        others: others,
        timetableId: 'tt',
        timetableName: 'Regular week',
        classroomId: 'std-1',
        classroomName: '1 Std',
      );
      expect(clashes, isEmpty);
    });
  });

  group('auditClashes', () {
    test('reports each pair once and leaves clean weeks alone', () {
      final bookings = StaffAvailability.bookings([
        _timetable('tt-a', 'lkg-a', [_period('p1', 't1', '09:30')]),
        _timetable('tt-b', 'std-1', [_period('p2', 't1', '09:45')]),
        _timetable('tt-c', 'std-2', [_period('p3', 't1', '11:00')]),
      ]);
      final clashes = StaffAvailability.auditClashes(bookings);
      expect(clashes, hasLength(1));
      expect({clashes.single.a.classroomId, clashes.single.b.classroomId}, {'lkg-a', 'std-1'});
    });
  });
}
