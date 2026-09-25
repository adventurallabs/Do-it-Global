import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class ActivityRepository extends BaseRepository<Activity> {
  ActivityRepository(SupabaseClient client) : super(client, 'activities');

  static final List<Activity> _items = [];

  @override
  Future<List<Activity>> getAll() {
    return remoteOrLocal(
      () async {
        final rows = await client
            .from(tableName)
            .select()
            .order('date', ascending: false)
            .limit(200);
        final list = (rows as List)
            .map((j) => Activity.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _items
          ..clear()
          ..addAll(list);
        return list;
      },
      () => List<Activity>.from(_items),
    );
  }

  Future<List<Activity>> getByStudent(String studentId) async {
    final all = await getAll();
    return all.where((a) => a.studentId == studentId).toList();
  }

  Future<List<Activity>> getByClassroom(String classroomId) async {
    final all = await getAll();
    return all.where((a) => a.classroomId == classroomId).toList();
  }

  @override
  Future<Activity?> getById(String id) async {
    try {
      return _items.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(Activity item) {
    return writeLocalThenRemote(
      () {
        final i = _items.indexWhere((a) => a.id == item.id);
        if (i >= 0) {
          _items[i] = item;
        } else {
          _items.insert(0, item);
        }
      },
      () => client.from(tableName).upsert(item.toJson()),
    );
  }

  @override
  Future<void> delete(String id) {
    return writeLocalThenRemote(
      () => _items.removeWhere((a) => a.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }
}
