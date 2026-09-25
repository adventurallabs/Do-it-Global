// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_timetable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExamSchedule _$ExamScheduleFromJson(Map<String, dynamic> json) => ExamSchedule(
  examId: json['exam_id'] as String,
  gradeKey: json['grade_key'] as String,
  status:
      $enumDecodeNullable(
        _$ExamScheduleStatusEnumMap,
        json['status'],
        unknownValue: ExamScheduleStatus.draft,
      ) ??
      ExamScheduleStatus.draft,
  publishedAt: json['published_at'] == null
      ? null
      : DateTime.parse(json['published_at'] as String),
  firstDate: _dateFromJsonOrNull(json['first_date']),
  lastDate: _dateFromJsonOrNull(json['last_date']),
  paperCount: (json['paper_count'] as num?)?.toInt() ?? 0,
  hasChanges: json['has_changes'] as bool? ?? false,
);

const _$ExamScheduleStatusEnumMap = {
  ExamScheduleStatus.draft: 'draft',
  ExamScheduleStatus.published: 'published',
};

ExamPaper _$ExamPaperFromJson(Map<String, dynamic> json) => ExamPaper(
  id: json['id'] as String,
  examId: json['exam_id'] as String,
  gradeKey: json['grade_key'] as String,
  subject: json['subject'] as String,
  examDate: _dateFromJson(json['exam_date']),
  startTime: json['start_time'] as String,
  endTime: json['end_time'] as String,
  syllabus: json['syllabus'] as String? ?? '',
  maxMarks: (json['max_marks'] as num?)?.toDouble() ?? 100,
  passMarks: (json['pass_marks'] as num?)?.toDouble() ?? 35,
);

Map<String, dynamic> _$ExamPaperToJson(ExamPaper instance) => <String, dynamic>{
  'id': instance.id,
  'exam_id': instance.examId,
  'grade_key': instance.gradeKey,
  'subject': instance.subject,
  'exam_date': _dateToJson(instance.examDate),
  'start_time': instance.startTime,
  'end_time': instance.endTime,
  'syllabus': instance.syllabus,
  'max_marks': instance.maxMarks,
  'pass_marks': instance.passMarks,
};

ExamMarkSheet _$ExamMarkSheetFromJson(Map<String, dynamic> json) =>
    ExamMarkSheet(
      paperId: json['paper_id'] as String,
      classroomId: json['classroom_id'] as String,
      examId: json['exam_id'] as String,
      subject: json['subject'] as String,
      status:
          $enumDecodeNullable(
            _$ExamSheetStatusEnumMap,
            json['status'],
            unknownValue: ExamSheetStatus.draft,
          ) ??
          ExamSheetStatus.draft,
      enteredCount: (json['entered_count'] as num?)?.toInt() ?? 0,
      teacherId: json['teacher_id'] as String? ?? '',
      submittedAt: json['submitted_at'] == null
          ? null
          : DateTime.parse(json['submitted_at'] as String),
      submittedBy: json['submitted_by'] as String?,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

const _$ExamSheetStatusEnumMap = {
  ExamSheetStatus.draft: 'draft',
  ExamSheetStatus.submitted: 'submitted',
};
