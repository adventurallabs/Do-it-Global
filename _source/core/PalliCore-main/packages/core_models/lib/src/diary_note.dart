import 'package:json_annotation/json_annotation.dart';

part 'diary_note.g.dart';

enum DiaryNoteKind {
  @JsonValue('note')
  note,
  @JsonValue('notice')
  notice,
  @JsonValue('reminder')
  reminder,
  @JsonValue('teacher_note')
  teacherNote,
  @JsonValue('activity')
  activity,
}

@JsonSerializable(fieldRename: FieldRename.snake)
class DiaryNote {
  final String id;
  final String classroomId;
  final String? studentId;
  final DateTime noteDate;
  @JsonKey(defaultValue: DiaryNoteKind.note, unknownEnumValue: DiaryNoteKind.note)
  final DiaryNoteKind kind;
  @JsonKey(defaultValue: '')
  final String title;
  final String body;
  final String? teacherName;
  @JsonKey(defaultValue: false)
  final bool hasAttachment;
  final String? attachmentUrl;
  @JsonKey(defaultValue: '')
  final String createdBy;

  DiaryNote({
    required this.id,
    required this.classroomId,
    this.studentId,
    required this.noteDate,
    this.kind = DiaryNoteKind.note,
    this.title = '',
    required this.body,
    this.teacherName,
    this.hasAttachment = false,
    this.attachmentUrl,
    this.createdBy = '',
  });

  factory DiaryNote.fromJson(Map<String, dynamic> json) => _$DiaryNoteFromJson(json);
  Map<String, dynamic> toJson() => _$DiaryNoteToJson(this);
}
