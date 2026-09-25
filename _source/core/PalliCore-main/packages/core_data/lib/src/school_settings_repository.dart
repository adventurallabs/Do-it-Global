import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'remote_sync.dart';

/// The school's name and crest — one row, read by every app and written only
/// from the admin's home screen.
class SchoolSettingsRepository {
  final SupabaseClient client;

  SchoolSettingsRepository(this.client);

  static const bucket = 'school-branding';

  SchoolProfile? _cached;

  /// The last profile read in this session. Screens that only need to know
  /// whether certificates are unlocked can ask without a round trip.
  SchoolProfile? get cached => _cached;

  Future<SchoolProfile> get() async {
    final row = await client
        .from('school_settings')
        .select()
        .maybeSingle()
        .timeout(kRemoteTimeout);
    final profile = row == null
        ? const SchoolProfile()
        : SchoolProfile.fromJson(Map<String, dynamic>.from(row));
    _cached = profile;
    return profile;
  }

  Future<void> saveName(String name) async {
    await client
        .from('school_settings')
        .update({'name': name.trim(), 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', true)
        .timeout(kRemoteTimeout);
    _cached = _cached?.copyWith(name: name.trim());
  }

  /// Uploads a crest and points the school at it.
  ///
  /// The path carries a timestamp so a replaced logo is a new URL — the old
  /// one sits in a hundred cached certificates and image caches, and reusing
  /// the path would leave them showing the previous school's mark.
  Future<String> uploadLogo({required Uint8List bytes, required String extension}) async {
    final ext = extension.replaceAll('.', '').toLowerCase();
    final path = 'logo/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _mimeFor(ext),
            upsert: true,
          ),
        );
    final url = client.storage.from(bucket).getPublicUrl(path);
    await client
        .from('school_settings')
        .update({'logo_url': url, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', true)
        .timeout(kRemoteTimeout);
    _cached = _cached?.copyWith(logoUrl: url);
    return url;
  }

  static String _mimeFor(String ext) => switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'svg' => 'image/svg+xml',
        _ => 'application/octet-stream',
      };
}
