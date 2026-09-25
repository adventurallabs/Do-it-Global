// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    AppNotification(
      id: json['id'] as String,
      recipientRole:
          $enumDecodeNullable(
            _$NotificationRecipientRoleEnumMap,
            json['recipient_role'],
            unknownValue: NotificationRecipientRole.teacher,
          ) ??
          NotificationRecipientRole.teacher,
      recipientId: json['recipient_id'] as String? ?? '',
      studentId: json['student_id'] as String?,
      kind:
          $enumDecodeNullable(
            _$NotificationKindEnumMap,
            json['kind'],
            unknownValue: NotificationKind.school,
          ) ??
          NotificationKind.school,
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      deepLink: json['deep_link'] as String? ?? '',
      isImportant: json['is_important'] as bool? ?? false,
      grouped: json['grouped'] as bool? ?? false,
      groupCount: (json['group_count'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
    );

Map<String, dynamic> _$AppNotificationToJson(
  AppNotification instance,
) => <String, dynamic>{
  'id': instance.id,
  'recipient_role': _$NotificationRecipientRoleEnumMap[instance.recipientRole]!,
  'recipient_id': instance.recipientId,
  'student_id': instance.studentId,
  'kind': _$NotificationKindEnumMap[instance.kind]!,
  'title': instance.title,
  'body': instance.body,
  'deep_link': instance.deepLink,
  'is_important': instance.isImportant,
  'grouped': instance.grouped,
  'group_count': instance.groupCount,
  'created_at': instance.createdAt.toIso8601String(),
  'read_at': instance.readAt?.toIso8601String(),
};

const _$NotificationRecipientRoleEnumMap = {
  NotificationRecipientRole.parent: 'parent',
  NotificationRecipientRole.teacher: 'teacher',
  NotificationRecipientRole.admin: 'admin',
};

const _$NotificationKindEnumMap = {
  NotificationKind.homework: 'homework',
  NotificationKind.marks: 'marks',
  NotificationKind.attendance: 'attendance',
  NotificationKind.fees: 'fees',
  NotificationKind.announcement: 'announcement',
  NotificationKind.message: 'message',
  NotificationKind.leave: 'leave',
  NotificationKind.activity: 'activity',
  NotificationKind.event: 'event',
  NotificationKind.diary: 'diary',
  NotificationKind.coverRequest: 'cover_request',
  NotificationKind.exam: 'exam',
  NotificationKind.libraryLoan: 'library',
  NotificationKind.school: 'school',
};
