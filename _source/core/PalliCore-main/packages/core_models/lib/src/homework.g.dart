// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'homework.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Homework _$HomeworkFromJson(Map<String, dynamic> json) => Homework(
  id: json['id'] as String,
  classroomId: json['classroom_id'] as String,
  subject: json['subject'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  dueDate: DateTime.parse(json['due_date'] as String),
  createdBy: json['created_by'] as String,
  studentId: json['student_id'] as String?,
  attachmentUrl: json['attachment_url'] as String?,
  attachmentName: json['attachment_name'] as String?,
);

Map<String, dynamic> _$HomeworkToJson(Homework instance) => <String, dynamic>{
  'id': instance.id,
  'classroom_id': instance.classroomId,
  'subject': instance.subject,
  'title': instance.title,
  'description': instance.description,
  'due_date': instance.dueDate.toIso8601String(),
  'created_by': instance.createdBy,
  'student_id': instance.studentId,
  'attachment_url': instance.attachmentUrl,
  'attachment_name': instance.attachmentName,
};
