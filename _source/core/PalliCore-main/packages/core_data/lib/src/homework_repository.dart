import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class HomeworkRepository extends BaseRepository<Homework> {
  HomeworkRepository(SupabaseClient client) : super(client, 'homework');

  static final List<Homework> _items = [];
  static final Random _rand = Random();

  /// Ids are `text` in the schema, so we mint our own. The millisecond clock
  /// alone collides when a teacher assigns the same work to several classes in
  /// one tap, which would silently overwrite the previous row.
  static String newId() {
    final suffix = _rand.nextInt(1 << 20).toRadixString(36).padLeft(4, '0');
    return '${DateTime.now().millisecondsSinceEpoch}-$suffix';
  }

  @override
  Future<List<Homework>> getAll() {
    return remoteOrLocal(() async {
      final response = await client.from(tableName).select();
      final remote = (response as List).map((json) => Homework.fromJson(json)).toList();
      _merge(remote);
      return remote;
    }, () => List<Homework>.from(_items));
  }

  /// Only what this teacher assigned. Filtered on the server — the teacher
  /// board used to pull every homework row in the school and narrow it in Dart.
  Future<List<Homework>> getByTeacher(String teacherId) {
    return remoteOrLocal(() async {
      final response =
          await client.from(tableName).select().eq('created_by', teacherId);
      final remote = (response as List).map((json) => Homework.fromJson(json)).toList();
      _merge(remote);
      return remote;
    }, () => _items.where((h) => h.createdBy == teacherId).toList());
  }

  @override
  Future<Homework?> getById(String id) {
    return remoteOrLocal(() async {
      final row = await client.from(tableName).select().eq('id', id).maybeSingle();
      if (row == null) return _cached(id);
      final hw = Homework.fromJson(Map<String, dynamic>.from(row));
      _merge([hw]);
      return hw;
    }, () => _cached(id));
  }

  Homework? _cached(String id) {
    for (final h in _items) {
      if (h.id == id) return h;
    }
    return null;
  }

  @override
  Future<void> upsert(Homework item) {
    return writeLocalThenRemote(
      () => _merge([item]),
      () => client.from(tableName).upsert(item.toJson()),
    );
  }

  /// Like [upsert] but **throws** when the write does not reach the server.
  ///
  /// Assigning homework is a one-shot action a teacher cannot verify by eye:
  /// swallowing the failure means the class never receives the work while the
  /// teacher is told it was sent. Callers show the error and let them retry.
  Future<void> save(Homework item) async {
    await client.from(tableName).upsert(item.toJson()).timeout(kRemoteTimeout);
    _merge([item]);
  }

  /// Strict counterpart of [delete] — see [save].
  Future<void> remove(String id) async {
    await client.from(tableName).delete().eq('id', id).timeout(kRemoteTimeout);
    _items.removeWhere((h) => h.id == id);
  }

  @override
  Future<void> delete(String id) {
    return writeLocalThenRemote(
      () => _items.removeWhere((h) => h.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }

  Future<List<Homework>> getByClassroom(String classroomId) {
    return remoteOrLocal(() async {
      final response =
          await client.from(tableName).select().eq('classroom_id', classroomId);
      final remote = (response as List).map((json) => Homework.fromJson(json)).toList();
      _merge(remote);
      return remote;
    }, () => _items.where((h) => h.classroomId == classroomId).toList());
  }

  Future<List<Homework>> getByStudent(String studentId) async {
    final all = await getAll();
    return all.where((h) => h.studentId == studentId).toList();
  }

  void _merge(List<Homework> list) {
    for (final h in list) {
      _items.removeWhere((x) => x.id == h.id);
      _items.add(h);
    }
  }
}
