// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventCategory _$EventCategoryFromJson(Map<String, dynamic> json) =>
    EventCategory(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      kind:
          $enumDecodeNullable(_$EventCategoryKindEnumMap, json['kind']) ??
          EventCategoryKind.competitive,
      issuesCertificates: json['issues_certificates'] as bool? ?? true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$EventCategoryToJson(EventCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'event_id': instance.eventId,
      'name': instance.name,
      'description': instance.description,
      'kind': _$EventCategoryKindEnumMap[instance.kind]!,
      'issues_certificates': instance.issuesCertificates,
      'created_at': instance.createdAt?.toIso8601String(),
    };

const _$EventCategoryKindEnumMap = {
  EventCategoryKind.competitive: 'competitive',
  EventCategoryKind.nonCompetitive: 'non_competitive',
};

EventCategoryHead _$EventCategoryHeadFromJson(Map<String, dynamic> json) =>
    EventCategoryHead(
      categoryId: json['category_id'] as String,
      teacherId: json['teacher_id'] as String,
    );

Map<String, dynamic> _$EventCategoryHeadToJson(EventCategoryHead instance) =>
    <String, dynamic>{
      'category_id': instance.categoryId,
      'teacher_id': instance.teacherId,
    };

EventParticipant _$EventParticipantFromJson(Map<String, dynamic> json) =>
    EventParticipant(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      studentId: json['student_id'] as String,
      classroomId: json['classroom_id'] as String? ?? '',
      addedBy: json['added_by'] as String?,
      selfRegistered: json['self_registered'] as bool? ?? false,
    );

Map<String, dynamic> _$EventParticipantToJson(EventParticipant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category_id': instance.categoryId,
      'student_id': instance.studentId,
      'classroom_id': instance.classroomId,
      'added_by': instance.addedBy,
      'self_registered': instance.selfRegistered,
    };
