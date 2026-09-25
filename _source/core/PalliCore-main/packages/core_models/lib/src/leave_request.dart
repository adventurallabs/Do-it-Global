import 'package:json_annotation/json_annotation.dart';

part 'leave_request.g.dart';

enum LeaveStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('approved')
  approved,
  @JsonValue('rejected')
  rejected,
}

@JsonSerializable(fieldRename: FieldRename.snake)
class LeaveCoverage {
  final String periodId;
  final String timetableId;
  final String classroomId;
  final String originalStaffId;
  final String substituteStaffId;
  final String subject;
  final String startTime;
  final String dayOfWeek;
  final DateTime date;

  LeaveCoverage({
    required this.periodId,
    required this.timetableId,
    required this.classroomId,
    required this.originalStaffId,
    required this.substituteStaffId,
    required this.subject,
    required this.startTime,
    required this.dayOfWeek,
    required this.date,
  });

  factory LeaveCoverage.fromJson(Map<String, dynamic> json) =>
      _$LeaveCoverageFromJson(json);
  Map<String, dynamic> toJson() => _$LeaveCoverageToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class LeaveRequest {
  final String id;
  final String teacherId;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final LeaveStatus status;
  final DateTime createdAt;
  final List<LeaveCoverage> coverage;

  LeaveRequest({
    required this.id,
    required this.teacherId,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.status = LeaveStatus.pending,
    required this.createdAt,
    this.coverage = const [],
  });

  LeaveRequest copyWith({
    LeaveStatus? status,
    List<LeaveCoverage>? coverage,
  }) {
    return LeaveRequest(
      id: id,
      teacherId: teacherId,
      fromDate: fromDate,
      toDate: toDate,
      reason: reason,
      status: status ?? this.status,
      createdAt: createdAt,
      coverage: coverage ?? this.coverage,
    );
  }

  factory LeaveRequest.fromJson(Map<String, dynamic> json) =>
      _$LeaveRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LeaveRequestToJson(this);
}
