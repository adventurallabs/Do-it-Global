import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

enum MessageSenderRole {
  @JsonValue('parent')
  parent,
  @JsonValue('teacher')
  teacher,
}

enum MessageKind {
  @JsonValue('text')
  text,
  @JsonValue('leave_request')
  leaveRequest,
  @JsonValue('late_info')
  lateInfo,
  @JsonValue('absent_info')
  absentInfo,
  @JsonValue('document')
  document,
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MessageThread {
  final String id;
  final String studentId;
  @JsonKey(defaultValue: '')
  final String classroomId;
  @JsonKey(defaultValue: '')
  final String parentId;
  @JsonKey(defaultValue: '')
  final String teacherId;
  @JsonKey(defaultValue: '')
  final String subject;
  final DateTime lastMessageAt;
  @JsonKey(defaultValue: 0)
  final int parentUnread;
  @JsonKey(defaultValue: 0)
  final int teacherUnread;

  MessageThread({
    required this.id,
    required this.studentId,
    this.classroomId = '',
    this.parentId = '',
    this.teacherId = '',
    this.subject = '',
    required this.lastMessageAt,
    this.parentUnread = 0,
    this.teacherUnread = 0,
  });

  factory MessageThread.fromJson(Map<String, dynamic> json) =>
      _$MessageThreadFromJson(json);
  Map<String, dynamic> toJson() => _$MessageThreadToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Message {
  final String id;
  final String threadId;
  final MessageSenderRole senderRole;
  @JsonKey(defaultValue: '')
  final String senderId;
  @JsonKey(defaultValue: MessageKind.text, unknownEnumValue: MessageKind.text)
  final MessageKind kind;
  @JsonKey(defaultValue: '')
  final String body;
  final String? attachmentName;
  final int? attachmentSize;
  final String? attachmentUrl;
  final String? leaveRequestId;
  final DateTime createdAt;
  final DateTime? readAt;

  Message({
    required this.id,
    required this.threadId,
    required this.senderRole,
    this.senderId = '',
    this.kind = MessageKind.text,
    this.body = '',
    this.attachmentName,
    this.attachmentSize,
    this.attachmentUrl,
    this.leaveRequestId,
    required this.createdAt,
    this.readAt,
  });

  bool get isFromParent => senderRole == MessageSenderRole.parent;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);
}
