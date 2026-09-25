import 'package:json_annotation/json_annotation.dart';

part 'student_leave_request.g.dart';

enum StudentLeaveKind {
  @JsonValue('leave')
  leave,
  @JsonValue('late_info')
  lateInfo,
  @JsonValue('absent_info')
  absentInfo,
}

enum StudentLeaveStatus {
  @JsonValue('requested')
  requested,
  @JsonValue('under_review')
  underReview,
  @JsonValue('approved')
  approved,
  @JsonValue('rejected')
  rejected,
}

@JsonSerializable(fieldRename: FieldRename.snake)
class StudentLeaveRequest {
  final String id;
  final String studentId;
  @JsonKey(defaultValue: '')
  final String requestedBy;
  @JsonKey(defaultValue: StudentLeaveKind.leave, unknownEnumValue: StudentLeaveKind.leave)
  final StudentLeaveKind kind;
  final DateTime fromDate;
  final DateTime? toDate;
  final String reason;
  @JsonKey(defaultValue: StudentLeaveStatus.requested, unknownEnumValue: StudentLeaveStatus.requested)
  final StudentLeaveStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final DateTime createdAt;

  StudentLeaveRequest({
    required this.id,
    required this.studentId,
    this.requestedBy = '',
    this.kind = StudentLeaveKind.leave,
    required this.fromDate,
    this.toDate,
    required this.reason,
    this.status = StudentLeaveStatus.requested,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote,
    required this.createdAt,
  });

  int get durationDays =>
      (toDate ?? fromDate).difference(fromDate).inDays + 1;

  StudentLeaveRequest copyWith({
    StudentLeaveStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? reviewNote,
  }) {
    return StudentLeaveRequest(
      id: id,
      studentId: studentId,
      requestedBy: requestedBy,
      kind: kind,
      fromDate: fromDate,
      toDate: toDate,
      reason: reason,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNote: reviewNote ?? this.reviewNote,
      createdAt: createdAt,
    );
  }

  factory StudentLeaveRequest.fromJson(Map<String, dynamic> json) =>
      _$StudentLeaveRequestFromJson(json);
  Map<String, dynamic> toJson() => _$StudentLeaveRequestToJson(this);
}
