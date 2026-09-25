// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'period_reassignment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PeriodReassignment _$PeriodReassignmentFromJson(Map<String, dynamic> json) =>
    PeriodReassignment(
      id: json['id'] as String,
      timetableId: json['timetable_id'] as String,
      periodId: json['period_id'] as String,
      classroomId: json['classroom_id'] as String,
      dayOfWeek: json['day_of_week'] as String,
      periodDate: DateTime.parse(json['period_date'] as String),
      periodName: json['period_name'] as String,
      startTime: json['start_time'] as String,
      durationMinutes: (json['duration_minutes'] as num).toInt(),
      fromStaffId: json['from_staff_id'] as String,
      toStaffId: json['to_staff_id'] as String,
      status:
          $enumDecodeNullable(
            _$PeriodReassignmentStatusEnumMap,
            json['status'],
            unknownValue: PeriodReassignmentStatus.pending,
          ) ??
          PeriodReassignmentStatus.pending,
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] == null
          ? null
          : DateTime.parse(json['responded_at'] as String),
    );

Map<String, dynamic> _$PeriodReassignmentToJson(PeriodReassignment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timetable_id': instance.timetableId,
      'period_id': instance.periodId,
      'classroom_id': instance.classroomId,
      'day_of_week': instance.dayOfWeek,
      'period_date': instance.periodDate.toIso8601String(),
      'period_name': instance.periodName,
      'start_time': instance.startTime,
      'duration_minutes': instance.durationMinutes,
      'from_staff_id': instance.fromStaffId,
      'to_staff_id': instance.toStaffId,
      'status': _$PeriodReassignmentStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt.toIso8601String(),
      'responded_at': instance.respondedAt?.toIso8601String(),
    };

const _$PeriodReassignmentStatusEnumMap = {
  PeriodReassignmentStatus.pending: 'pending',
  PeriodReassignmentStatus.accepted: 'accepted',
  PeriodReassignmentStatus.rejected: 'rejected',
};
