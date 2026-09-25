import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class StaffAttendanceRepository extends BaseRepository<StaffAttendance> {
  StaffAttendanceRepository(SupabaseClient client) : super(client, 'staff_attendance');

  /// Offline cache of rows this session has read or written — never
  /// made-up staff.
  static final List<StaffAttendance> _items = [];

  @override
  Future<List<StaffAttendance>> getAll() {
    return remoteOrLocal(
      () async {
        final response = await client.from(tableName).select();
        final remote = (response as List)
            .map((j) =>
                StaffAttendance.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _items
          ..clear()
          ..addAll(remote);
        return List<StaffAttendance>.from(_items);
      },
      () => List<StaffAttendance>.from(_items),
    );
  }

  /// One day, filtered in the database (a full read hits the API's
  /// 1000-row cap within months and silently drops newer days).
  Future<List<StaffAttendance>> getByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return remoteOrLocal(
      () async {
        final rows = await client
            .from(tableName)
            .select()
            .gte('date', start.toUtc().toIso8601String())
            .lt('date', end.toUtc().toIso8601String());
        final list = (rows as List)
            .map((j) => StaffAttendance.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        for (final item in list) {
          final i = _items.indexWhere((a) => a.id == item.id);
          if (i >= 0) {
            _items[i] = item;
          } else {
            _items.add(item);
          }
        }
        return list;
      },
      () => _items.where((a) => GradeCatalog.sameDay(a.date, date)).toList(),
    );
  }

  /// A span of days — the staff attendance charts and one teacher's history.
  Future<List<StaffAttendance>> getBetween(DateTime from, DateTime to, {String? staffId}) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));
    try {
      var q = client
          .from(tableName)
          .select()
          .gte('date', start.toUtc().toIso8601String())
          .lt('date', end.toUtc().toIso8601String());
      if (staffId != null) q = q.eq('staff_id', staffId);
      final rows = await q.order('date');
      return (rows as List)
          .map((j) => StaffAttendance.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    } catch (_) {
      return _items
          .where((a) =>
              !a.date.isBefore(start) &&
              a.date.isBefore(end) &&
              (staffId == null || a.staffId == staffId))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    }
  }

  @override
  Future<StaffAttendance?> getById(String id) async {
    try {
      return _items.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(StaffAttendance item) {
    return writeLocalThenRemote(() {
      final index = _items.indexWhere((a) => a.id == item.id);
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
      () => _items.removeWhere((a) => a.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }
}
