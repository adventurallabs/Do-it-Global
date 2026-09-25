// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'school_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SchoolProfile _$SchoolProfileFromJson(Map<String, dynamic> json) =>
    SchoolProfile(
      name: json['name'] as String? ?? '',
      logoUrl: json['logo_url'] as String? ?? '',
      primaryColorHex: json['primary_color_hex'] as String? ?? '#2F6BFF',
      accentColorHex: json['accent_color_hex'] as String? ?? '#C9A227',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      academicSessionLabel: json['academic_session_label'] as String?,
      attendanceWarningThreshold:
          (json['attendance_warning_threshold'] as num?)?.toInt() ?? 85,
    );

Map<String, dynamic> _$SchoolProfileToJson(SchoolProfile instance) =>
    <String, dynamic>{
      'name': instance.name,
      'logo_url': instance.logoUrl,
      'primary_color_hex': instance.primaryColorHex,
      'accent_color_hex': instance.accentColorHex,
      'address': instance.address,
      'phone': instance.phone,
      'email': instance.email,
      'academic_session_label': instance.academicSessionLabel,
      'attendance_warning_threshold': instance.attendanceWarningThreshold,
    };
