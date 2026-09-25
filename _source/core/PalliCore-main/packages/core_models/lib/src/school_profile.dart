import 'package:json_annotation/json_annotation.dart';

part 'school_profile.g.dart';

/// The school's own identity: what it is called and what its crest looks like.
///
/// Certificates carry both, and a certificate with a placeholder name on it is
/// worse than no certificate — so [isReadyForCertificates] is the gate the
/// admin has to pass before any layout can be published.
@JsonSerializable(fieldRename: FieldRename.snake)
class SchoolProfile {
  /// Single-row table; the key is a constant `true`.
  @JsonKey(includeToJson: false, includeFromJson: false)
  final bool id;

  final String name;
  final String logoUrl;
  final String primaryColorHex;
  final String accentColorHex;
  final String? address;
  final String? phone;
  final String? email;
  final String? academicSessionLabel;

  /// The mark below which the school wants a child's attendance flagged.
  /// Read rather than hard-coded, because 85 is this school's number, not a
  /// universal one.
  @JsonKey(defaultValue: 85)
  final int attendanceWarningThreshold;

  const SchoolProfile({
    this.id = true,
    this.name = '',
    this.logoUrl = '',
    this.primaryColorHex = '#2F6BFF',
    this.accentColorHex = '#C9A227',
    this.address,
    this.phone,
    this.email,
    this.academicSessionLabel,
    this.attendanceWarningThreshold = 85,
  });

  /// The default row ships with "Your School" in it, which is a placeholder,
  /// not a name — treat it as unset.
  bool get hasName {
    final n = name.trim();
    return n.isNotEmpty && n.toLowerCase() != 'your school';
  }

  bool get hasLogo => logoUrl.trim().isNotEmpty;

  /// Certificates need both. Neither can be faked from elsewhere: the crest is
  /// a file only the admin can upload, and the name is what parents will read
  /// at the top of their child's award.
  bool get isReadyForCertificates => hasName && hasLogo;

  List<String> get missingForCertificates => [
        if (!hasName) 'school name',
        if (!hasLogo) 'school logo',
      ];

  factory SchoolProfile.fromJson(Map<String, dynamic> json) => _$SchoolProfileFromJson(json);
  Map<String, dynamic> toJson() => _$SchoolProfileToJson(this);

  SchoolProfile copyWith({String? name, String? logoUrl}) => SchoolProfile(
        id: id,
        name: name ?? this.name,
        logoUrl: logoUrl ?? this.logoUrl,
        primaryColorHex: primaryColorHex,
        accentColorHex: accentColorHex,
        address: address,
        phone: phone,
        email: email,
        academicSessionLabel: academicSessionLabel,
        attendanceWarningThreshold: attendanceWarningThreshold,
      );
}
