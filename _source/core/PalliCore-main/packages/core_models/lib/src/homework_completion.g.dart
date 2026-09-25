// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'homework_completion.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HomeworkCompletion _$HomeworkCompletionFromJson(Map<String, dynamic> json) =>
    HomeworkCompletion(
      homeworkId: json['homework_id'] as String,
      studentId: json['student_id'] as String,
      status:
          $enumDecodeNullable(
            _$HomeworkCompletionStatusEnumMap,
            json['status'],
            unknownValue: HomeworkCompletionStatus.pending,
          ) ??
          HomeworkCompletionStatus.pending,
      submittedAt: json['submitted_at'] == null
          ? null
          : DateTime.parse(json['submitted_at'] as String),
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
    );

Map<String, dynamic> _$HomeworkCompletionToJson(HomeworkCompletion instance) =>
    <String, dynamic>{
      'homework_id': instance.homeworkId,
      'student_id': instance.studentId,
      'status': _$HomeworkCompletionStatusEnumMap[instance.status]!,
      'submitted_at': instance.submittedAt?.toIso8601String(),
      'reviewed_by': instance.reviewedBy,
      'reviewed_at': instance.reviewedAt?.toIso8601String(),
    };

const _$HomeworkCompletionStatusEnumMap = {
  HomeworkCompletionStatus.pending: 'pending',
  HomeworkCompletionStatus.underReview: 'under_review',
  HomeworkCompletionStatus.completed: 'completed',
};
