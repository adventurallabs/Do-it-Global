import 'package:json_annotation/json_annotation.dart';
import 'academic_year.dart';
import 'exit_record.dart';

part 'student.g.dart';

/// Recorded for the school register. Nullable everywhere it appears, because
/// "nobody has asked yet" is a different state from any answer.
enum Gender {
  @JsonValue('male')
  male,
  @JsonValue('female')
  female,
  @JsonValue('other')
  other;

  String get label => switch (this) {
        Gender.male => 'Male',
        Gender.female => 'Female',
        Gender.other => 'Other',
      };
}


@JsonSerializable(fieldRename: FieldRename.snake)
class Student {
  final String id;
  final String name;
  final String rollNumber;
  final String? photoUrl;
  final String fatherName;
  final String motherName;
  final String contactNumber;
  final String? secondaryContactNumber;

  /// Who to call when the parents cannot be reached. Collected at
  /// admission when it is known, chased afterwards when it is not.
  final String? emergencyContact;
  final String? emergencyContactAlt;

  final Gender? gender;

  /// Blood group as written on the record — free text rather than an
  /// enum, because a school copies what the certificate says.
  final String? bloodGroup;

  /// The day they joined. Set to the row's creation date at admission.
  final DateTime? admissionDate;

  /// Null until somebody answers. False is a real answer — the child
  /// walks — and must not be confused with never having been asked.
  final bool? needsTransport;

  final String address;
  final String classroomId;
  final double fees;
  @JsonKey(defaultValue: 'ay-current')
  final String academicYearId;
  @JsonKey(defaultValue: StudentLifecycle.enrolled)
  final StudentLifecycle lifecycle;
  /// School register/admission number. Also doubles as the parent-app login
  /// identity (`<admissionNo>@parent.internal`) — must be unique.
  final String admissionNo;
  @JsonKey(defaultValue: true)
  final bool isActive;
  final DateTime? deactivatedAt;
  /// Source for the parent login's default password (first initial + DDMMYYYY).
  final DateTime? dob;
  /// When the child left and when their file is erased. [lifecycle] says why;
  /// these say when, and are only set for a lifecycle that has left.
  final DateTime? exitAt;
  final DateTime? purgeAfter;
  @JsonKey(defaultValue: '')
  final String exitNote;

  Student({
    required this.id,
    required this.name,
    required this.rollNumber,
    this.photoUrl,
    required this.fatherName,
    required this.motherName,
    required this.contactNumber,
    this.secondaryContactNumber,
    this.emergencyContact,
    this.emergencyContactAlt,
    this.gender,
    this.bloodGroup,
    this.admissionDate,
    this.needsTransport,
    required this.address,
    required this.classroomId,
    required this.fees,
    this.academicYearId = 'ay-current',
    this.lifecycle = StudentLifecycle.enrolled,
    required this.admissionNo,
    this.isActive = true,
    this.deactivatedAt,
    this.dob,
    this.exitAt,
    this.purgeAfter,
    this.exitNote = '',
  });

  /// Non-null once the child has left — the archive entry with its retention
  /// countdown. Derived from [lifecycle] so the two can never disagree.
  ExitRecord? get exit {
    final reason = lifecycle.exitReason;
    if (reason == null || exitAt == null) return null;
    return ExitRecord(
      reason: reason,
      at: exitAt!,
      purgeAfter: purgeAfter ?? ArchivePolicy.purgeDateFor(exitAt!),
      note: exitNote,
    );
  }

  bool get hasLeft => exit != null;

  Student copyWith({
    String? id,
    String? name,
    String? rollNumber,
    String? photoUrl,
    String? fatherName,
    String? motherName,
    String? contactNumber,
    String? secondaryContactNumber,
    String? address,
    String? classroomId,
    double? fees,
    String? academicYearId,
    StudentLifecycle? lifecycle,
    String? admissionNo,
    bool? isActive,
    DateTime? deactivatedAt,
    bool clearDeactivatedAt = false,
    DateTime? dob,
    DateTime? exitAt,
    DateTime? purgeAfter,
    String? exitNote,
    bool clearExit = false,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      rollNumber: rollNumber ?? this.rollNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      contactNumber: contactNumber ?? this.contactNumber,
      secondaryContactNumber: secondaryContactNumber ?? this.secondaryContactNumber,
      address: address ?? this.address,
      classroomId: classroomId ?? this.classroomId,
      fees: fees ?? this.fees,
      academicYearId: academicYearId ?? this.academicYearId,
      lifecycle: lifecycle ?? this.lifecycle,
      admissionNo: admissionNo ?? this.admissionNo,
      isActive: isActive ?? this.isActive,
      deactivatedAt: clearDeactivatedAt ? null : (deactivatedAt ?? this.deactivatedAt),
      dob: dob ?? this.dob,
      exitAt: clearExit ? null : (exitAt ?? this.exitAt),
      purgeAfter: clearExit ? null : (purgeAfter ?? this.purgeAfter),
      exitNote: clearExit ? '' : (exitNote ?? this.exitNote),
    );
  }

  factory Student.fromJson(Map<String, dynamic> json) => _$StudentFromJson(json);
  Map<String, dynamic> toJson() => _$StudentToJson(this);
}
