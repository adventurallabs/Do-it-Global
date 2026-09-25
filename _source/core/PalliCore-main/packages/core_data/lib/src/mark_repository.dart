import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class MarkRepository extends BaseRepository<Mark> {
  MarkRepository(SupabaseClient client) : super(client, 'marks');

  static final List<Mark> _items = [
    Mark(
      id: 'm1',
      studentId: 's1',
      subject: 'English',
      score: 82,
      totalMarks: 100,
      testType: 'Mid Term',
      date: DateTime.now().subtract(const Duration(days: 1)),
      updatedBy: 't1',
      examId: 'ex1',
    ),
    Mark(
      id: 'm2',
      studentId: 's1',
      subject: 'Mathematics',
      score: 74,
      totalMarks: 100,
      testType: 'Mid Term',
      date: DateTime.now().subtract(const Duration(days: 1)),
      updatedBy: 't2',
      examId: 'ex1',
    ),
  ];

  @override
  Future<List<Mark>> getAll() {
    return remoteOrLocal(
      () async {
        final response = await client.from(tableName).select();
        final remote = (response as List)
            .map((j) => Mark.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _items
          ..clear()
          ..addAll(remote);
        return List<Mark>.from(_items);
      },
      () => List<Mark>.from(_items),
    );
  }

  @override
  Future<Mark?> getById(String id) async {
    try {
      return _items.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(Mark item) {
    return writeLocalThenRemote(() {
      final index = _items.indexWhere((m) => m.id == item.id);
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
      () => _items.removeWhere((m) => m.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }

  Future<List<Mark>> getByStudent(String studentId) async {
    final all = await getAll();
    return all.where((m) => m.studentId == studentId).toList();
  }

  /// Every mark belonging to a set of students — the marks board reads a
  /// whole class this way. Filtered server-side; pulling the school's marks
  /// and narrowing in Dart does not scale past a few classes.
  Future<List<Mark>> getForStudents(List<String> studentIds) async {
    if (studentIds.isEmpty) return const [];
    final ids = studentIds.toSet();
    try {
      final response = await client
          .from(tableName)
          .select()
          .inFilter('student_id', ids.toList())
          .order('date', ascending: false)
          .timeout(kRemoteTimeout);
      final remote = (response as List)
          .map((j) => Mark.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
      // Refresh the offline cache for exactly these students, so a later
      // read while offline sees the corrections rather than stale scores.
      _items.removeWhere((m) => ids.contains(m.studentId));
      _items.addAll(remote);
      return remote;
    } catch (_) {
      return _items.where((m) => ids.contains(m.studentId)).toList();
    }
  }

  /// Every mark recorded *in* a classroom, whoever is on its roster today.
  ///
  /// The board pairs this with [getForStudents]: on its own, the roster query
  /// loses a sheet's marks the moment a child transfers out or is archived,
  /// so a test entered for five children reads as one. Marks stamped with the
  /// classroom survive that, and the two together also cover older rows
  /// written before the stamp existed.
  Future<List<Mark>> getForClassroom(String classroomId) async {
    if (classroomId.isEmpty) return const [];
    try {
      final response = await client
          .from(tableName)
          .select()
          .eq('classroom_id', classroomId)
          .order('date', ascending: false)
          .timeout(kRemoteTimeout);
      final remote = (response as List)
          .map((j) => Mark.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
      final ids = {for (final m in remote) m.id};
      _items.removeWhere((m) => ids.contains(m.id));
      _items.addAll(remote);
      return remote;
    } catch (_) {
      return _items.where((m) => m.classroomId == classroomId).toList();
    }
  }

  /// Removes a whole test sheet. Throws on failure — a teacher deleting a
  /// test must not be told it went when it didn't.
  Future<void> deleteMarks(List<String> ids) async {
    if (ids.isEmpty) return;
    await client.from(tableName).delete().inFilter('id', ids).timeout(kRemoteTimeout);
    _items.removeWhere((m) => ids.contains(m.id));
  }

  /// A failed write throws rather than being swallowed — marks entry must
  /// never tell a teacher "saved" when it wasn't.
  Future<void> saveMarks(List<Mark> marks) async {
    if (marks.isEmpty) return;
    await client
        .from(tableName)
        .upsert(marks.map((e) => e.toJson()).toList())
        .timeout(kRemoteTimeout);
    for (final item in marks) {
      final index = _items.indexWhere((m) => m.id == item.id);
      if (index >= 0) {
        _items[index] = item;
      } else {
        _items.add(item);
      }
    }
  }
}
