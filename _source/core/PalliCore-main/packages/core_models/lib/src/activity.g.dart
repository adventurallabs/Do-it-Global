// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Activity _$ActivityFromJson(Map<String, dynamic> json) => Activity(
  id: json['id'] as String,
  studentId: json['student_id'] as String,
  classroomId: json['classroom_id'] as String?,
  name: json['name'] as String,
  date: DateTime.parse(json['date'] as String),
  category: json['category'] as String? ?? '',
  achievement: json['achievement'] as String?,
  result: json['result'] as String?,
  teacherRemarks: json['teacher_remarks'] as String?,
  documentLabel: json['document_label'] as String?,
  createdBy: json['created_by'] as String? ?? '',
  batchId: json['batch_id'] as String?,
);

Map<String, dynamic> _$ActivityToJson(Activity instance) => <String, dynamic>{
  'id': instance.id,
  'student_id': instance.studentId,
  'classroom_id': instance.classroomId,
  'name': instance.name,
  'date': instance.date.toIso8601String(),
  'category': instance.category,
  'achievement': instance.achievement,
  'result': instance.result,
  'teacher_remarks': instance.teacherRemarks,
  'document_label': instance.documentLabel,
  'created_by': instance.createdBy,
  'batch_id': instance.batchId,
};
