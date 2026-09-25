import 'package:json_annotation/json_annotation.dart';
import 'exit_record.dart';
// Gender is declared beside Student because that is where it was first
// needed; staff use the same three values rather than a parallel enum.
import 'student.dart' show Gender;

part 'teacher.g.dart';

enum StaffRole {
  @JsonValue('teaching')
  teaching,
  @JsonValue('nonTeaching')
  nonTeaching,
  @JsonValue('driver')
  driver,
  @JsonValue('office')
  office,
  /// Runs the Digital Library. Signs in like a teacher but lands on the
  /// library dashboard, and is never offered as a teacher for a class,
  /// period or cover.
  @JsonValue('librarian')
  librarian,
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Teacher {
  final String id;
  final String name;
  final String contactNumber;
  final String? photoUrl;
  final String qualification;

  final Gender? gender;

  /// The day they started. Set to the row's creation date when the
  /// login is issued.
  final DateTime? joinDate;

  /// Who to call if something happens to them at school.
  final String? emergencyContact;

  final String address;
  final double salary;
  final String? classroomId;
  @JsonKey(defaultValue: StaffRole.teaching)
  final StaffRole role;
  @JsonKey(defaultValue: true)
  final bool isActive;
  final DateTime? deactivatedAt;
  /// Source for the default login password (first initial + DDMMYYYY).
  final DateTime? dob;
  @JsonKey(defaultValue: <String>[])
  final List<String> subjects;
  /// Set when the staff member has left the school for good. Distinct from
  /// [isActive], which only says whether their login works right now.
  final ExitReason? exitReason;
  final DateTime? exitAt;
  /// The date the nightly purge is entitled to erase this record.
  final DateTime? purgeAfter;
  @JsonKey(defaultValue: '')
  final String exitNote;

  Teacher({
    required this.id,
    required this.name,
    required this.contactNumber,
    this.photoUrl,
    required this.qualification,
    this.gender,
    this.joinDate,
    this.emergencyContact,
    required this.address,
    required this.salary,
    this.classroomId,
    this.role = StaffRole.teaching,
    this.isActive = true,
    this.deactivatedAt,
    this.dob,
    this.subjects = const [],
    this.exitReason,
    this.exitAt,
    this.purgeAfter,
    this.exitNote = '',
  });

  /// Non-null only once they have left — the archive entry with its
  /// retention countdown.
  ExitRecord? get exit => exitReason == null || exitAt == null
      ? null
      : ExitRecord(
          reason: exitReason!,
          at: exitAt!,
          purgeAfter: purgeAfter ?? ArchivePolicy.purgeDateFor(exitAt!),
          note: exitNote,
        );

  bool get hasLeft => exit != null;

  bool get isTeaching => role == StaffRole.teaching;

  bool get isLibrarian => role == StaffRole.librarian;

  String get roleLabel {
    switch (role) {
      case StaffRole.teaching:
        return 'Teaching staff';
      case StaffRole.nonTeaching:
        return 'Non-teaching staff';
      case StaffRole.driver:
        return 'Driver';
      case StaffRole.office:
        return 'Office staff';
      case StaffRole.librarian:
        return 'Librarian';
    }
  }

  Teacher copyWith({
    String? id,
    String? name,
    String? contactNumber,
    String? photoUrl,
    String? qualification,
    String? address,
    double? salary,
    String? classroomId,
    bool clearClassroom = false,
    StaffRole? role,
    Gender? gender,
    DateTime? joinDate,
    String? emergencyContact,
    bool? isActive,
    DateTime? deactivatedAt,
    bool clearDeactivatedAt = false,
    DateTime? dob,
    List<String>? subjects,
    ExitReason? exitReason,
    DateTime? exitAt,
    DateTime? purgeAfter,
    String? exitNote,
    bool clearExit = false,
  }) {
    return Teacher(
      id: id ?? this.id,
      name: name ?? this.name,
      contactNumber: contactNumber ?? this.contactNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      qualification: qualification ?? this.qualification,
      address: address ?? this.address,
      salary: salary ?? this.salary,
      classroomId: clearClassroom ? null : (classroomId ?? this.classroomId),
      role: role ?? this.role,
      gender: gender ?? this.gender,
      joinDate: joinDate ?? this.joinDate,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      isActive: isActive ?? this.isActive,
      deactivatedAt: clearDeactivatedAt ? null : (deactivatedAt ?? this.deactivatedAt),
      dob: dob ?? this.dob,
      subjects: subjects ?? this.subjects,
      exitReason: clearExit ? null : (exitReason ?? this.exitReason),
      exitAt: clearExit ? null : (exitAt ?? this.exitAt),
      purgeAfter: clearExit ? null : (purgeAfter ?? this.purgeAfter),
      exitNote: clearExit ? '' : (exitNote ?? this.exitNote),
    );
  }

  factory Teacher.fromJson(Map<String, dynamic> json) => _$TeacherFromJson(json);
  Map<String, dynamic> toJson() => _$TeacherToJson(this);
}
