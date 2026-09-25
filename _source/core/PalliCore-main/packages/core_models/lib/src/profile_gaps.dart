import 'student.dart';
import 'teacher.dart';

/// Who is expected to supply a missing detail.
enum GapOwner {
  /// The family knows it; the app should ask them.
  family,

  /// Only the office can answer — a fee, a class, a joining date.
  office,
}

/// How much it matters that this is still blank.
enum GapWeight {
  /// Someone could be hurt by its absence. A blood group and an emergency
  /// number are the difference between a phone call and a guess.
  critical,

  /// Wanted, but nothing breaks today.
  standard,
}

/// One detail nobody has filled in.
class ProfileGap {
  /// Stable key, so a screen can route to the right field.
  final String field;

  /// What to call it in front of a parent.
  final String label;

  /// A sentence asking for it.
  final String ask;

  final GapOwner owner;
  final GapWeight weight;

  const ProfileGap({
    required this.field,
    required this.label,
    required this.ask,
    this.owner = GapOwner.family,
    this.weight = GapWeight.standard,
  });

  bool get isCritical => weight == GapWeight.critical;
}

/// What is still missing from a child's file.
///
/// Admission takes what the parent has on them that morning, which is rarely
/// everything — so the rest is optional at the desk and chased afterwards.
/// This is the single list both sides read from: the admin's profile marks
/// each one as still needed, and the parent's app asks for exactly the ones
/// they can answer. Two lists would have disagreed within a month.
class StudentProfileGaps {
  final List<ProfileGap> gaps;

  const StudentProfileGaps(this.gaps);

  bool get isComplete => gaps.isEmpty;

  int get criticalCount => gaps.where((g) => g.isCritical).length;

  /// Just the ones a family can actually answer — what the parent app asks.
  List<ProfileGap> get forFamily =>
      gaps.where((g) => g.owner == GapOwner.family).toList();

  List<ProfileGap> get forOffice =>
      gaps.where((g) => g.owner == GapOwner.office).toList();

  /// A sentence for the admin's list, or null when the file is complete.
  String? get summary {
    if (gaps.isEmpty) return null;
    final names = gaps.map((g) => g.label.toLowerCase()).toList();
    if (names.length == 1) return 'Still needed: ${names.single}';
    if (names.length <= 3) {
      return 'Still needed: ${names.take(names.length - 1).join(', ')} and ${names.last}';
    }
    return 'Still needed: ${names.take(2).join(', ')} and ${names.length - 2} more';
  }

  static bool _blank(String? value) => value == null || value.trim().isEmpty;

  /// The same rule, from plain values.
  ///
  /// PalliConnect holds its own `Student` shape, and the one thing that must
  /// not differ between the two apps is *which* details are still owed — a
  /// parent asked for something the admin does not show as missing is how
  /// trust in the list goes. So the logic lives here once and both call it.
  static StudentProfileGaps fromValues({
    String? photoUrl,
    String? gender,
    String? bloodGroup,
    DateTime? dob,
    String? emergencyContact,
    String? address,
    bool? needsTransport,
    bool hasTransportDetails = false,
    int documentCount = 0,
  }) {
    return _build(
      photoUrl: photoUrl,
      hasGender: gender != null && gender.trim().isNotEmpty,
      bloodGroup: bloodGroup,
      dob: dob,
      emergencyContact: emergencyContact,
      address: address,
      needsTransport: needsTransport,
      hasTransportDetails: hasTransportDetails,
      documentCount: documentCount,
    );
  }

  /// [hasTransportDetails] is true once a bus and the two addresses are on
  /// record; it is only asked for when the family has said they need transport.
  static StudentProfileGaps of(
    Student student, {
    bool hasTransportDetails = false,
    int documentCount = 0,
  }) {
    return _build(
      photoUrl: student.photoUrl,
      hasGender: student.gender != null,
      bloodGroup: student.bloodGroup,
      dob: student.dob,
      emergencyContact: student.emergencyContact,
      address: student.address,
      needsTransport: student.needsTransport,
      hasTransportDetails: hasTransportDetails,
      documentCount: documentCount,
    );
  }

  static StudentProfileGaps _build({
    required String? photoUrl,
    required bool hasGender,
    required String? bloodGroup,
    required DateTime? dob,
    required String? emergencyContact,
    required String? address,
    required bool? needsTransport,
    required bool hasTransportDetails,
    required int documentCount,
  }) {
    return StudentProfileGaps([
      if (_blank(photoUrl))
        const ProfileGap(
          field: 'photoUrl',
          label: 'Photo',
          ask: "Add a photo of your child so staff can recognise them.",
        ),
      if (!hasGender)
        const ProfileGap(
          field: 'gender',
          label: 'Gender',
          ask: "Tell us your child's gender for the school register.",
        ),
      if (_blank(bloodGroup))
        const ProfileGap(
          field: 'bloodGroup',
          label: 'Blood group',
          ask: "Add your child's blood group — the school needs it in an emergency.",
          weight: GapWeight.critical,
        ),
      if (dob == null)
        const ProfileGap(
          field: 'dob',
          label: 'Date of birth',
          ask: "Add your child's date of birth.",
        ),
      if (_blank(emergencyContact))
        const ProfileGap(
          field: 'emergencyContact',
          label: 'Emergency contact',
          ask: 'Add a number the school can call if we cannot reach you.',
          weight: GapWeight.critical,
        ),
      if (_blank(address))
        const ProfileGap(
          field: 'address',
          label: 'Home address',
          ask: 'Add your home address.',
        ),
      if (needsTransport == null)
        const ProfileGap(
          field: 'needsTransport',
          label: 'Transport',
          ask: 'Does your child travel on the school bus? Let us know either way.',
        ),
      // Only chased once they have said yes. Asking a walker for a bus stop
      // is how a form loses someone's patience.
      if (needsTransport == true && !hasTransportDetails)
        const ProfileGap(
          field: 'transportDetails',
          label: 'Bus and stop',
          ask: 'Tell us the bus and where your child is picked up and dropped.',
          owner: GapOwner.office,
        ),
      if (documentCount == 0)
        const ProfileGap(
          field: 'documents',
          label: 'Documents',
          ask: "Upload your child's birth certificate or other records.",
        ),
    ]);
  }
}

/// The same idea for a member of staff. Everything here is the office's to
/// fill in — a teacher does not chase their own file.
class TeacherProfileGaps {
  final List<ProfileGap> gaps;

  const TeacherProfileGaps(this.gaps);

  bool get isComplete => gaps.isEmpty;

  int get criticalCount => gaps.where((g) => g.isCritical).length;

  String? get summary {
    if (gaps.isEmpty) return null;
    final names = gaps.map((g) => g.label.toLowerCase()).toList();
    if (names.length == 1) return 'Still needed: ${names.single}';
    if (names.length <= 3) {
      return 'Still needed: ${names.take(names.length - 1).join(', ')} and ${names.last}';
    }
    return 'Still needed: ${names.take(2).join(', ')} and ${names.length - 2} more';
  }

  static bool _blank(String? value) => value == null || value.trim().isEmpty;

  static TeacherProfileGaps of(Teacher teacher, {int documentCount = 0}) {
    return TeacherProfileGaps([
      if (_blank(teacher.photoUrl))
        const ProfileGap(
          field: 'photoUrl',
          label: 'Photo',
          ask: 'Add a staff photo.',
          owner: GapOwner.office,
        ),
      if (teacher.gender == null)
        const ProfileGap(
          field: 'gender',
          label: 'Gender',
          ask: 'Record their gender for the staff register.',
          owner: GapOwner.office,
        ),
      if (teacher.dob == null)
        const ProfileGap(
          field: 'dob',
          label: 'Date of birth',
          ask: 'Record their date of birth.',
          owner: GapOwner.office,
        ),
      if (_blank(teacher.emergencyContact))
        const ProfileGap(
          field: 'emergencyContact',
          label: 'Emergency contact',
          ask: 'Add a number to call if something happens at school.',
          owner: GapOwner.office,
          weight: GapWeight.critical,
        ),
      if (_blank(teacher.address))
        const ProfileGap(
          field: 'address',
          label: 'Address',
          ask: 'Record their address.',
          owner: GapOwner.office,
        ),
      if (documentCount == 0)
        const ProfileGap(
          field: 'documents',
          label: 'Documents',
          ask: 'Upload their certificates or ID.',
          owner: GapOwner.office,
        ),
    ]);
  }
}
