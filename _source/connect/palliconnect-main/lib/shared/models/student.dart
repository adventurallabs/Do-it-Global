class Student {
  final String id;
  final String schoolId;
  final String admissionNo;
  final String rollNo;
  final String fullName;
  final String? photoUrl;
  final String className;
  final String sectionName;
  final String academicYear;
  final String? bloodGroup;
  final String? classTeacher;
  final String classroomId;

  /// The details admission leaves optional. Held here so the app can tell the
  /// family exactly which ones the school is still waiting on.
  final String? gender;
  final DateTime? dob;
  final String? address;
  final String? emergencyContact;

  /// Null means nobody has been asked yet — not the same as "no".
  final bool? needsTransport;
  final bool hasTransportDetails;
  final int documentCount;

  Student({
    required this.id,
    required this.schoolId,
    required this.admissionNo,
    required this.rollNo,
    required this.fullName,
    this.photoUrl,
    required this.className,
    required this.sectionName,
    this.academicYear = '2026–27',
    this.bloodGroup,
    this.classTeacher,
    this.classroomId = '',
    this.gender,
    this.dob,
    this.address,
    this.emergencyContact,
    this.needsTransport,
    this.hasTransportDetails = false,
    this.documentCount = 0,
  });

  String get classLabel => '$className-$sectionName';

  Student copyWith({bool? hasTransportDetails, int? documentCount}) => Student(
        id: id,
        schoolId: schoolId,
        admissionNo: admissionNo,
        rollNo: rollNo,
        fullName: fullName,
        photoUrl: photoUrl,
        className: className,
        sectionName: sectionName,
        academicYear: academicYear,
        bloodGroup: bloodGroup,
        classTeacher: classTeacher,
        classroomId: classroomId,
        gender: gender,
        dob: dob,
        address: address,
        emergencyContact: emergencyContact,
        needsTransport: needsTransport,
        hasTransportDetails: hasTransportDetails ?? this.hasTransportDetails,
        documentCount: documentCount ?? this.documentCount,
      );

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? fullName : parts.first;
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      schoolId: json['school_id'],
      admissionNo: json['admission_no'],
      rollNo: json['roll_no'] ?? '',
      fullName: json['full_name'],
      photoUrl: json['photo_url'],
      className: json['class_name'] ?? '',
      sectionName: json['section_name'] ?? '',
      academicYear: json['academic_year'] ?? '2026–27',
      bloodGroup: json['blood_group'],
      classTeacher: json['class_teacher'],
      classroomId: json['classroom_id'] ?? '',
      gender: json['gender'],
      address: json['address'],
      emergencyContact: json['emergency_contact'],
      needsTransport: json['needs_transport'],
    );
  }
}
