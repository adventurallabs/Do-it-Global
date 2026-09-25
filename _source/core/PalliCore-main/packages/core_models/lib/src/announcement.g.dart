// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Announcement _$AnnouncementFromJson(Map<String, dynamic> json) => Announcement(
  id: json['id'] as String,
  title: json['title'] as String,
  content: json['content'] as String,
  target: $enumDecode(_$AnnouncementTargetEnumMap, json['target']),
  scope:
      $enumDecodeNullable(
        _$AnnouncementScopeEnumMap,
        json['scope'],
        unknownValue: AnnouncementScope.school,
      ) ??
      AnnouncementScope.school,
  classroomId: json['classroom_id'] as String?,
  isImportant: json['is_important'] as bool? ?? false,
  createdBy: json['created_by'] as String? ?? '',
  createdAt: DateTime.parse(json['created_at'] as String),
  expiresAt: DateTime.parse(json['expires_at'] as String),
);

Map<String, dynamic> _$AnnouncementToJson(Announcement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'content': instance.content,
      'target': _$AnnouncementTargetEnumMap[instance.target]!,
      'scope': _$AnnouncementScopeEnumMap[instance.scope]!,
      'classroom_id': instance.classroomId,
      'is_important': instance.isImportant,
      'created_by': instance.createdBy,
      'created_at': instance.createdAt.toIso8601String(),
      'expires_at': instance.expiresAt.toIso8601String(),
    };

const _$AnnouncementTargetEnumMap = {
  AnnouncementTarget.teachers: 'teachers',
  AnnouncementTarget.students: 'students',
  AnnouncementTarget.overall: 'overall',
  AnnouncementTarget.parents: 'parents',
};

const _$AnnouncementScopeEnumMap = {
  AnnouncementScope.school: 'school',
  AnnouncementScope.classroom: 'classroom',
};
