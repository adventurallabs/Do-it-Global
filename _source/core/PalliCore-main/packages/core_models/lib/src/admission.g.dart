// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admission.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Admission _$AdmissionFromJson(Map<String, dynamic> json) => Admission(
  id: json['id'] as String,
  studentName: json['student_name'] as String,
  parentName: json['parent_name'] as String,
  contactNumber: json['contact_number'] as String,
  appliedGradeKey: json['applied_grade_key'] as String,
  notes: json['notes'] as String? ?? '',
  stage:
      $enumDecodeNullable(_$AdmissionStageEnumMap, json['stage']) ??
      AdmissionStage.enquiry,
  createdAt: DateTime.parse(json['created_at'] as String),
  createdStudentId: json['created_student_id'] as String?,
);

Map<String, dynamic> _$AdmissionToJson(Admission instance) => <String, dynamic>{
  'id': instance.id,
  'student_name': instance.studentName,
  'parent_name': instance.parentName,
  'contact_number': instance.contactNumber,
  'applied_grade_key': instance.appliedGradeKey,
  'notes': instance.notes,
  'stage': _$AdmissionStageEnumMap[instance.stage]!,
  'created_at': instance.createdAt.toIso8601String(),
  'created_student_id': instance.createdStudentId,
};

const _$AdmissionStageEnumMap = {
  AdmissionStage.enquiry: 'enquiry',
  AdmissionStage.application: 'application',
  AdmissionStage.documents: 'documents',
  AdmissionStage.verification: 'verification',
  AdmissionStage.approved: 'approved',
  AdmissionStage.rejected: 'rejected',
};
