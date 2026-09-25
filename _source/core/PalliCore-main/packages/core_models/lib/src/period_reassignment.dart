import 'package:json_annotation/json_annotation.dart';

part 'period_reassignment.g.dart';

enum PeriodReassignmentStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('accepted')
  accepted,
  @JsonValue('rejected')
  rejected,
}

/// A teacher asking another to cover one of their periods for a single day.
@JsonSerializable(fieldRename: FieldRename.snake)
class PeriodReassignment {
  final String id;
  final String timetableId;
  final String periodId;
  final String classroomId;
  final String dayOfWeek;
  final DateTime periodDate;
  final String periodName;
  final String startTime;
  final int durationMinutes;
  final String fromStaffId;
  final String toStaffId;
  @JsonKey(defaultValue: PeriodReassignmentStatus.pending, unknownEnumValue: PeriodReassignmentStatus.pending)
  final PeriodReassignmentStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  PeriodReassignment({
    required this.id,
    required this.timetableId,
    required this.periodId,
    required this.classroomId,
    required this.dayOfWeek,
    required this.periodDate,
    required this.periodName,
    required this.startTime,
    required this.durationMinutes,
    required this.fromStaffId,
    required this.toStaffId,
    this.status = PeriodReassignmentStatus.pending,
    required this.createdAt,
    this.respondedAt,
  });

  PeriodReassignment copyWith({
    PeriodReassignmentStatus? status,
    DateTime? respondedAt,
  }) {
    return PeriodReassignment(
      id: id,
      timetableId: timetableId,
      periodId: periodId,
      classroomId: classroomId,
      dayOfWeek: dayOfWeek,
      periodDate: periodDate,
      periodName: periodName,
      startTime: startTime,
      durationMinutes: durationMinutes,
      fromStaffId: fromStaffId,
      toStaffId: toStaffId,
      status: status ?? this.status,
      createdAt: createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  factory PeriodReassignment.fromJson(Map<String, dynamic> json) =>
      _$PeriodReassignmentFromJson(json);
  Map<String, dynamic> toJson() => _$PeriodReassignmentToJson(this);
}
