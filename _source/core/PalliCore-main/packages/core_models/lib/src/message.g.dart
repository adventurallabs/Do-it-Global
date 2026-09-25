// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessageThread _$MessageThreadFromJson(Map<String, dynamic> json) =>
    MessageThread(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      classroomId: json['classroom_id'] as String? ?? '',
      parentId: json['parent_id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      lastMessageAt: DateTime.parse(json['last_message_at'] as String),
      parentUnread: (json['parent_unread'] as num?)?.toInt() ?? 0,
      teacherUnread: (json['teacher_unread'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MessageThreadToJson(MessageThread instance) =>
    <String, dynamic>{
      'id': instance.id,
      'student_id': instance.studentId,
      'classroom_id': instance.classroomId,
      'parent_id': instance.parentId,
      'teacher_id': instance.teacherId,
      'subject': instance.subject,
      'last_message_at': instance.lastMessageAt.toIso8601String(),
      'parent_unread': instance.parentUnread,
      'teacher_unread': instance.teacherUnread,
    };

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  id: json['id'] as String,
  threadId: json['thread_id'] as String,
  senderRole: $enumDecode(_$MessageSenderRoleEnumMap, json['sender_role']),
  senderId: json['sender_id'] as String? ?? '',
  kind:
      $enumDecodeNullable(
        _$MessageKindEnumMap,
        json['kind'],
        unknownValue: MessageKind.text,
      ) ??
      MessageKind.text,
  body: json['body'] as String? ?? '',
  attachmentName: json['attachment_name'] as String?,
  attachmentSize: (json['attachment_size'] as num?)?.toInt(),
  attachmentUrl: json['attachment_url'] as String?,
  leaveRequestId: json['leave_request_id'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  readAt: json['read_at'] == null
      ? null
      : DateTime.parse(json['read_at'] as String),
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'id': instance.id,
  'thread_id': instance.threadId,
  'sender_role': _$MessageSenderRoleEnumMap[instance.senderRole]!,
  'sender_id': instance.senderId,
  'kind': _$MessageKindEnumMap[instance.kind]!,
  'body': instance.body,
  'attachment_name': instance.attachmentName,
  'attachment_size': instance.attachmentSize,
  'attachment_url': instance.attachmentUrl,
  'leave_request_id': instance.leaveRequestId,
  'created_at': instance.createdAt.toIso8601String(),
  'read_at': instance.readAt?.toIso8601String(),
};

const _$MessageSenderRoleEnumMap = {
  MessageSenderRole.parent: 'parent',
  MessageSenderRole.teacher: 'teacher',
};

const _$MessageKindEnumMap = {
  MessageKind.text: 'text',
  MessageKind.leaveRequest: 'leave_request',
  MessageKind.lateInfo: 'late_info',
  MessageKind.absentInfo: 'absent_info',
  MessageKind.document: 'document',
};
