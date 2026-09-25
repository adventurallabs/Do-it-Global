// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Attendance _$AttendanceFromJson(Map<String, dynamic> json) => Attendance(
  id: json['id'] as String,
  studentId: json['student_id'] as String,
  classroomId: json['classroom_id'] as String? ?? '',
  periodId: json['period_id'] as String,
  date: DateTime.parse(json['date'] as String),
  status: $enumDecode(
    _$AttendanceStatusEnumMap,
    json['status'],
    unknownValue: AttendanceStatus.od,
  ),
  markedBy: json['marked_by'] as String,
);

Map<String, dynamic> _$AttendanceToJson(Attendance instance) =>
    <String, dynamic>{
      'id': instance.id,
      'student_id': instance.studentId,
      'classroom_id': instance.classroomId,
      'period_id': instance.periodId,
      'date': instance.date.toIso8601String(),
      'status': _$AttendanceStatusEnumMap[instance.status]!,
      'marked_by': instance.markedBy,
    };

const _$AttendanceStatusEnumMap = {
  AttendanceStatus.present: 'present',
  AttendanceStatus.absent: 'absent',
  AttendanceStatus.od: 'od',
  AttendanceStatus.delayed: 'delayed',
};
