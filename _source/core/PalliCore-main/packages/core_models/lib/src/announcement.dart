import 'package:json_annotation/json_annotation.dart';

part 'announcement.g.dart';

enum AnnouncementTarget {
  @JsonValue('teachers')
  teachers,
  @JsonValue('students')
  students,
  @JsonValue('overall')
  overall,
  @JsonValue('parents')
  parents,
}

enum AnnouncementScope {
  @JsonValue('school')
  school,
  @JsonValue('classroom')
  classroom,
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Announcement {
  final String id;
  final String title;
  final String content;
  final AnnouncementTarget target;
  @JsonKey(defaultValue: AnnouncementScope.school, unknownEnumValue: AnnouncementScope.school)
  final AnnouncementScope scope;
  final String? classroomId;
  @JsonKey(defaultValue: false)
  final bool isImportant;
  @JsonKey(defaultValue: '')
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.target,
    this.scope = AnnouncementScope.school,
    this.classroomId,
    this.isImportant = false,
    this.createdBy = '',
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isClassroomScoped =>
      scope == AnnouncementScope.classroom && (classroomId ?? '').isNotEmpty;

  factory Announcement.fromJson(Map<String, dynamic> json) => _$AnnouncementFromJson(json);
  Map<String, dynamic> toJson() => _$AnnouncementToJson(this);
}
