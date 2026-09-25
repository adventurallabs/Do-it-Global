// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_note.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DiaryNote _$DiaryNoteFromJson(Map<String, dynamic> json) => DiaryNote(
  id: json['id'] as String,
  classroomId: json['classroom_id'] as String,
  studentId: json['student_id'] as String?,
  noteDate: DateTime.parse(json['note_date'] as String),
  kind:
      $enumDecodeNullable(
        _$DiaryNoteKindEnumMap,
        json['kind'],
        unknownValue: DiaryNoteKind.note,
      ) ??
      DiaryNoteKind.note,
  title: json['title'] as String? ?? '',
  body: json['body'] as String,
  teacherName: json['teacher_name'] as String?,
  hasAttachment: json['has_attachment'] as bool? ?? false,
  attachmentUrl: json['attachment_url'] as String?,
  createdBy: json['created_by'] as String? ?? '',
);

Map<String, dynamic> _$DiaryNoteToJson(DiaryNote instance) => <String, dynamic>{
  'id': instance.id,
  'classroom_id': instance.classroomId,
  'student_id': instance.studentId,
  'note_date': instance.noteDate.toIso8601String(),
  'kind': _$DiaryNoteKindEnumMap[instance.kind]!,
  'title': instance.title,
  'body': instance.body,
  'teacher_name': instance.teacherName,
  'has_attachment': instance.hasAttachment,
  'attachment_url': instance.attachmentUrl,
  'created_by': instance.createdBy,
};

const _$DiaryNoteKindEnumMap = {
  DiaryNoteKind.note: 'note',
  DiaryNoteKind.notice: 'notice',
  DiaryNoteKind.reminder: 'reminder',
  DiaryNoteKind.teacherNote: 'teacher_note',
  DiaryNoteKind.activity: 'activity',
};
