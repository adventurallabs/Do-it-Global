// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Exam _$ExamFromJson(Map<String, dynamic> json) => Exam(
  id: json['id'] as String,
  name: json['name'] as String,
  academicYearId: json['academic_year_id'] as String,
  examGroup: json['exam_group'] as String?,
  startDate: DateTime.parse(json['start_date'] as String),
  endDate: DateTime.parse(json['end_date'] as String),
  gradeKeys:
      (json['grade_keys'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  classroomIds:
      (json['classroom_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  subjects:
      (json['subjects'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  totalMarks: (json['total_marks'] as num?)?.toDouble() ?? 100,
  createdBy: json['created_by'] as String?,
  resultMode:
      $enumDecodeNullable(
        _$ExamResultModeEnumMap,
        json['result_mode'],
        unknownValue: ExamResultMode.marks,
      ) ??
      ExamResultMode.marks,
  gradeScale: json['grade_scale'] == null
      ? const []
      : _bandsFromJson(json['grade_scale']),
);

Map<String, dynamic> _$ExamToJson(Exam instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'academic_year_id': instance.academicYearId,
  'exam_group': instance.examGroup,
  'start_date': instance.startDate.toIso8601String(),
  'end_date': instance.endDate.toIso8601String(),
  'grade_keys': instance.gradeKeys,
  'classroom_ids': instance.classroomIds,
  'subjects': instance.subjects,
  'total_marks': instance.totalMarks,
  'created_by': instance.createdBy,
  'result_mode': _$ExamResultModeEnumMap[instance.resultMode]!,
  'grade_scale': _bandsToJson(instance.gradeScale),
};

const _$ExamResultModeEnumMap = {
  ExamResultMode.marks: 'marks',
  ExamResultMode.grades: 'grades',
  ExamResultMode.marksAndGrades: 'marks_grades',
};
