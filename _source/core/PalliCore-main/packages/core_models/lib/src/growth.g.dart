// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'growth.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GrowthObservation _$GrowthObservationFromJson(Map<String, dynamic> json) =>
    GrowthObservation(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      classroomId: json['classroom_id'] as String?,
      title: json['title'] as String? ?? 'Note',
      body: json['body'] as String,
      source: json['source'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      createdBy: json['created_by'] as String? ?? '',
      tone:
          $enumDecodeNullable(
            _$ObservationToneEnumMap,
            json['tone'],
            unknownValue: ObservationTone.neutral,
          ) ??
          ObservationTone.positive,
      category: json['category'] as String? ?? '',
      batchId: json['batch_id'] as String?,
    );

Map<String, dynamic> _$GrowthObservationToJson(GrowthObservation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'student_id': instance.studentId,
      'classroom_id': instance.classroomId,
      'title': instance.title,
      'body': instance.body,
      'source': instance.source,
      'date': instance.date.toIso8601String(),
      'created_by': instance.createdBy,
      'tone': _$ObservationToneEnumMap[instance.tone]!,
      'category': instance.category,
      'batch_id': instance.batchId,
    };

const _$ObservationToneEnumMap = {
  ObservationTone.positive: 'positive',
  ObservationTone.neutral: 'neutral',
  ObservationTone.attention: 'attention',
};

GrowthSkill _$GrowthSkillFromJson(Map<String, dynamic> json) => GrowthSkill(
  id: json['id'] as String,
  studentId: json['student_id'] as String,
  classroomId: json['classroom_id'] as String?,
  name: json['name'] as String,
  level: json['level'] as String? ?? '',
  framework: json['framework'] as String? ?? '',
  category: json['category'] as String? ?? '',
  rating: (json['rating'] as num?)?.toDouble(),
  ratedBy: json['rated_by'] as String? ?? '',
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$GrowthSkillToJson(GrowthSkill instance) =>
    <String, dynamic>{
      'id': instance.id,
      'student_id': instance.studentId,
      'classroom_id': instance.classroomId,
      'name': instance.name,
      'level': instance.level,
      'framework': instance.framework,
      'category': instance.category,
      'rating': instance.rating,
      'rated_by': instance.ratedBy,
    };
