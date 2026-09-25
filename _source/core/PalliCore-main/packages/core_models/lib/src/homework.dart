import 'package:json_annotation/json_annotation.dart';

part 'homework.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Homework {
  final String id;
  final String classroomId;
  final String subject;
  final String title;
  final String description;
  final DateTime dueDate;
  final String createdBy;
  final String? studentId;
  final String? attachmentUrl;
  final String? attachmentName;

  Homework({
    required this.id,
    required this.classroomId,
    required this.subject,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.createdBy,
    this.studentId,
    this.attachmentUrl,
    this.attachmentName,
  });

  bool get hasAttachment => (attachmentUrl ?? '').isNotEmpty;

  factory Homework.fromJson(Map<String, dynamic> json) => _$HomeworkFromJson(json);
  Map<String, dynamic> toJson() => _$HomeworkToJson(this);
}
