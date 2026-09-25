// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_leave_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StudentLeaveRequest _$StudentLeaveRequestFromJson(Map<String, dynamic> json) =>
    StudentLeaveRequest(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      requestedBy: json['requested_by'] as String? ?? '',
      kind:
          $enumDecodeNullable(
            _$StudentLeaveKindEnumMap,
            json['kind'],
            unknownValue: StudentLeaveKind.leave,
          ) ??
          StudentLeaveKind.leave,
      fromDate: DateTime.parse(json['from_date'] as String),
      toDate: json['to_date'] == null
          ? null
          : DateTime.parse(json['to_date'] as String),
      reason: json['reason'] as String,
      status:
          $enumDecodeNullable(
            _$StudentLeaveStatusEnumMap,
            json['status'],
            unknownValue: StudentLeaveStatus.requested,
          ) ??
          StudentLeaveStatus.requested,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
      reviewNote: json['review_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$StudentLeaveRequestToJson(
  StudentLeaveRequest instance,
) => <String, dynamic>{
  'id': instance.id,
  'student_id': instance.studentId,
  'requested_by': instance.requestedBy,
  'kind': _$StudentLeaveKindEnumMap[instance.kind]!,
  'from_date': instance.fromDate.toIso8601String(),
  'to_date': instance.toDate?.toIso8601String(),
  'reason': instance.reason,
  'status': _$StudentLeaveStatusEnumMap[instance.status]!,
  'reviewed_by': instance.reviewedBy,
  'reviewed_at': instance.reviewedAt?.toIso8601String(),
  'review_note': instance.reviewNote,
  'created_at': instance.createdAt.toIso8601String(),
};

const _$StudentLeaveKindEnumMap = {
  StudentLeaveKind.leave: 'leave',
  StudentLeaveKind.lateInfo: 'late_info',
  StudentLeaveKind.absentInfo: 'absent_info',
};

const _$StudentLeaveStatusEnumMap = {
  StudentLeaveStatus.requested: 'requested',
  StudentLeaveStatus.underReview: 'under_review',
  StudentLeaveStatus.approved: 'approved',
  StudentLeaveStatus.rejected: 'rejected',
};
