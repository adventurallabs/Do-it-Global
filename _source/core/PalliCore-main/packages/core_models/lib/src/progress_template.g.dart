// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_template.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProgressTemplate _$ProgressTemplateFromJson(Map<String, dynamic> json) =>
    ProgressTemplate(
      id: json['id'] as String,
      kind: $enumDecode(_$ProgressKindEnumMap, json['kind']),
      title: json['title'] as String,
      category: json['category'] as String? ?? '',
      body: json['body'] as String? ?? '',
      tone:
          $enumDecodeNullable(
            _$ObservationToneEnumMap,
            json['tone'],
            unknownValue: ObservationTone.neutral,
          ) ??
          ObservationTone.positive,
      createdBy: json['created_by'] as String? ?? '',
    );

Map<String, dynamic> _$ProgressTemplateToJson(ProgressTemplate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': _$ProgressKindEnumMap[instance.kind]!,
      'title': instance.title,
      'category': instance.category,
      'body': instance.body,
      'tone': _$ObservationToneEnumMap[instance.tone]!,
      'created_by': instance.createdBy,
    };

const _$ProgressKindEnumMap = {
  ProgressKind.star: 'star',
  ProgressKind.activity: 'activity',
  ProgressKind.observation: 'observation',
  ProgressKind.skill: 'skill',
};

const _$ObservationToneEnumMap = {
  ObservationTone.positive: 'positive',
  ObservationTone.neutral: 'neutral',
  ObservationTone.attention: 'attention',
};
