import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

List<Period> _demoWeek() {
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  const slots = [
    ('English', 't1', '08:30', 45),
    ('Break', 'N/A', '09:15', 15),
    ('Mathematics', 't2', '09:30', 45),
    ('Science', 't1', '10:15', 45),
    ('Lunch', 'N/A', '11:00', 45),
    ('Tamil', 't2', '11:45', 45),
    ('Social', 't1', '12:30', 45),
  ];
  final periods = <Period>[];
  var i = 0;
  for (final day in days) {
    for (final slot in slots) {
      periods.add(Period(
        id: 'p${i++}',
        name: slot.$1,
        staffId: slot.$2,
        startTime: slot.$3,
        durationMinutes: slot.$4,
        dayOfWeek: day,
      ));
    }
  }
  return periods;
}

class TimetableRepository extends BaseRepository<Timetable> {
  TimetableRepository(SupabaseClient client) : super(client, 'timetables');

  static final List<Timetable> _items = [
    Timetable(
      id: 'tt1',
      classroomId: '1',
      name: 'Regular week',
      isActive: true,
      startTime: '08:30',
      endTime: '15:30',
      intervalCount: 8,
      periods: _demoWeek(),
    ),
  ];

  @override
  Future<List<Timetable>> getAll() {
    return remoteOrLocal(
      () async {
        final response = await client.from(tableName).select();
        final remote = (response as List)
            .map((j) => Timetable.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _items
          ..clear()
          ..addAll(remote);
        return List<Timetable>.from(_items);
      },
      () => List<Timetable>.from(_items),
    );
  }

  @override
  Future<Timetable?> getById(String id) async {
    try {
      return _items.firstWhere((t) => t.id == id);
    } catch (_) {
      return remoteOrLocal(() async {
        final response = await client.from(tableName).select().eq('id', id).maybeSingle();
        return response == null ? null : Timetable.fromJson(response);
      }, () => null);
    }
  }

  /// One-day cover periods from before today are history — drop them on
  /// every write so they don't pile up in the timetable forever.
  static Timetable _withoutStaleCovers(Timetable t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final kept = t.periods
        .where((p) => !p.isTemporary || p.date == null || !p.date!.isBefore(today))
        .toList();
    if (kept.length == t.periods.length) return t;
    return Timetable(
      id: t.id,
      classroomId: t.classroomId,
      name: t.name,
      isActive: t.isActive,
      periods: kept,
      startTime: t.startTime,
      endTime: t.endTime,
      intervalCount: t.intervalCount,
    );
  }

  @override
  Future<void> upsert(Timetable input) {
    final item = _withoutStaleCovers(input);
    return writeLocalThenRemote(() {
      final index = _items.indexWhere((t) => t.id == item.id);
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
      () => _items.removeWhere((t) => t.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }

  Future<List<Timetable>> getForClass(String classroomId) {
    return remoteOrLocal(
      () async {
        final response = await client.from(tableName).select().eq('classroom_id', classroomId);
        final remote = (response as List).map((json) => Timetable.fromJson(json)).toList();
        for (final item in remote) {
          final index = _items.indexWhere((t) => t.id == item.id);
          if (index >= 0) {
            _items[index] = item;
          } else {
            _items.add(item);
          }
        }
        return _items.where((t) => t.classroomId == classroomId).toList();
      },
      () => _items.where((t) => t.classroomId == classroomId).toList(),
    );
  }

  Future<Timetable?> getActiveForClass(String classroomId) async {
    final all = await getForClass(classroomId);
    try {
      return all.firstWhere((t) => t.isActive);
    } catch (_) {
      return all.isEmpty ? null : all.first;
    }
  }

  Future<void> activateTimetable(String timetableId, String classroomId) {
    return writeLocalThenRemote(() {
      for (int i = 0; i < _items.length; i++) {
        final timetable = _items[i];
        if (timetable.classroomId == classroomId) {
          _items[i] = Timetable(
            id: timetable.id,
            classroomId: timetable.classroomId,
            name: timetable.name,
            isActive: timetable.id == timetableId,
            periods: timetable.periods,
            startTime: timetable.startTime,
            endTime: timetable.endTime,
            intervalCount: timetable.intervalCount,
          );
        }
      }
    }, () async {
      await client.from(tableName).update({'is_active': false}).eq('classroom_id', classroomId);
      await client.from(tableName).update({'is_active': true}).eq('id', timetableId);
    });
  }

  Future<void> addTemporaryCoverage({
    required String timetableId,
    required Period original,
    required String substituteStaffId,
    required DateTime date,
  }) {
    return addTemporaryCoverageBatch(
      timetableId: timetableId,
      assignments: [(original: original, substituteStaffId: substituteStaffId, date: date)],
    );
  }

  /// Same as [addTemporaryCoverage] but applies several assignments to one
  /// timetable in a single read-modify-write. Calling [addTemporaryCoverage]
  /// in a loop for periods that share a timetable is unsafe — each call
  /// reads the timetable before the previous write lands, so concurrent (or
  /// even just repeated) calls silently drop all but the last one. Batching
  /// per timetable is both the correct fix and the faster one — one write
  /// instead of N.
  Future<void> addTemporaryCoverageBatch({
    required String timetableId,
    required List<({Period original, String substituteStaffId, DateTime date})> assignments,
  }) async {
    if (assignments.isEmpty) return;
    final index = _items.indexWhere((t) => t.id == timetableId);
    if (index < 0) return;
    final timetable = _items[index];
    var periods = timetable.periods;
    for (final a in assignments) {
      periods = _withTemporaryCoverage(periods, a.original, a.substituteStaffId, a.date);
    }
    await upsert(
      Timetable(
        id: timetable.id,
        classroomId: timetable.classroomId,
        name: timetable.name,
        isActive: timetable.isActive,
        periods: periods,
        startTime: timetable.startTime,
        endTime: timetable.endTime,
        intervalCount: timetable.intervalCount,
      ),
    );
  }

  List<Period> _withTemporaryCoverage(
    List<Period> periods,
    Period original,
    String substituteStaffId,
    DateTime date,
  ) {
    final temp = original.copyWith(
      id: 'tmp_${DateTime.now().microsecondsSinceEpoch}_${original.id}',
      staffId: substituteStaffId,
      isTemporary: true,
      date: date,
    );
    return periods.where((p) {
      if (!p.isTemporary) return true;
      return !(p.dayOfWeek == original.dayOfWeek &&
          p.startTime == original.startTime &&
          p.date != null &&
          GradeCatalog.sameDay(p.date!, date));
    }).toList()
      ..add(temp);
  }
}
