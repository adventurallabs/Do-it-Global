// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Student _$StudentFromJson(Map<String, dynamic> json) => Student(
  id: json['id'] as String,
  name: json['name'] as String,
  rollNumber: json['roll_number'] as String,
  photoUrl: json['photo_url'] as String?,
  fatherName: json['father_name'] as String,
  motherName: json['mother_name'] as String,
  contactNumber: json['contact_number'] as String,
  secondaryContactNumber: json['secondary_contact_number'] as String?,
  emergencyContact: json['emergency_contact'] as String?,
  emergencyContactAlt: json['emergency_contact_alt'] as String?,
  gender: $enumDecodeNullable(_$GenderEnumMap, json['gender']),
  bloodGroup: json['blood_group'] as String?,
  admissionDate: json['admission_date'] == null
      ? null
      : DateTime.parse(json['admission_date'] as String),
  needsTransport: json['needs_transport'] as bool?,
  address: json['address'] as String,
  classroomId: json['classroom_id'] as String,
  fees: (json['fees'] as num).toDouble(),
  academicYearId: json['academic_year_id'] as String? ?? 'ay-current',
  lifecycle:
      $enumDecodeNullable(_$StudentLifecycleEnumMap, json['lifecycle']) ??
      StudentLifecycle.enrolled,
  admissionNo: json['admission_no'] as String,
  isActive: json['is_active'] as bool? ?? true,
  deactivatedAt: json['deactivated_at'] == null
      ? null
      : DateTime.parse(json['deactivated_at'] as String),
  dob: json['dob'] == null ? null : DateTime.parse(json['dob'] as String),
  exitAt: json['exit_at'] == null
      ? null
      : DateTime.parse(json['exit_at'] as String),
  purgeAfter: json['purge_after'] == null
      ? null
      : DateTime.parse(json['purge_after'] as String),
  exitNote: json['exit_note'] as String? ?? '',
);

Map<String, dynamic> _$StudentToJson(Student instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'roll_number': instance.rollNumber,
  'photo_url': instance.photoUrl,
  'father_name': instance.fatherName,
  'mother_name': instance.motherName,
  'contact_number': instance.contactNumber,
  'secondary_contact_number': instance.secondaryContactNumber,
  'emergency_contact': instance.emergencyContact,
  'emergency_contact_alt': instance.emergencyContactAlt,
  'gender': _$GenderEnumMap[instance.gender],
  'blood_group': instance.bloodGroup,
  'admission_date': instance.admissionDate?.toIso8601String(),
  'needs_transport': instance.needsTransport,
  'address': instance.address,
  'classroom_id': instance.classroomId,
  'fees': instance.fees,
  'academic_year_id': instance.academicYearId,
  'lifecycle': _$StudentLifecycleEnumMap[instance.lifecycle]!,
  'admission_no': instance.admissionNo,
  'is_active': instance.isActive,
  'deactivated_at': instance.deactivatedAt?.toIso8601String(),
  'dob': instance.dob?.toIso8601String(),
  'exit_at': instance.exitAt?.toIso8601String(),
  'purge_after': instance.purgeAfter?.toIso8601String(),
  'exit_note': instance.exitNote,
};

const _$GenderEnumMap = {
  Gender.male: 'male',
  Gender.female: 'female',
  Gender.other: 'other',
};

const _$StudentLifecycleEnumMap = {
  StudentLifecycle.enrolled: 'enrolled',
  StudentLifecycle.retained: 'retained',
  StudentLifecycle.graduated: 'graduated',
  StudentLifecycle.transferred: 'transferred',
  StudentLifecycle.discontinued: 'discontinued',
};
