import 'package:json_annotation/json_annotation.dart';

part 'admission.g.dart';

enum AdmissionStage {
  @JsonValue('enquiry')
  enquiry,
  @JsonValue('application')
  application,
  @JsonValue('documents')
  documents,
  @JsonValue('verification')
  verification,
  @JsonValue('approved')
  approved,
  @JsonValue('rejected')
  rejected,
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Admission {
  final String id;
  final String studentName;
  final String parentName;
  final String contactNumber;
  final String appliedGradeKey;
  final String notes;
  final AdmissionStage stage;
  final DateTime createdAt;
  final String? createdStudentId;

  Admission({
    required this.id,
    required this.studentName,
    required this.parentName,
    required this.contactNumber,
    required this.appliedGradeKey,
    this.notes = '',
    this.stage = AdmissionStage.enquiry,
    required this.createdAt,
    this.createdStudentId,
  });

  Admission copyWith({
    AdmissionStage? stage,
    String? notes,
    String? createdStudentId,
  }) {
    return Admission(
      id: id,
      studentName: studentName,
      parentName: parentName,
      contactNumber: contactNumber,
      appliedGradeKey: appliedGradeKey,
      notes: notes ?? this.notes,
      stage: stage ?? this.stage,
      createdAt: createdAt,
      createdStudentId: createdStudentId ?? this.createdStudentId,
    );
  }

  factory Admission.fromJson(Map<String, dynamic> json) =>
      _$AdmissionFromJson(json);
  Map<String, dynamic> toJson() => _$AdmissionToJson(this);
}
