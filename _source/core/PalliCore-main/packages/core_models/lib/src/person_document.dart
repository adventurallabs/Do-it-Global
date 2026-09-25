import 'package:json_annotation/json_annotation.dart';

part 'person_document.g.dart';

/// Whose file a document belongs to.
enum DocumentOwner {
  @JsonValue('student')
  student,
  @JsonValue('teacher')
  teacher,
}

/// What kind of paper it is. Free-form `other` exists because a school will
/// always have one more form than any list anticipated.
enum DocumentKind {
  @JsonValue('birth_certificate')
  birthCertificate,
  @JsonValue('transfer_certificate')
  transferCertificate,
  @JsonValue('id_proof')
  idProof,
  @JsonValue('address_proof')
  addressProof,
  @JsonValue('medical')
  medical,
  @JsonValue('marksheet')
  marksheet,
  @JsonValue('qualification')
  qualification,
  @JsonValue('other')
  other;

  String get label => switch (this) {
        DocumentKind.birthCertificate => 'Birth certificate',
        DocumentKind.transferCertificate => 'Transfer certificate',
        DocumentKind.idProof => 'ID proof',
        DocumentKind.addressProof => 'Address proof',
        DocumentKind.medical => 'Medical record',
        DocumentKind.marksheet => 'Mark sheet',
        DocumentKind.qualification => 'Qualification',
        DocumentKind.other => 'Other document',
      };

  /// What a family is normally asked for.
  static const forStudents = [
    DocumentKind.birthCertificate,
    DocumentKind.transferCertificate,
    DocumentKind.idProof,
    DocumentKind.addressProof,
    DocumentKind.medical,
    DocumentKind.other,
  ];

  static const forTeachers = [
    DocumentKind.qualification,
    DocumentKind.idProof,
    DocumentKind.addressProof,
    DocumentKind.marksheet,
    DocumentKind.other,
  ];
}

/// One file on a person's record.
///
/// The bucket behind these is private — [fileUrl] is a path, not something a
/// browser can open on its own, and a short-lived signed link is minted when
/// somebody actually asks to see it.
@JsonSerializable(fieldRename: FieldRename.snake)
class PersonDocument {
  final String id;
  final DocumentOwner ownerType;
  final String ownerId;

  @JsonKey(unknownEnumValue: DocumentKind.other)
  final DocumentKind kind;

  /// What the uploader called it. Falls back to the kind's own name.
  @JsonKey(defaultValue: '')
  final String label;

  final String fileUrl;

  /// Path inside the bucket — what a signed link is minted from.
  @JsonKey(defaultValue: '')
  final String filePath;

  @JsonKey(defaultValue: '')
  final String mimeType;

  @JsonKey(defaultValue: 0)
  final int sizeBytes;

  final String? uploadedBy;
  final DateTime? uploadedAt;

  const PersonDocument({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    this.kind = DocumentKind.other,
    this.label = '',
    required this.fileUrl,
    this.filePath = '',
    this.mimeType = '',
    this.sizeBytes = 0,
    this.uploadedBy,
    this.uploadedAt,
  });

  String get displayName => label.trim().isEmpty ? kind.label : label.trim();

  bool get isPdf => mimeType.contains('pdf');

  String get sizeLabel {
    if (sizeBytes <= 0) return '';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory PersonDocument.fromJson(Map<String, dynamic> json) =>
      _$PersonDocumentFromJson(json);
  Map<String, dynamic> toJson() => _$PersonDocumentToJson(this);
}
