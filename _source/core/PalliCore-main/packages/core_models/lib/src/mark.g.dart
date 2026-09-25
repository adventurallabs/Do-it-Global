// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mark.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Mark _$MarkFromJson(Map<String, dynamic> json) => Mark(
  id: json['id'] as String,
  studentId: json['student_id'] as String,
  subject: json['subject'] as String,
  score: (json['score'] as num).toDouble(),
  totalMarks: (json['total_marks'] as num).toDouble(),
  testType: json['test_type'] as String,
  date: DateTime.parse(json['date'] as String),
  updatedBy: json['updated_by'] as String,
  examId: json['exam_id'] as String? ?? '',
  paperId: json['paper_id'] as String?,
  classroomId: json['classroom_id'] as String? ?? '',
  isAbsent: json['is_absent'] as bool? ?? false,
  grade: json['grade'] as String?,
);

Map<String, dynamic> _$MarkToJson(Mark instance) => <String, dynamic>{
  'id': instance.id,
  'student_id': instance.studentId,
  'subject': instance.subject,
  'score': instance.score,
  'total_marks': instance.totalMarks,
  'test_type': instance.testType,
  'date': instance.date.toIso8601String(),
  'updated_by': instance.updatedBy,
  'exam_id': instance.examId,
  'paper_id': instance.paperId,
  'classroom_id': instance.classroomId,
  'is_absent': instance.isAbsent,
  'grade': instance.grade,
};
