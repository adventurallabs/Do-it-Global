// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class_day_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LearningItem _$LearningItemFromJson(Map<String, dynamic> json) => LearningItem(
  subject: json['subject'] as String,
  topic: json['topic'] as String,
);

Map<String, dynamic> _$LearningItemToJson(LearningItem instance) =>
    <String, dynamic>{'subject': instance.subject, 'topic': instance.topic};

GrowthSignal _$GrowthSignalFromJson(Map<String, dynamic> json) => GrowthSignal(
  name: json['name'] as String,
  indicator: json['indicator'] as String? ?? '↑',
);

Map<String, dynamic> _$GrowthSignalToJson(GrowthSignal instance) =>
    <String, dynamic>{'name': instance.name, 'indicator': instance.indicator};

ClassDaySummary _$ClassDaySummaryFromJson(Map<String, dynamic> json) =>
    ClassDaySummary(
      id: json['id'] as String,
      classroomId: json['classroom_id'] as String,
      summaryDate: DateTime.parse(json['summary_date'] as String),
      teacherNote: json['teacher_note'] as String? ?? '',
      learning:
          (json['learning'] as List<dynamic>?)
              ?.map((e) => LearningItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      growthSignals:
          (json['growth_signals'] as List<dynamic>?)
              ?.map((e) => GrowthSignal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdBy: json['created_by'] as String? ?? '',
    );

Map<String, dynamic> _$ClassDaySummaryToJson(ClassDaySummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'classroom_id': instance.classroomId,
      'summary_date': instance.summaryDate.toIso8601String(),
      'teacher_note': instance.teacherNote,
      'learning': instance.learning.map((e) => e.toJson()).toList(),
      'growth_signals': instance.growthSignals.map((e) => e.toJson()).toList(),
      'created_by': instance.createdBy,
    };
