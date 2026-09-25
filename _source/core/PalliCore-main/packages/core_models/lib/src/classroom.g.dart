// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'classroom.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Classroom _$ClassroomFromJson(Map<String, dynamic> json) => Classroom(
  id: json['id'] as String,
  name: json['name'] as String,
  classTeacherId: json['class_teacher_id'] as String,
  baseFees: (json['base_fees'] as num).toDouble(),
  gradeKey: json['grade_key'] as String? ?? '',
  section: json['section'] as String? ?? '',
);

Map<String, dynamic> _$ClassroomToJson(Classroom instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'class_teacher_id': instance.classTeacherId,
  'base_fees': instance.baseFees,
  'grade_key': instance.gradeKey,
  'section': instance.section,
};
