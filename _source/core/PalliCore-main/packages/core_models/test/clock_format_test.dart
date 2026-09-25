import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Both apps show clock times as 12-hour. Timetables are stored as "HH:mm",
/// so every screen that prints one goes through [Schedule.format12] — the
/// teacher dashboard used to print the stored value straight out.
void main() {
  group('Schedule.format12', () {
    test('renders a school day in 12-hour time', () {
      expect(Schedule.format12('08:30'), '8:30 AM');
      expect(Schedule.format12('09:00'), '9:00 AM');
      expect(Schedule.format12('13:45'), '1:45 PM');
      expect(Schedule.format12('15:30'), '3:30 PM');
    });

    test('noon and midnight are 12, not 0', () {
      expect(Schedule.format12('12:00'), '12:00 PM');
      expect(Schedule.format12('00:00'), '12:00 AM');
      expect(Schedule.format12('12:59'), '12:59 PM');
    });

    test('minutes keep their leading zero', () {
      expect(Schedule.format12('10:05'), '10:05 AM');
    });

    test('a period reads as a 12-hour range', () {
      final p = Period(
        id: 'p1',
        name: 'Maths',
        staffId: 't1',
        startTime: '13:15',
        durationMinutes: 45,
        dayOfWeek: 'Monday',
      );
      expect(Schedule.range(p), '1:15 PM – 2:00 PM');
    });
  });
}
