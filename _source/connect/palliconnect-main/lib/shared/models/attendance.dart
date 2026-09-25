enum AttendanceMark { present, absent, leave, none }

class AttendanceSummary {
  final int present;
  final int absent;
  final int leave;
  final int percent;
  final int warningThreshold;
  final Map<DateTime, AttendanceMark> days;

  const AttendanceSummary({
    required this.present,
    required this.absent,
    required this.leave,
    required this.percent,
    required this.warningThreshold,
    required this.days,
  });

  bool get needsAttention => percent < warningThreshold;
}
