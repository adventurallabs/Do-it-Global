import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class ClassDaySummaryRepository extends BaseRepository<ClassDaySummary> {
  ClassDaySummaryRepository(SupabaseClient client)
      : super(client, 'class_day_summaries');

  static final List<ClassDaySummary> _items = [];

  @override
  Future<List<ClassDaySummary>> getAll() async => List.from(_items);

  Future<List<ClassDaySummary>> getForClassroom(String classroomId) {
    return remoteOrLocal(
      () async {
        final rows = await client
            .from(tableName)
            .select()
            .eq('classroom_id', classroomId)
            .order('summary_date', ascending: false)
            .limit(30);
        final list = (rows as List)
            .map((j) =>
                ClassDaySummary.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _merge(list);
        return list;
      },
      () => _items.where((s) => s.classroomId == classroomId).toList()
        ..sort((a, b) => b.summaryDate.compareTo(a.summaryDate)),
    );
  }

  Future<ClassDaySummary?> getForClassroomOnDate(
      String classroomId, DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final all = await getForClassroom(classroomId);
    for (final s in all) {
      final d = s.summaryDate;
      if (d.year == day.year && d.month == day.month && d.day == day.day) return s;
    }
    return null;
  }

  @override
  Future<ClassDaySummary?> getById(String id) async {
    try {
      return _items.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(ClassDaySummary item) {
    return writeLocalThenRemote(
      () => _merge([item]),
      () => client
          .from(tableName)
          .upsert(item.toJson(), onConflict: 'classroom_id,summary_date'),
    );
  }

  @override
  Future<void> delete(String id) {
    return writeLocalThenRemote(
      () => _items.removeWhere((s) => s.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }

  void _merge(List<ClassDaySummary> list) {
    for (final s in list) {
      _items.removeWhere((x) =>
          x.id == s.id ||
          (x.classroomId == s.classroomId &&
              _sameDay(x.summaryDate, s.summaryDate)));
      _items.add(s);
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
