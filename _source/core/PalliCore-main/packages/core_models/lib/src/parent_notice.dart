import 'package:json_annotation/json_annotation.dart';

part 'parent_notice.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class ParentNotice {
  final String id;
  final String eventId;
  final String studentId;
  final String studentName;
  final String guardianName;
  final String contactNumber;
  final String title;
  final String body;
  final DateTime createdAt;

  ParentNotice({
    required this.id,
    required this.eventId,
    required this.studentId,
    required this.studentName,
    required this.guardianName,
    required this.contactNumber,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  factory ParentNotice.fromJson(Map<String, dynamic> json) =>
      _$ParentNoticeFromJson(json);
  Map<String, dynamic> toJson() => _$ParentNoticeToJson(this);
}
