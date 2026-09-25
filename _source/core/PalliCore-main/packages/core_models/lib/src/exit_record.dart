import 'package:json_annotation/json_annotation.dart';

/// Why someone left the school.
///
/// A person who has left is not the same as a person who is switched off:
/// deactivating suspends a login, leaving ends the relationship. Only the
/// latter starts the retention clock.
enum ExitReason {
  /// Staff who stopped working here, or a child withdrawn mid-year.
  @JsonValue('discontinued')
  discontinued,

  /// A child who moved to another school.
  @JsonValue('transferred')
  transferred,

  /// A child who finished their final year here.
  @JsonValue('graduated')
  graduated,
}

extension ExitReasonLabel on ExitReason {
  String get label => switch (this) {
        ExitReason.discontinued => 'Discontinued',
        ExitReason.transferred => 'Transferred out',
        ExitReason.graduated => 'Graduated',
      };

  String get verb => switch (this) {
        ExitReason.discontinued => 'discontinued',
        ExitReason.transferred => 'transferred out',
        ExitReason.graduated => 'graduated',
      };

  /// Graduates are kept apart from the two "left early" reasons — finishing
  /// school is not the same event, and an admin should never scan one list
  /// looking for the other.
  bool get isGraduation => this == ExitReason.graduated;
}

/// How long a record stays readable after the person leaves, and what that
/// window is for.
class ArchivePolicy {
  ArchivePolicy._();

  /// The school keeps a leaver's file for a month so it can be exported, then
  /// the record is erased for good.
  static const retention = Duration(days: 30);

  static DateTime purgeDateFor(DateTime exitAt) => exitAt.add(retention);

  /// Whole days left before the record is erased — 0 on the last day, and
  /// negative once it is overdue for the nightly purge.
  static int daysLeft(DateTime purgeAfter, {DateTime? now}) {
    final today = _midnight(now ?? DateTime.now());
    final due = _midnight(purgeAfter);
    return due.difference(today).inDays;
  }

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// The archive entry for one person who has left: why, when, and how long
/// their file survives.
class ExitRecord {
  final ExitReason reason;
  final DateTime at;
  final DateTime purgeAfter;

  /// Optional free text the admin typed — which school they moved to, why
  /// the contract ended.
  final String note;

  const ExitRecord({
    required this.reason,
    required this.at,
    required this.purgeAfter,
    this.note = '',
  });

  /// Builds the record for someone leaving now, with the retention clock set.
  factory ExitRecord.starting(ExitReason reason, {DateTime? at, String note = ''}) {
    final when = at ?? DateTime.now();
    return ExitRecord(
      reason: reason,
      at: when,
      purgeAfter: ArchivePolicy.purgeDateFor(when),
      note: note,
    );
  }

  int daysLeft({DateTime? now}) => ArchivePolicy.daysLeft(purgeAfter, now: now);

  /// True once the nightly purge is entitled to erase this record.
  bool isDue({DateTime? now}) => daysLeft(now: now) <= 0;

  /// "Erased in 12 days" / "Erased tonight" / "Overdue for erasing" — one
  /// phrase, so the countdown reads the same on every screen.
  String countdownLabel({DateTime? now}) {
    final left = daysLeft(now: now);
    if (left < 0) return 'Overdue for erasing';
    if (left == 0) return 'Erased tonight';
    if (left == 1) return 'Erased tomorrow';
    return 'Erased in $left days';
  }

  /// Warn the admin once the window is nearly gone and the export has still
  /// not been taken.
  bool isUrgent({DateTime? now}) => daysLeft(now: now) <= 7;
}
