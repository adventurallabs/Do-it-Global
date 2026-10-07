import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models.dart' show Json;

/// Assessment changes the server hasn't accepted yet (no network, or a save refused), kept on this device so
/// they survive the app closing. Written only when a save fails, deleted the moment one succeeds, and never
/// kept longer than [maxAge]. Lives in the app's private support folder (not shared storage, not the web's
/// localStorage); on the web nothing is kept and unsynced changes live only in memory.
class PendingAssessments {
  PendingAssessments._();

  static const maxAge = Duration(days: 30);

  static final _locks = <String, Future<void>>{};

  /// Runs [job] when no other job for assessment [id] is running (sending kept changes, or opening it and
  /// recovering them), so the same changes are never sent twice.
  static Future<T> exclusive<T>(String id, Future<T> Function() job) {
    final before = _locks[id] ?? Future.value();
    final run = before.then((_) => job(), onError: (_) => job());
    final done = run.then((_) {}, onError: (_) {});
    _locks[id] = done;
    done.whenComplete(() {
      if (identical(_locks[id], done)) _locks.remove(id);
    });
    return run;
  }

  @visibleForTesting
  static Directory? folderOverride;

  static Future<Directory?> _folder() async {
    if (kIsWeb) return null;
    try {
      final base = folderOverride ?? await getApplicationSupportDirectory();
      final dir = Directory('${base.path}${Platform.pathSeparator}nuvara_assessments');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (_) {
      return null;
    }
  }

  static String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '');
  static File _file(Directory dir, String userId, String id) => File('${dir.path}${Platform.pathSeparator}${_safe(userId)}__${_safe(id)}.json');

  /// Keeps [payload] for [id], made on top of server revision [rev].
  static Future<void> write(String userId, String id, int rev, Json payload) async {
    final dir = await _folder();
    if (dir == null) return;
    try {
      final f = _file(dir, userId, id);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode({'user_id': userId, 'id': id, 'rev': rev, 'saved_at': DateTime.now().toUtc().toIso8601String(), 'payload': payload}), flush: true);
      await tmp.rename(f.path);
    } catch (_) {/* best effort: the changes are still in memory and retried */}
  }

  /// The unsynced changes for [id], or null.
  static Future<({int rev, DateTime savedAt, Json payload})?> read(String userId, String id) async {
    final dir = await _folder();
    if (dir == null) return null;
    final f = _file(dir, userId, id);
    try {
      if (!await f.exists()) return null;
      final m = jsonDecode(await f.readAsString()) as Json;
      final at = DateTime.tryParse('${m['saved_at']}');
      if (m['user_id'] != userId || m['id'] != id || at == null || DateTime.now().difference(at) > maxAge) {
        await f.delete();
        return null;
      }
      return (rev: (m['rev'] as num).toInt(), savedAt: at.toLocal(), payload: (m['payload'] as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  static Future<void> remove(String userId, String id) async {
    final dir = await _folder();
    if (dir == null) return;
    try {
      final f = _file(dir, userId, id);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Assessment ids with unsynced changes for [userId].
  static Future<List<String>> ids(String userId) async {
    final dir = await _folder();
    if (dir == null) return const [];
    final prefix = '${_safe(userId)}__';
    try {
      return [
        await for (final e in dir.list())
          if (e is File && e.uri.pathSegments.last.startsWith(prefix) && e.path.endsWith('.json')) e.uri.pathSegments.last.substring(prefix.length).replaceAll('.json', ''),
      ];
    } catch (_) {
      return const [];
    }
  }
}
