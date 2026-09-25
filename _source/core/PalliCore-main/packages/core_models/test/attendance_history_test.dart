import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

Attendance _row(int day, AttendanceStatus status,
        {String periodId = 'homeroom', int hour = 9}) =>
    Attendance(
      id: 'a$day-$periodId-$hour',
      studentId: 's1',
      classroomId: 'c1',
      periodId: periodId,
      date: DateTime(2026, 9, day, hour),
      status: status,
      markedBy: 't1',
    );

AttendanceHistory _history(List<Attendance> rows) => AttendanceHistory.fromRows(
      rows: rows,
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 9, 30),
    );

void main() {
  group('AttendanceHistory', () {
    test('a rate is over recorded days, not calendar days', () {
      // Only four days were ever marked. Counting the rest of September as
      // absences would turn holidays and weekends into a truancy record.
      final h = _history([
        _row(1, AttendanceStatus.present),
        _row(2, AttendanceStatus.present),
        _row(3, AttendanceStatus.absent),
        _row(4, AttendanceStatus.present),
      ]);

      expect(h.recorded, 4);
      expect(h.present, 3);
      expect(h.absent, 1);
      expect(h.ratePercent, 75);
      expect(h.rateLabel, '75%');
    });

    test('with nothing recorded the rate is unknown, not zero', () {
      final h = _history(const []);
      expect(h.recorded, 0);
      expect(h.ratePercent, isNull);
      expect(h.rateLabel, '—');
      expect(h.absentDates, isEmpty);
      expect(h.longestAbsenceRun, 0);
      expect(h.currentAbsenceRun, 0);
    });

    test('on duty and late are days in school', () {
      final h = _history([
        _row(1, AttendanceStatus.od),
        _row(2, AttendanceStatus.delayed),
        _row(3, AttendanceStatus.absent),
      ]);
      expect(h.present, 2);
      expect(h.absent, 1);
    });

    test('a subject period is not a day of attendance', () {
      final h = _history([
        _row(1, AttendanceStatus.present, periodId: 'p3'),
        _row(2, AttendanceStatus.present),
      ]);
      expect(h.recorded, 1, reason: 'only the homeroom roll counts as the day');
    });

    test('a day corrected later keeps the correction', () {
      final h = _history([
        _row(5, AttendanceStatus.absent, hour: 9),
        _row(5, AttendanceStatus.present, hour: 14),
      ]);
      expect(h.recorded, 1);
      expect(h.present, 1);
      expect(h.absent, 0);
    });

    test('a long absence is told apart from scattered ones', () {
      final scattered = _history([
        _row(1, AttendanceStatus.absent),
        _row(2, AttendanceStatus.present),
        _row(3, AttendanceStatus.absent),
        _row(4, AttendanceStatus.present),
        _row(5, AttendanceStatus.absent),
      ]);
      final block = _history([
        _row(1, AttendanceStatus.present),
        _row(2, AttendanceStatus.absent),
        _row(3, AttendanceStatus.absent),
        _row(4, AttendanceStatus.absent),
        _row(5, AttendanceStatus.present),
      ]);

      // Same rate, very different stories.
      expect(scattered.ratePercent, block.ratePercent);
      expect(scattered.longestAbsenceRun, 1);
      expect(block.longestAbsenceRun, 3);
    });

    test('an absence still running today is counted separately', () {
      final h = _history([
        _row(1, AttendanceStatus.present),
        _row(2, AttendanceStatus.absent),
        _row(3, AttendanceStatus.absent),
      ]);
      expect(h.currentAbsenceRun, 2);

      final back = _history([
        _row(1, AttendanceStatus.absent),
        _row(2, AttendanceStatus.absent),
        _row(3, AttendanceStatus.present),
      ]);
      expect(back.currentAbsenceRun, 0, reason: 'they came back');
      expect(back.longestAbsenceRun, 2);
    });

    test('absent dates come back newest first', () {
      final h = _history([
        _row(2, AttendanceStatus.absent),
        _row(9, AttendanceStatus.absent),
        _row(5, AttendanceStatus.present),
      ]);
      expect(h.absentDates.map((d) => d.day).toList(), [9, 2]);
    });

    test('the warning threshold is the school\'s, not ours', () {
      final h = _history([
        _row(1, AttendanceStatus.present),
        _row(2, AttendanceStatus.absent),
      ]);
      expect(h.ratePercent, 50);
      expect(h.isBelow(85), isTrue);
      expect(h.isBelow(40), isFalse);
      expect(_history(const []).isBelow(85), isFalse,
          reason: 'no record is not a low record');
    });

    test('months come back in order with their own totals', () {
      final h = AttendanceHistory.fromRows(
        rows: [
          Attendance(
              id: 'x1',
              studentId: 's1',
              classroomId: 'c1',
              periodId: 'homeroom',
              date: DateTime(2026, 8, 20),
              status: AttendanceStatus.absent,
              markedBy: 't'),
          _row(3, AttendanceStatus.present),
          _row(4, AttendanceStatus.absent),
        ],
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 9, 30),
      );

      expect(h.months.length, 2);
      expect(h.months.first.label, 'August 2026');
      expect(h.months.first.absent, 1);
      expect(h.months.last.shortLabel, 'Sep');
      expect(h.months.last.absentDayNumbers, {4});
      expect(h.months.last.presentDayNumbers, {3});
      expect(h.months.last.ratePercent, 50);
    });
  });

  group('AttendanceHistory.fromStaffRows', () {
    test('staff rows have no period and are whole days', () {
      final h = AttendanceHistory.fromStaffRows(
        rows: [
          (date: DateTime(2026, 9, 1), status: AttendanceStatus.present),
          (date: DateTime(2026, 9, 2), status: AttendanceStatus.absent),
          (date: DateTime(2026, 9, 2, 15), status: AttendanceStatus.present),
        ],
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );
      expect(h.recorded, 2);
      expect(h.present, 2, reason: 'the later row for the 2nd corrected it');
      expect(h.ratePercent, 100);
    });
  });
}
