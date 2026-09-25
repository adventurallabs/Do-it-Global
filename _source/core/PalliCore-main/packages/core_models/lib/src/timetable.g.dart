// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timetable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Timetable _$TimetableFromJson(Map<String, dynamic> json) => Timetable(
  id: json['id'] as String,
  classroomId: json['classroom_id'] as String,
  name: json['name'] as String,
  isActive: json['is_active'] as bool,
  periods: (json['periods'] as List<dynamic>)
      .map((e) => Period.fromJson(e as Map<String, dynamic>))
      .toList(),
  startTime: json['start_time'] as String? ?? "08:30",
  endTime: json['end_time'] as String? ?? "15:30",
  intervalCount: (json['interval_count'] as num?)?.toInt() ?? 11,
);

Map<String, dynamic> _$TimetableToJson(Timetable instance) => <String, dynamic>{
  'id': instance.id,
  'classroom_id': instance.classroomId,
  'name': instance.name,
  'is_active': instance.isActive,
  'periods': instance.periods,
  'start_time': instance.startTime,
  'end_time': instance.endTime,
  'interval_count': instance.intervalCount,
};
