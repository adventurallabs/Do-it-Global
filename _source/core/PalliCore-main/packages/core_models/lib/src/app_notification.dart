import 'package:json_annotation/json_annotation.dart';

part 'app_notification.g.dart';

enum NotificationRecipientRole {
  @JsonValue('parent')
  parent,
  @JsonValue('teacher')
  teacher,
  @JsonValue('admin')
  admin,
}

enum NotificationKind {
  @JsonValue('homework')
  homework,
  @JsonValue('marks')
  marks,
  @JsonValue('attendance')
  attendance,
  @JsonValue('fees')
  fees,
  @JsonValue('announcement')
  announcement,
  @JsonValue('message')
  message,
  @JsonValue('leave')
  leave,
  @JsonValue('activity')
  activity,
  @JsonValue('event')
  event,
  @JsonValue('diary')
  diary,
  @JsonValue('cover_request')
  coverRequest,
  @JsonValue('exam')
  exam,
  @JsonValue('library')
  libraryLoan,
  @JsonValue('school')
  school,
}

@JsonSerializable(fieldRename: FieldRename.snake)
class AppNotification {
  final String id;
  @JsonKey(
      defaultValue: NotificationRecipientRole.teacher,
      unknownEnumValue: NotificationRecipientRole.teacher)
  final NotificationRecipientRole recipientRole;
  @JsonKey(defaultValue: '')
  final String recipientId;
  final String? studentId;
  @JsonKey(defaultValue: NotificationKind.school, unknownEnumValue: NotificationKind.school)
  final NotificationKind kind;
  final String title;
  @JsonKey(defaultValue: '')
  final String body;
  @JsonKey(defaultValue: '')
  final String deepLink;
  @JsonKey(defaultValue: false)
  final bool isImportant;
  @JsonKey(defaultValue: false)
  final bool grouped;
  final int? groupCount;
  final DateTime createdAt;
  final DateTime? readAt;

  AppNotification({
    required this.id,
    this.recipientRole = NotificationRecipientRole.teacher,
    this.recipientId = '',
    this.studentId,
    this.kind = NotificationKind.school,
    required this.title,
    this.body = '',
    this.deepLink = '',
    this.isImportant = false,
    this.grouped = false,
    this.groupCount,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
  Map<String, dynamic> toJson() => _$AppNotificationToJson(this);
}
