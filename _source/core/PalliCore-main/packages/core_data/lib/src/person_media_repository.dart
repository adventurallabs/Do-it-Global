import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'remote_sync.dart';

/// Photos and documents for a child or a member of staff.
///
/// Two buckets, two different rules. A face is public-read because it appears
/// in class lists and on a parent's home screen, and a signed link per row
/// would be a round trip per face. A birth certificate is not: that bucket is
/// private, and reading one mints a short-lived signed link instead.
class PersonMediaRepository {
  final SupabaseClient client;

  PersonMediaRepository(this.client);

  static const photoBucket = 'person-photos';
  static const documentBucket = 'person-documents';

  /// How long a document link stays good. Long enough to open and read,
  /// short enough that a screenshot of the URL is worth nothing tomorrow.
  static const signedLinkLifetime = Duration(minutes: 10);

  static int _seq = 0;

  static String _newId(String prefix) {
    _seq = (_seq + 1) & 0xFFFFF;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '_${_seq.toRadixString(36)}';
  }

  // ---------------------------------------------------------------- photo --

  /// Uploads a face and returns its public URL.
  ///
  /// The path carries a timestamp so replacing a photo yields a new URL —
  /// reusing the path would leave every cached copy showing the old one.
  Future<String> uploadPhoto({
    required DocumentOwner ownerType,
    required String ownerId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final ext = extension.replaceAll('.', '').toLowerCase();
    final path = '${ownerType.name}/$ownerId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await client.storage.from(photoBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _mimeFor(ext), upsert: true),
        );
    return client.storage.from(photoBucket).getPublicUrl(path);
  }

  // ------------------------------------------------------------ documents --

  Future<List<PersonDocument>> documents({
    required DocumentOwner ownerType,
    required String ownerId,
  }) async {
    final rows = await client
        .from('person_documents')
        .select()
        .eq('owner_type', ownerType.name)
        .eq('owner_id', ownerId)
        .order('uploaded_at', ascending: false)
        .timeout(kRemoteTimeout);
    return (rows as List)
        .map((j) => PersonDocument.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
  }

  /// How many documents each of these people has — one query for a whole
  /// list, so a directory can flag incomplete files without N round trips.
  Future<Map<String, int>> documentCounts({
    required DocumentOwner ownerType,
    required List<String> ownerIds,
  }) async {
    if (ownerIds.isEmpty) return const {};
    final rows = await client
        .from('person_documents')
        .select('owner_id')
        .eq('owner_type', ownerType.name)
        .inFilter('owner_id', ownerIds)
        .timeout(kRemoteTimeout);
    final counts = <String, int>{};
    for (final r in rows as List) {
      final id = (r as Map)['owner_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<PersonDocument> addDocument({
    required DocumentOwner ownerType,
    required String ownerId,
    required DocumentKind kind,
    required String label,
    required Uint8List bytes,
    required String fileName,
    String? uploadedBy,
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'bin';
    // The owner id leads the path: the storage policy checks that first
    // folder to decide whether a parent may put a file here at all.
    final path = '$ownerId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final mime = _mimeFor(ext);

    await client.storage.from(documentBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );

    final row = {
      'id': _newId('doc'),
      'owner_type': ownerType.name,
      'owner_id': ownerId,
      'kind': _kindValue(kind),
      'label': label.trim(),
      // Not a usable link on its own — the bucket is private. Kept so the
      // row is self-describing; `signedUrl` is what opens it.
      'file_url': path,
      'file_path': path,
      'mime_type': mime,
      'size_bytes': bytes.lengthInBytes,
      'uploaded_by': uploadedBy ?? client.auth.currentUser?.id,
    };

    try {
      final saved = await client
          .from('person_documents')
          .insert(row)
          .select()
          .single()
          .timeout(kRemoteTimeout);
      return PersonDocument.fromJson(Map<String, dynamic>.from(saved));
    } catch (e) {
      // Do not leave the file behind with no row pointing at it.
      try {
        await client.storage.from(documentBucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  /// A link that opens the file, good for [signedLinkLifetime].
  Future<String> signedUrl(PersonDocument document) {
    final path = document.filePath.isNotEmpty ? document.filePath : document.fileUrl;
    return client.storage
        .from(documentBucket)
        .createSignedUrl(path, signedLinkLifetime.inSeconds);
  }

  Future<void> deleteDocument(PersonDocument document) async {
    await client.from('person_documents').delete().eq('id', document.id).timeout(kRemoteTimeout);
    final path = document.filePath.isNotEmpty ? document.filePath : document.fileUrl;
    try {
      await client.storage.from(documentBucket).remove([path]);
    } catch (_) {
      // The row is gone, which is what the person asked for. An orphaned
      // object is tidy-up, not a failure to report.
    }
  }

  // ------------------------------------------------------------ transport --

  Future<StudentTransport?> transport(String studentId) async {
    final row = await client
        .from('student_transport')
        .select()
        .eq('student_id', studentId)
        .maybeSingle()
        .timeout(kRemoteTimeout);
    return row == null ? null : StudentTransport.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Map<String, StudentTransport>> transportFor(List<String> studentIds) async {
    if (studentIds.isEmpty) return const {};
    final rows = await client
        .from('student_transport')
        .select()
        .inFilter('student_id', studentIds)
        .timeout(kRemoteTimeout);
    return {
      for (final r in rows as List)
        (r as Map)['student_id'] as String:
            StudentTransport.fromJson(Map<String, dynamic>.from(r)),
    };
  }

  Future<void> saveTransport(StudentTransport transport) async {
    await client.from('student_transport').upsert({
      'student_id': transport.studentId,
      'bus_id': transport.busId,
      'pickup_location': transport.pickupLocation,
      'drop_location': transport.dropLocation,
      'route_id': transport.routeId,
      'stop_id': transport.stopId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'student_id').timeout(kRemoteTimeout);
  }

  /// Called when a family says the child does not travel by bus — the row
  /// goes rather than lingering as a half-answer.
  Future<void> clearTransport(String studentId) async {
    await client
        .from('student_transport')
        .delete()
        .eq('student_id', studentId)
        .timeout(kRemoteTimeout);
  }

  static String _kindValue(DocumentKind kind) => switch (kind) {
        DocumentKind.birthCertificate => 'birth_certificate',
        DocumentKind.transferCertificate => 'transfer_certificate',
        DocumentKind.idProof => 'id_proof',
        DocumentKind.addressProof => 'address_proof',
        DocumentKind.medical => 'medical',
        DocumentKind.marksheet => 'marksheet',
        DocumentKind.qualification => 'qualification',
        DocumentKind.other => 'other',
      };

  static String _mimeFor(String ext) => switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };

  static String describeError(Object error) {
    if (error is StorageException) {
      final message = error.message.trim();
      if (message.toLowerCase().contains('exceeded the maximum allowed size')) {
        return 'That file is too large. Photos go up to 5 MB, documents up to 10 MB.';
      }
      if (message.toLowerCase().contains('mime type')) {
        return 'That file type is not accepted. Use a JPG, PNG or PDF.';
      }
      if (message.isNotEmpty) return message;
    }
    if (error is PostgrestException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    final text = error.toString();
    if (text.contains('TimeoutException') || text.contains('SocketException')) {
      return "Couldn't reach the school server. Check your connection and try again.";
    }
    return 'Something went wrong. Please try again.';
  }
}
