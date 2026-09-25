// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PersonDocument _$PersonDocumentFromJson(Map<String, dynamic> json) =>
    PersonDocument(
      id: json['id'] as String,
      ownerType: $enumDecode(_$DocumentOwnerEnumMap, json['owner_type']),
      ownerId: json['owner_id'] as String,
      kind:
          $enumDecodeNullable(
            _$DocumentKindEnumMap,
            json['kind'],
            unknownValue: DocumentKind.other,
          ) ??
          DocumentKind.other,
      label: json['label'] as String? ?? '',
      fileUrl: json['file_url'] as String,
      filePath: json['file_path'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      uploadedBy: json['uploaded_by'] as String?,
      uploadedAt: json['uploaded_at'] == null
          ? null
          : DateTime.parse(json['uploaded_at'] as String),
    );

Map<String, dynamic> _$PersonDocumentToJson(PersonDocument instance) =>
    <String, dynamic>{
      'id': instance.id,
      'owner_type': _$DocumentOwnerEnumMap[instance.ownerType]!,
      'owner_id': instance.ownerId,
      'kind': _$DocumentKindEnumMap[instance.kind]!,
      'label': instance.label,
      'file_url': instance.fileUrl,
      'file_path': instance.filePath,
      'mime_type': instance.mimeType,
      'size_bytes': instance.sizeBytes,
      'uploaded_by': instance.uploadedBy,
      'uploaded_at': instance.uploadedAt?.toIso8601String(),
    };

const _$DocumentOwnerEnumMap = {
  DocumentOwner.student: 'student',
  DocumentOwner.teacher: 'teacher',
};

const _$DocumentKindEnumMap = {
  DocumentKind.birthCertificate: 'birth_certificate',
  DocumentKind.transferCertificate: 'transfer_certificate',
  DocumentKind.idProof: 'id_proof',
  DocumentKind.addressProof: 'address_proof',
  DocumentKind.medical: 'medical',
  DocumentKind.marksheet: 'marksheet',
  DocumentKind.qualification: 'qualification',
  DocumentKind.other: 'other',
};
