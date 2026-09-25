// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'star_point.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarPoint _$StarPointFromJson(Map<String, dynamic> json) => StarPoint(
  id: json['id'] as String,
  studentId: json['student_id'] as String,
  classroomId: json['classroom_id'] as String?,
  points: (json['points'] as num?)?.toInt() ?? 1,
  reason: json['reason'] as String,
  batchId: json['batch_id'] as String?,
  awardedBy: json['awarded_by'] as String,
  awardedByName: json['awarded_by_name'] as String? ?? '',
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$StarPointToJson(StarPoint instance) => <String, dynamic>{
  'id': instance.id,
  'student_id': instance.studentId,
  'classroom_id': instance.classroomId,
  'points': instance.points,
  'reason': instance.reason,
  'batch_id': instance.batchId,
  'awarded_by': instance.awardedBy,
  'awarded_by_name': instance.awardedByName,
};
