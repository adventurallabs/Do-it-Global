// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClassLog _$ClassLogFromJson(Map<String, dynamic> json) => ClassLog(
  id: json['id'] as String,
  periodId: json['period_id'] as String,
  staffId: json['staff_id'] as String,
  startTime: DateTime.parse(json['start_time'] as String),
  status: json['status'] as String,
);

Map<String, dynamic> _$ClassLogToJson(ClassLog instance) => <String, dynamic>{
  'id': instance.id,
  'period_id': instance.periodId,
  'staff_id': instance.staffId,
  'start_time': instance.startTime.toIso8601String(),
  'status': instance.status,
};
