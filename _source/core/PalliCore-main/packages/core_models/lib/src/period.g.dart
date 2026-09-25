// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'period.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Period _$PeriodFromJson(Map<String, dynamic> json) => Period(
  id: json['id'] as String,
  name: json['name'] as String,
  staffId: json['staff_id'] as String,
  startTime: json['start_time'] as String,
  durationMinutes: (json['duration_minutes'] as num).toInt(),
  dayOfWeek: json['day_of_week'] as String,
  isTemporary: json['is_temporary'] as bool? ?? false,
  date: json['date'] == null ? null : DateTime.parse(json['date'] as String),
);

Map<String, dynamic> _$PeriodToJson(Period instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'staff_id': instance.staffId,
  'start_time': instance.startTime,
  'duration_minutes': instance.durationMinutes,
  'day_of_week': instance.dayOfWeek,
  'is_temporary': instance.isTemporary,
  'date': instance.date?.toIso8601String(),
};
