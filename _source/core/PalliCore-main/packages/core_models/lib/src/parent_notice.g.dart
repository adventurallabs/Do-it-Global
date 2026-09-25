// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parent_notice.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ParentNotice _$ParentNoticeFromJson(Map<String, dynamic> json) => ParentNotice(
  id: json['id'] as String,
  eventId: json['event_id'] as String,
  studentId: json['student_id'] as String,
  studentName: json['student_name'] as String,
  guardianName: json['guardian_name'] as String,
  contactNumber: json['contact_number'] as String,
  title: json['title'] as String,
  body: json['body'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$ParentNoticeToJson(ParentNotice instance) =>
    <String, dynamic>{
      'id': instance.id,
      'event_id': instance.eventId,
      'student_id': instance.studentId,
      'student_name': instance.studentName,
      'guardian_name': instance.guardianName,
      'contact_number': instance.contactNumber,
      'title': instance.title,
      'body': instance.body,
      'created_at': instance.createdAt.toIso8601String(),
    };
