import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class StudentRepository extends BaseRepository<Student> {
  StudentRepository(SupabaseClient client) : super(client, 'students');

  // Offline-only cache, populated from Supabase on first successful fetch.
  // Empty until then — the app shows real data or an empty/error state, never
  // placeholder students.
  static final List<Student> _items = [];

  /// The school's current roll.
  ///
  /// Children who have graduated, transferred out or been discontinued are
  /// left out by default: they belong to the archive, and every counter,
  /// roster and picker that reads this was treating them as if they were
  /// still here. [includeLeavers] is for the archive itself.
  @override
  Future<List<Student>> getAll({bool includeInactive = false, bool includeLeavers = false}) {
    return remoteOrLocal(
      () async {
        var query = client.from(tableName).select();
        if (!includeInactive) query = query.eq('is_active', true);
        if (!includeLeavers) {
          query = query.not('lifecycle', 'in', '(graduated,transferred,discontinued)');
        }
        final response = await query;
        final remote = (response as List).map((json) => Student.fromJson(json)).toList();
        if (!includeInactive && !includeLeavers) {
          _items
            ..clear()
            ..addAll(remote);
        }
        return remote;
      },
      () => includeInactive
          ? const <Student>[]
          : includeLeavers
              ? List<Student>.from(_items)
              : _items.where((s) => !s.lifecycle.hasLeft).toList(),
    );
  }

  /// Deactivated students — surfaced only in the admin "Deactivated" section.
  Future<List<Student>> getInactive() async {
    try {
      final response = await client.from(tableName).select().eq('is_active', false).timeout(kRemoteTimeout);
      return (response as List).map((json) => Student.fromJson(json)).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Student?> getById(String id) async {
    try {
      return _items.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// One class's current roster, filtered server-side — this is on every
  /// marks and attendance screen, and pulling the whole school to keep one
  /// section doesn't scale.
  ///
  /// [strict] throws when offline with nothing cached, instead of returning an
  /// empty class — for screens where "no students" would look complete.
  Future<List<Student>> getByClassroom(String classroomId, {bool strict = false}) async {
    return getByClassrooms([classroomId], strict: strict);
  }

  /// Current rosters of several classrooms in one query (every section of a
  /// standard, for exam results).
  Future<List<Student>> getByClassrooms(List<String> classroomIds, {bool strict = false}) async {
    if (classroomIds.isEmpty) return const [];
    final ids = classroomIds.toSet();
    try {
      final response = await client
          .from(tableName)
          .select()
          .inFilter('classroom_id', ids.toList())
          .eq('is_active', true)
          .not('lifecycle', 'in', '(graduated,transferred,discontinued)')
          .timeout(kRemoteTimeout);
      final remote = (response as List).map((json) => Student.fromJson(json)).toList();
      _items
        ..removeWhere((s) => ids.contains(s.classroomId))
        ..addAll(remote);
      return remote;
    } catch (_) {
      final cached = _items
          .where((s) => ids.contains(s.classroomId) && s.isActive && !s.lifecycle.hasLeft)
          .toList();
      // Nothing cached means we don't know the roster — say so, rather than
      // show "no students" and let a marks screen look complete and empty.
      if (strict && cached.isEmpty) rethrow;
      return cached;
    }
  }

  /// Students an admin may place into a classroom: this class's own roster
  /// plus the genuinely unplaced. A leaver also has an empty classroom_id,
  /// and used to surface here as if they were waiting to be assigned.
  Future<List<Student>> getAvailableStudents(String currentClassroomId) async {
    final all = await getAll();
    return all
        .where((s) =>
            s.classroomId == currentClassroomId ||
            (s.classroomId.isEmpty && !s.lifecycle.hasLeft))
        .toList();
  }

  /// The leaver archive: students who have left, newest exit first. Reads
  /// past `is_active` because leaving and being switched off are different
  /// states and a leaver may still be active until the purge.
  Future<List<Student>> getArchived({Set<StudentLifecycle>? reasons}) async {
    final wanted = reasons ?? {
      StudentLifecycle.graduated,
      StudentLifecycle.transferred,
      StudentLifecycle.discontinued,
    };
    try {
      final response = await client
          .from(tableName)
          .select()
          .inFilter('lifecycle', wanted.map((r) => r.name).toList())
          .order('exit_at', ascending: false)
          .timeout(kRemoteTimeout);
      return (response as List).map((json) => Student.fromJson(json)).toList();
    } catch (_) {
      return _items.where((s) => wanted.contains(s.lifecycle)).toList();
    }
  }

  /// Marks a child as having left, unassigns them and starts the retention
  /// clock. Throws on failure — an admin must never be told a child was
  /// archived when the row still says enrolled.
  Future<Student> recordExit(
    Student student, {
    required StudentLifecycle lifecycle,
    String note = '',
    DateTime? at,
  }) async {
    assert(lifecycle.hasLeft, 'recordExit is only for a lifecycle that has left');
    final exit = ExitRecord.starting(lifecycle.exitReason!, at: at, note: note);
    final updated = student.copyWith(
      classroomId: '',
      lifecycle: lifecycle,
      exitAt: exit.at,
      purgeAfter: exit.purgeAfter,
      exitNote: note,
    );
    await client.from(tableName).upsert(updated.toJson()).timeout(kRemoteTimeout);
    final index = _items.indexWhere((s) => s.id == updated.id);
    if (index >= 0) {
      _items[index] = updated;
    }
    return updated;
  }

  /// Puts a leaver back on the roll and stops the clock. The classroom is not
  /// restored — where they belong now is the admin's call.
  Future<void> undoExit(Student student) async {
    final updated = student.copyWith(
      lifecycle: StudentLifecycle.enrolled,
      clearExit: true,
    );
    final payload = updated.toJson()
      ..['exit_at'] = null
      ..['purge_after'] = null
      ..['exit_note'] = '';
    await client.from(tableName).upsert(payload).timeout(kRemoteTimeout);
    final index = _items.indexWhere((s) => s.id == updated.id);
    if (index >= 0) {
      _items[index] = updated;
    }
  }

  @override
  Future<void> upsert(Student item) {
    return writeLocalThenRemote(() {
      final index = _items.indexWhere((s) => s.id == item.id);
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
      () => _items.removeWhere((s) => s.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }

  /// Deactivate (also revokes + deactivates the linked parent login, if any)
  /// or reactivate (restores both).
  Future<void> setActive(String studentId, bool active) async {
    final res = await client.functions
        .invoke('admin-set-student-active', body: {'studentId': studentId, 'active': active});
    _throwIfError(res);
  }

  /// Permanent purge — only valid once the student is already deactivated.
  /// Deletes the linked parent login too; everything else cascades in the DB.
  Future<void> deletePermanently(String studentId) async {
    final res = await client.functions.invoke('admin-delete-student', body: {'studentId': studentId});
    _throwIfError(res);
  }

  /// Issues the student's parent-facing login (register number = admissionNo).
  /// Returns the one-time temp password.
  Future<String> issueParentLogin(String studentId) async {
    final res = await client.functions.invoke('admin-create-parent-account', body: {'studentId': studentId});
    _throwIfError(res);
    return res.data['tempPassword'] as String;
  }

  /// Issues a fresh temp password for the student's existing parent login.
  Future<String> resetParentPassword(String studentId) async {
    final res = await client.functions.invoke('admin-reset-parent-password', body: {'studentId': studentId});
    _throwIfError(res);
    return res.data['tempPassword'] as String;
  }

  void _throwIfError(FunctionResponse res) {
    if (res.status != 200) {
      final message = (res.data is Map) ? res.data['error']?.toString() : null;
      throw Exception(message ?? 'Request failed (${res.status})');
    }
  }

  Future<void> updateClassroom(String studentId, String? classroomId, {double? fees}) async {
    final index = _items.indexWhere((s) => s.id == studentId);
    if (index >= 0) {
      final s = _items[index];
      _items[index] = s.copyWith(classroomId: classroomId ?? '', fees: fees ?? s.fees);
    }
    try {
      final values = <String, dynamic>{'classroom_id': classroomId ?? ''};
      if (fees != null) values['fees'] = fees;
      await client.from(tableName).update(values).eq('id', studentId).timeout(kRemoteTimeout);
    } catch (_) {}
  }
}
