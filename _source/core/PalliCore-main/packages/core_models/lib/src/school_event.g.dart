// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'school_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SchoolEvent _$SchoolEventFromJson(Map<String, dynamic> json) => SchoolEvent(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  eventDate: DateTime.parse(json['event_date'] as String),
  lastPayDate: json['last_pay_date'] == null
      ? null
      : DateTime.parse(json['last_pay_date'] as String),
  feeAmount: (json['fee_amount'] as num?)?.toDouble() ?? 0,
  audience: $enumDecode(_$EventAudienceEnumMap, json['audience']),
  classroomIds:
      (json['classroom_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$SchoolEventToJson(SchoolEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'event_date': instance.eventDate.toIso8601String(),
      'last_pay_date': instance.lastPayDate?.toIso8601String(),
      'fee_amount': instance.feeAmount,
      'audience': _$EventAudienceEnumMap[instance.audience]!,
      'classroom_ids': instance.classroomIds,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$EventAudienceEnumMap = {
  EventAudience.school: 'school',
  EventAudience.classrooms: 'classrooms',
};
