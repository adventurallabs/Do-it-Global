// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_attendance.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffAttendance _$StaffAttendanceFromJson(Map<String, dynamic> json) =>
    StaffAttendance(
      id: json['id'] as String,
      staffId: json['staff_id'] as String,
      date: DateTime.parse(json['date'] as String),
      status: $enumDecode(
        _$AttendanceStatusEnumMap,
        json['status'],
        unknownValue: AttendanceStatus.od,
      ),
    );

Map<String, dynamic> _$StaffAttendanceToJson(StaffAttendance instance) =>
    <String, dynamic>{
      'id': instance.id,
      'staff_id': instance.staffId,
      'date': instance.date.toIso8601String(),
      'status': _$AttendanceStatusEnumMap[instance.status]!,
    };

const _$AttendanceStatusEnumMap = {
  AttendanceStatus.present: 'present',
  AttendanceStatus.absent: 'absent',
  AttendanceStatus.od: 'od',
  AttendanceStatus.delayed: 'delayed',
};
