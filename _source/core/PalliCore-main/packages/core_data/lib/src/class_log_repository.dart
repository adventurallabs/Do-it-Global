import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class ClassLogRepository extends BaseRepository<ClassLog> {
  ClassLogRepository(SupabaseClient client) : super(client, 'class_logs');

  static final List<ClassLog> _items = [];

  @override
  Future<List<ClassLog>> getAll() {
    return remoteOrLocal(
      () async {
        final response = await client.from(tableName).select();
        final remote = (response as List)
            .map((j) => ClassLog.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _items
          ..clear()
          ..addAll(remote);
        return List<ClassLog>.from(_items);
      },
      () => List<ClassLog>.from(_items),
    );
  }

  @override
  Future<ClassLog?> getById(String id) async {
    try {
      return _items.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(ClassLog item) {
    return writeLocalThenRemote(() {
      final index = _items.indexWhere((c) => c.id == item.id);
      if (index >= 0) {
        _items[index] = item;
      } else {
        _items.add(item);
      }
    }, () => client.from(tableName).upsert(item.toJson()));
  }

  @override
  Future<void> delete(String id) {
    return writeLocalThenRemote(
      () => _items.removeWhere((c) => c.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }

  /// One local day's logs, filtered in the database. The table grows by
  /// every period of every class each day, so a full read soon exceeds the
  /// API's 1000-row cap and silently drops today's rows.
  Future<List<ClassLog>> getForDay(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return remoteOrLocal(
      () async {
        final rows = await client
            .from(tableName)
            .select()
            .gte('start_time', start.toUtc().toIso8601String())
            .lt('start_time', end.toUtc().toIso8601String());
        final list = (rows as List)
            .map((j) => ClassLog.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        for (final item in list) {
          final i = _items.indexWhere((c) => c.id == item.id);
          if (i >= 0) {
            _items[i] = item;
          } else {
            _items.add(item);
          }
        }
        return list;
      },
      () => _items.where((c) => _sameDay(c.startTime.toLocal(), date)).toList(),
    );
  }

  Future<ClassLog?> getForPeriodAndDate(String periodId, DateTime date) async {
    final day = await getForDay(date);
    for (final c in day) {
      if (c.periodId == periodId) return c;
    }
    return null;
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
