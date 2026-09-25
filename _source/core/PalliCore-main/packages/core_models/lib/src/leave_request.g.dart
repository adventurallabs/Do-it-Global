// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'leave_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LeaveCoverage _$LeaveCoverageFromJson(Map<String, dynamic> json) =>
    LeaveCoverage(
      periodId: json['period_id'] as String,
      timetableId: json['timetable_id'] as String,
      classroomId: json['classroom_id'] as String,
      originalStaffId: json['original_staff_id'] as String,
      substituteStaffId: json['substitute_staff_id'] as String,
      subject: json['subject'] as String,
      startTime: json['start_time'] as String,
      dayOfWeek: json['day_of_week'] as String,
      date: DateTime.parse(json['date'] as String),
    );

Map<String, dynamic> _$LeaveCoverageToJson(LeaveCoverage instance) =>
    <String, dynamic>{
      'period_id': instance.periodId,
      'timetable_id': instance.timetableId,
      'classroom_id': instance.classroomId,
      'original_staff_id': instance.originalStaffId,
      'substitute_staff_id': instance.substituteStaffId,
      'subject': instance.subject,
      'start_time': instance.startTime,
      'day_of_week': instance.dayOfWeek,
      'date': instance.date.toIso8601String(),
    };

LeaveRequest _$LeaveRequestFromJson(Map<String, dynamic> json) => LeaveRequest(
  id: json['id'] as String,
  teacherId: json['teacher_id'] as String,
  fromDate: DateTime.parse(json['from_date'] as String),
  toDate: DateTime.parse(json['to_date'] as String),
  reason: json['reason'] as String,
  status:
      $enumDecodeNullable(_$LeaveStatusEnumMap, json['status']) ??
      LeaveStatus.pending,
  createdAt: DateTime.parse(json['created_at'] as String),
  coverage:
      (json['coverage'] as List<dynamic>?)
          ?.map((e) => LeaveCoverage.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$LeaveRequestToJson(LeaveRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'teacher_id': instance.teacherId,
      'from_date': instance.fromDate.toIso8601String(),
      'to_date': instance.toDate.toIso8601String(),
      'reason': instance.reason,
      'status': _$LeaveStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt.toIso8601String(),
      'coverage': instance.coverage,
    };

const _$LeaveStatusEnumMap = {
  LeaveStatus.pending: 'pending',
  LeaveStatus.approved: 'approved',
  LeaveStatus.rejected: 'rejected',
};
