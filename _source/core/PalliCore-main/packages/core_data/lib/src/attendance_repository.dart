import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class AttendanceRepository extends BaseRepository<Attendance> {
  AttendanceRepository(SupabaseClient client) : super(client, 'attendance');

  /// Offline cache of rows this session has read or written.
  static final List<Attendance> _items = [];

  @override
  Future<List<Attendance>> getAll() {
    return remoteOrLocal(
      () async {
        final response = await client.from(tableName).select();
        final remote = (response as List)
            .map((j) => Attendance.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _items
          ..clear()
          ..addAll(remote);
        return List<Attendance>.from(_items);
      },
      () => List<Attendance>.from(_items),
    );
  }

  // Range bounds are the local day's real UTC instants (e.g. IST midnight =
  // 18:30Z the day before). That window contains both ways a date gets
  // stored: true instants taken during the school day, and "local midnight"
  // values serialised without an offset (stored as 00:00Z of that date).
  static String _day(DateTime localMidnight) => localMidnight.toUtc().toIso8601String();

  /// Rows in [from, to) filtered in the database — never the whole table
  /// (which the API also caps at 1000 rows, silently hiding newer records).
  Future<List<Attendance>> _range(
    DateTime from,
    DateTime to, {
    String? periodId,
    String? classroomId,
    required bool Function(Attendance) localFilter,
  }) {
    return remoteOrLocal(
      () async {
        var q = client.from(tableName).select().gte('date', _day(from)).lt('date', _day(to));
        if (periodId != null) q = q.eq('period_id', periodId);
        if (classroomId != null) q = q.eq('classroom_id', classroomId);
        final rows = await q;
        final list = (rows as List)
            .map((j) => Attendance.fromJson(Map<String, dynamic>.from(j as Map)))
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
      () => _items.where(localFilter).toList(),
    );
  }

  static DateTime _startOf(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<List<Attendance>> getByDate(DateTime date) {
    final start = _startOf(date);
    return _range(start, start.add(const Duration(days: 1)),
        localFilter: (a) => GradeCatalog.sameDay(a.date, date));
  }

  /// Roll-call rows across a span of days, for the attendance charts and a
  /// child's or teacher's history. Only homeroom rows, because a subject
  /// period is a different record with a different meaning.
  Future<List<Attendance>> getHomeroomBetween(DateTime from, DateTime to) {
    final start = _startOf(from);
    final end = _startOf(to).add(const Duration(days: 1));
    return _range(start, end,
        periodId: 'homeroom',
        localFilter: (a) =>
            a.periodId == 'homeroom' && !a.date.isBefore(start) && a.date.isBefore(end));
  }

  /// Every roll-call row for one child in a span — their attendance history.
  Future<List<Attendance>> getForStudentBetween(
    String studentId,
    DateTime from,
    DateTime to,
  ) async {
    final start = _startOf(from);
    final end = _startOf(to).add(const Duration(days: 1));
    try {
      final rows = await client
          .from(tableName)
          .select()
          .eq('student_id', studentId)
          .eq('period_id', 'homeroom')
          .gte('date', _day(start))
          .lt('date', _day(end))
          .order('date');
      return (rows as List)
          .map((j) => Attendance.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    } catch (_) {
      return _items
          .where((a) =>
              a.studentId == studentId &&
              a.periodId == 'homeroom' &&
              !a.date.isBefore(start) &&
              a.date.isBefore(end))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    }
  }

  Future<List<Attendance>> getByMonth(int year, int month) {
    return _range(DateTime(year, month), DateTime(year, month + 1),
        localFilter: (a) => a.date.year == year && a.date.month == month);
  }

  @override
  Future<Attendance?> getById(String id) async {
    try {
      return _items.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(Attendance item) {
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

  Future<List<Attendance>> getByPeriodAndDate(String periodId, DateTime date) {
    final start = _startOf(date);
    return _range(start, start.add(const Duration(days: 1)),
        periodId: periodId,
        localFilter: (a) => a.periodId == periodId && GradeCatalog.sameDay(a.date, date));
  }

  /// Daily homeroom roll-call for a classroom (`period_id == 'homeroom'`),
  /// as taken by the class teacher — distinct from per-subject-period rows.
  Future<List<Attendance>> getHomeroomForClassroom(String classroomId, DateTime date) {
    final start = _startOf(date);
    return _range(start, start.add(const Duration(days: 1)),
        periodId: 'homeroom',
        classroomId: classroomId,
        localFilter: (a) =>
            a.periodId == 'homeroom' && a.classroomId == classroomId && GradeCatalog.sameDay(a.date, date));
  }

  /// Every attendance row for one child, newest first — the leaver export
  /// writes these out before the record is erased.
  Future<List<Attendance>> getForStudent(String studentId) async {
    try {
      final response = await client
          .from(tableName)
          .select()
          .eq('student_id', studentId)
          .order('date', ascending: false)
          .timeout(kRemoteTimeout);
      return (response as List)
          .map((j) => Attendance.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    } catch (_) {
      return _items.where((a) => a.studentId == studentId).toList();
    }
  }

  /// Saves a class's attendance in one request. Throws when the write
  /// fails — attendance must never look saved when parents can't see it.
  Future<void> submitAttendance(List<Attendance> attendanceList) async {
    await client
        .from(tableName)
        .upsert(attendanceList.map((e) => e.toJson()).toList())
        .timeout(kRemoteTimeout);
    for (final item in attendanceList) {
      final index = _items.indexWhere((a) => a.id == item.id);
      if (index >= 0) {
        _items[index] = item;
      } else {
        _items.add(item);
      }
    }
  }
}
