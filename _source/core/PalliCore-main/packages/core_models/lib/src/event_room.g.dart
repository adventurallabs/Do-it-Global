// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_room.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventRoom _$EventRoomFromJson(Map<String, dynamic> json) => EventRoom(
  id: json['id'] as String,
  categoryId: json['category_id'] as String,
  name: json['name'] as String,
  status:
      $enumDecodeNullable(_$EventRoomStatusEnumMap, json['status']) ??
      EventRoomStatus.draft,
  prizeCount: (json['prize_count'] as num?)?.toInt() ?? 3,
  startedAt: json['started_at'] == null
      ? null
      : DateTime.parse(json['started_at'] as String),
  submittedAt: json['submitted_at'] == null
      ? null
      : DateTime.parse(json['submitted_at'] as String),
  createdBy: json['created_by'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$EventRoomToJson(EventRoom instance) => <String, dynamic>{
  'id': instance.id,
  'category_id': instance.categoryId,
  'name': instance.name,
  'status': _$EventRoomStatusEnumMap[instance.status]!,
  'prize_count': instance.prizeCount,
  'started_at': instance.startedAt?.toIso8601String(),
  'submitted_at': instance.submittedAt?.toIso8601String(),
  'created_by': instance.createdBy,
  'created_at': instance.createdAt?.toIso8601String(),
};

const _$EventRoomStatusEnumMap = {
  EventRoomStatus.draft: 'draft',
  EventRoomStatus.started: 'started',
  EventRoomStatus.submitted: 'submitted',
};

EventResult _$EventResultFromJson(Map<String, dynamic> json) => EventResult(
  roomId: json['room_id'] as String,
  position: (json['position'] as num).toInt(),
  participantId: json['participant_id'] as String,
);

Map<String, dynamic> _$EventResultToJson(EventResult instance) =>
    <String, dynamic>{
      'room_id': instance.roomId,
      'position': instance.position,
      'participant_id': instance.participantId,
    };

EventCertificate _$EventCertificateFromJson(Map<String, dynamic> json) =>
    EventCertificate(
      roomId: json['room_id'] as String,
      layoutId: json['layout_id'] as String,
      publishedAt: json['published_at'] == null
          ? null
          : DateTime.parse(json['published_at'] as String),
    );

Map<String, dynamic> _$EventCertificateToJson(EventCertificate instance) =>
    <String, dynamic>{
      'room_id': instance.roomId,
      'layout_id': instance.layoutId,
      'published_at': instance.publishedAt?.toIso8601String(),
    };
