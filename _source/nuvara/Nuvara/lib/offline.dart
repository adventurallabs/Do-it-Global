import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthRetryableFetchException, PostgrestException, RealtimeSubscribeException;

import 'models.dart';
import 'util.dart';

/// A small, per-login copy of what each person needs to see when the network is down: their profile, the
/// centre's lists, this week (plus next, and last for therapists), recent bills and anything still owed,
/// recent messages and open requests. Nothing older or bulkier is kept.
///
/// Where: the app's private cache folder. Android never copies it into backups and the OS may clear it, so
/// it's a cache in the strict sense: losing it only means the next offline start shows less.
/// How long: 14 days at most, and it's deleted when that login signs out.
class OfflineCache {
  OfflineCache._();

  /// Bumped when the snapshot's shape changes; older files are ignored and replaced.
  static const version = 1;
  static const maxAge = Duration(days: 14);

  /// Above this the snapshot is trimmed further (fewer messages and bills) before it's written.
  static const maxBytes = 600 * 1024;

  /// Tests point this at a temporary folder; null uses the platform cache folder.
  @visibleForTesting
  static Directory? folderOverride;

  static Future<Directory?> _folder() async {
    if (kIsWeb) return null;
    try {
      final base = folderOverride ?? await getApplicationCacheDirectory();
      final dir = Directory('${base.path}${Platform.pathSeparator}nuvara_offline');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (_) {
      return null;
    }
  }

  // Login ids are UUIDs; anything else is reduced to safe file-name characters.
  static String _name(String userId) => '${userId.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '')}.json';

  /// The saved snapshot for [userId], or null when there is none, it's too old or it can't be read.
  static Future<Json?> read(String userId) async {
    final dir = await _folder();
    if (dir == null) return null;
    final f = File('${dir.path}${Platform.pathSeparator}${_name(userId)}');
    try {
      if (!await f.exists()) return null;
      final data = jsonDecode(await f.readAsString()) as Json;
      final saved = DateTime.tryParse('${data['saved_at']}');
      if (data['v'] != version || data['user_id'] != userId || saved == null || DateTime.now().difference(saved) > maxAge) {
        await f.delete();
        return null;
      }
      return data;
    } catch (_) {
      // Unreadable (cut short, or an older shape): drop it rather than show half the data.
      try {
        await f.delete();
      } catch (_) {}
      return null;
    }
  }

  /// Writes [data] for [userId]. The file is replaced in one step, so a crash mid-write never leaves half a
  /// snapshot behind. Best effort: failing to save never affects the app.
  static Future<void> write(String userId, Json data) async {
    final dir = await _folder();
    if (dir == null) return;
    try {
      final text = encode(data);
      if (text == null) return;
      final f = File('${dir.path}${Platform.pathSeparator}${_name(userId)}');
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(text, flush: true);
      await tmp.rename(f.path);
    } catch (_) {}
  }

  /// Deletes [userId]'s snapshot (signing out of that login).
  static Future<void> remove(String userId) async {
    final dir = await _folder();
    if (dir == null) return;
    try {
      final f = File('${dir.path}${Platform.pathSeparator}${_name(userId)}');
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Deletes every snapshot on this device (signing out everywhere).
  static Future<void> clear() async {
    final dir = await _folder();
    if (dir == null) return;
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// [data] as JSON, trimmed until it fits [maxBytes]; null if even the leanest form doesn't fit.
  @visibleForTesting
  static String? encode(Json data) {
    var text = jsonEncode(data);
    for (final level in const [1, 2, 3]) {
      if (utf8.encode(text).length <= maxBytes) return text;
      text = jsonEncode(shrink(data, level));
    }
    return utf8.encode(text).length <= maxBytes ? text : null;
  }

  /// Leaner copies of a snapshot, from 1 (fewer messages) to 3 (only what's owed and the next sessions).
  @visibleForTesting
  static Json shrink(Json data, int level) {
    final out = Json.of(data);
    List<Json> rows(String key) => ((out[key] as List?) ?? const []).cast<Json>();
    out['messages'] = lastPerThread(rows('messages'), level == 1 ? 15 : 5);
    out['payments'] = rows('payments').take(level == 1 ? 15 : 5).toList();
    if (level >= 2) out['progress'] = <String, dynamic>{};
    if (level >= 3) {
      out['fees'] = [for (final w in rows('fees')) if (FeeWeek(w).due > 0) w];
      final weeks = Json.from((out['weeks'] as Map?) ?? const {});
      final thisWeek = weekStart(todayISO());
      out['weeks'] = {for (final e in weeks.entries) if (e.key == thisWeek) e.key: e.value};
    }
    return out;
  }

  /// The newest [n] messages of each conversation, oldest first like the store keeps them.
  static List<Json> lastPerThread(List<Json> messages, int n) {
    final count = <String, int>{};
    final keep = <Json>[];
    for (final m in messages.reversed) {
      final thread = '${m['child_id'] ?? ''}|${m['therapist_id'] ?? ''}';
      final c = count[thread] = (count[thread] ?? 0) + 1;
      if (c <= n) keep.add(m);
    }
    return keep.reversed.toList();
  }
}

/// When the shown data was saved, for the offline banner: "10:42 AM" today, else "Fri 2 Oct, 10:42 AM".
String savedAtLabel(DateTime at) {
  final local = at.toLocal();
  final time = fmtTime('${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}');
  final day = iso(local);
  if (day == todayISO()) return time;
  if (day == addDays(todayISO(), -1)) return 'yesterday, $time';
  return '${fmtDate(day, 'EEE, d MMM')}, $time';
}

/// True when [e] means the server couldn't be reached (no network, DNS, TLS, timeout), as opposed to the
/// server answering with an error. Only these switch the app to its saved data.
bool isNetworkError(Object e) {
  if (e is SocketException || e is HandshakeException || e is TimeoutException || e is HttpException) return true;
  if (e is AuthRetryableFetchException || e is RealtimeSubscribeException) return true;
  final text = e is PostgrestException ? '${e.message} ${e.details ?? ''}' : '$e';
  return RegExp(r'SocketException|ClientException|Failed host lookup|Connection (refused|reset|closed|timed out)|Network is unreachable|XMLHttpRequest error', caseSensitive: false).hasMatch(text);
}
