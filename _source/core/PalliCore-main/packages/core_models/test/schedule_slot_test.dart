import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The blank week the admin taps into. "Periods per day" used to be recorded
/// and then ignored — the grid drew rows only for periods that already
/// existed, so a new timetable opened empty and had to be filled in one
/// period at a time.
void main() {
  group('Schedule.slotPlan', () {
    test('lays out one row per period, back to back from the first bell', () {
      final slots = Schedule.slotPlan(dayStart: '09:00', dayEnd: '15:00', count: 6);

      expect(slots.length, 6);
      expect(slots.first.startTime, '09:00');
      expect(slots.first.durationMinutes, 60);
      expect([for (final s in slots) s.startTime],
          ['09:00', '10:00', '11:00', '12:00', '13:00', '14:00']);
      expect(slots.last.endTime, '15:00');
    });

    test('never runs past the end of the school day', () {
      // 8:30–15:30 is 420 minutes; 11 periods is 38.18 each, which rounds
      // down to 35 rather than up to 40 — a class scheduled after everyone
      // has gone home is worse than a few spare minutes.
      final slots = Schedule.slotPlan(dayStart: '08:30', dayEnd: '15:30', count: 11);

      expect(slots.length, 11);
      expect(slots.first.durationMinutes, 35);
      expect(Schedule.minutesOf(slots.last.endTime),
          lessThanOrEqualTo(Schedule.minutesOf('15:30')));
    });

    test('slot times read back as 12-hour', () {
      final slots = Schedule.slotPlan(dayStart: '08:30', dayEnd: '15:30', count: 11);
      expect(slots.first.label, '8:30 AM – 9:05 AM');
    });

    test('a nonsense day yields no grid rather than a broken one', () {
      expect(Schedule.slotPlan(dayStart: '09:00', dayEnd: '09:00', count: 6), isEmpty);
      expect(Schedule.slotPlan(dayStart: '15:00', dayEnd: '09:00', count: 6), isEmpty);
      expect(Schedule.slotPlan(dayStart: '09:00', dayEnd: '15:00', count: 0), isEmpty);
    });

    test('more periods than minutes still gives every one a row', () {
      final slots = Schedule.slotPlan(dayStart: '09:00', dayEnd: '09:20', count: 12);
      expect(slots.length, 12);
      expect(slots.first.durationMinutes, 5);
    });
  });
}
