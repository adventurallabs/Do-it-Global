import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArchivePolicy', () {
    test('the window is 30 days from the day they left', () {
      final left = DateTime(2026, 9, 21, 14, 30);
      expect(ArchivePolicy.purgeDateFor(left), DateTime(2026, 10, 21, 14, 30));
    });

    test('counts whole days, ignoring the time of day', () {
      final purge = DateTime(2026, 10, 21, 2, 0);
      // Late on the 20th is still "tomorrow", not "in 0 days".
      expect(ArchivePolicy.daysLeft(purge, now: DateTime(2026, 10, 20, 23, 59)), 1);
      expect(ArchivePolicy.daysLeft(purge, now: DateTime(2026, 10, 21, 0, 1)), 0);
      expect(ArchivePolicy.daysLeft(purge, now: DateTime(2026, 10, 23)), -2);
    });
  });

  group('ExitRecord', () {
    ExitRecord record(DateTime at) => ExitRecord.starting(ExitReason.discontinued, at: at);

    test('starting sets the clock from the exit date', () {
      final r = record(DateTime(2026, 9, 21));
      expect(r.purgeAfter, DateTime(2026, 10, 21));
      expect(r.reason, ExitReason.discontinued);
    });

    test('reads the countdown the same way on every screen', () {
      final r = record(DateTime(2026, 9, 21));
      expect(r.countdownLabel(now: DateTime(2026, 9, 21)), 'Erased in 30 days');
      expect(r.countdownLabel(now: DateTime(2026, 10, 20)), 'Erased tomorrow');
      expect(r.countdownLabel(now: DateTime(2026, 10, 21)), 'Erased tonight');
      expect(r.countdownLabel(now: DateTime(2026, 10, 25)), 'Overdue for erasing');
    });

    test('is due once the window closes, and urgent in the last week', () {
      final r = record(DateTime(2026, 9, 21));
      expect(r.isDue(now: DateTime(2026, 10, 20)), isFalse);
      expect(r.isDue(now: DateTime(2026, 10, 21)), isTrue);
      expect(r.isUrgent(now: DateTime(2026, 10, 13)), isFalse);
      expect(r.isUrgent(now: DateTime(2026, 10, 14)), isTrue);
    });
  });

  group('StudentLifecycle', () {
    test('only the three leaving states start the clock', () {
      expect(StudentLifecycle.enrolled.hasLeft, isFalse);
      expect(StudentLifecycle.retained.hasLeft, isFalse);
      expect(StudentLifecycle.graduated.hasLeft, isTrue);
      expect(StudentLifecycle.transferred.hasLeft, isTrue);
      expect(StudentLifecycle.discontinued.hasLeft, isTrue);
    });

    test('maps to the reason the archive files them under', () {
      expect(StudentLifecycle.graduated.exitReason, ExitReason.graduated);
      expect(StudentLifecycle.transferred.exitReason, ExitReason.transferred);
      expect(StudentLifecycle.discontinued.exitReason, ExitReason.discontinued);
      expect(StudentLifecycle.enrolled.exitReason, isNull);
    });

    test('graduating is kept apart from leaving early', () {
      expect(ExitReason.graduated.isGraduation, isTrue);
      expect(ExitReason.transferred.isGraduation, isFalse);
      expect(ExitReason.discontinued.isGraduation, isFalse);
    });
  });

  group('the record on a person', () {
    Student student({StudentLifecycle lifecycle = StudentLifecycle.enrolled, DateTime? exitAt}) =>
        Student(
          id: 's1',
          name: 'Meera',
          rollNumber: '4',
          fatherName: '',
          motherName: '',
          contactNumber: '',
          address: '',
          classroomId: '',
          fees: 0,
          admissionNo: 'A100',
          lifecycle: lifecycle,
          exitAt: exitAt,
        );

    test('a student on the roll has no archive entry', () {
      expect(student().exit, isNull);
      expect(student().hasLeft, isFalse);
    });

    test('a leaver carries the reason from their lifecycle', () {
      final s = student(
        lifecycle: StudentLifecycle.transferred,
        exitAt: DateTime(2026, 9, 21),
      );
      expect(s.hasLeft, isTrue);
      expect(s.exit!.reason, ExitReason.transferred);
      expect(s.exit!.purgeAfter, DateTime(2026, 10, 21));
    });

    test('a lifecycle without an exit date is not yet archived', () {
      expect(student(lifecycle: StudentLifecycle.graduated).exit, isNull);
    });

    test('staff carry their own reason, separate from their login state', () {
      final teacher = Teacher(
        id: 't1',
        name: 'Anitha',
        contactNumber: '',
        qualification: '',
        address: '',
        salary: 0,
        isActive: false,
      );
      expect(teacher.hasLeft, isFalse, reason: 'switched off is not the same as left');

      final left = teacher.copyWith(
        exitReason: ExitReason.discontinued,
        exitAt: DateTime(2026, 9, 21),
        purgeAfter: DateTime(2026, 10, 21),
      );
      expect(left.hasLeft, isTrue);
      expect(left.exit!.countdownLabel(now: DateTime(2026, 10, 14)), 'Erased in 7 days');
      expect(left.copyWith(clearExit: true).hasLeft, isFalse);
    });
  });
}
