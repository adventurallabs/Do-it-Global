// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Teacher _$TeacherFromJson(Map<String, dynamic> json) => Teacher(
  id: json['id'] as String,
  name: json['name'] as String,
  contactNumber: json['contact_number'] as String,
  photoUrl: json['photo_url'] as String?,
  qualification: json['qualification'] as String,
  gender: $enumDecodeNullable(_$GenderEnumMap, json['gender']),
  joinDate: json['join_date'] == null
      ? null
      : DateTime.parse(json['join_date'] as String),
  emergencyContact: json['emergency_contact'] as String?,
  address: json['address'] as String,
  salary: (json['salary'] as num).toDouble(),
  classroomId: json['classroom_id'] as String?,
  role:
      $enumDecodeNullable(_$StaffRoleEnumMap, json['role']) ??
      StaffRole.teaching,
  isActive: json['is_active'] as bool? ?? true,
  deactivatedAt: json['deactivated_at'] == null
      ? null
      : DateTime.parse(json['deactivated_at'] as String),
  dob: json['dob'] == null ? null : DateTime.parse(json['dob'] as String),
  subjects:
      (json['subjects'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  exitReason: $enumDecodeNullable(_$ExitReasonEnumMap, json['exit_reason']),
  exitAt: json['exit_at'] == null
      ? null
      : DateTime.parse(json['exit_at'] as String),
  purgeAfter: json['purge_after'] == null
      ? null
      : DateTime.parse(json['purge_after'] as String),
  exitNote: json['exit_note'] as String? ?? '',
);

Map<String, dynamic> _$TeacherToJson(Teacher instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'contact_number': instance.contactNumber,
  'photo_url': instance.photoUrl,
  'qualification': instance.qualification,
  'gender': _$GenderEnumMap[instance.gender],
  'join_date': instance.joinDate?.toIso8601String(),
  'emergency_contact': instance.emergencyContact,
  'address': instance.address,
  'salary': instance.salary,
  'classroom_id': instance.classroomId,
  'role': _$StaffRoleEnumMap[instance.role]!,
  'is_active': instance.isActive,
  'deactivated_at': instance.deactivatedAt?.toIso8601String(),
  'dob': instance.dob?.toIso8601String(),
  'subjects': instance.subjects,
  'exit_reason': _$ExitReasonEnumMap[instance.exitReason],
  'exit_at': instance.exitAt?.toIso8601String(),
  'purge_after': instance.purgeAfter?.toIso8601String(),
  'exit_note': instance.exitNote,
};

const _$GenderEnumMap = {
  Gender.male: 'male',
  Gender.female: 'female',
  Gender.other: 'other',
};

const _$StaffRoleEnumMap = {
  StaffRole.teaching: 'teaching',
  StaffRole.nonTeaching: 'nonTeaching',
  StaffRole.driver: 'driver',
  StaffRole.office: 'office',
  StaffRole.librarian: 'librarian',
};

const _$ExitReasonEnumMap = {
  ExitReason.discontinued: 'discontinued',
  ExitReason.transferred: 'transferred',
  ExitReason.graduated: 'graduated',
};
