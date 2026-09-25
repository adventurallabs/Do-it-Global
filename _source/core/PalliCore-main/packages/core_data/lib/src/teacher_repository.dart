import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class TeacherRepository extends BaseRepository<Teacher> {
  TeacherRepository(SupabaseClient client) : super(client, 'teachers');

  // Offline-only cache, populated from Supabase on first successful fetch.
  // Empty until then — the app shows real data or an empty/error state, never
  // placeholder teachers.
  static final List<Teacher> _items = [];

  @override
  Future<List<Teacher>> getAll({bool includeInactive = false}) {
    return remoteOrLocal(
      () async {
        var query = client.from(tableName).select();
        if (!includeInactive) query = query.eq('is_active', true);
        final response = await query;
        final remote = (response as List).map((json) => Teacher.fromJson(json)).toList();
        if (!includeInactive) {
          _items
            ..clear()
            ..addAll(remote);
        }
        return remote;
      },
      () => includeInactive
          ? const <Teacher>[]
          : List<Teacher>.from(_items),
    );
  }

  /// Deactivated teachers — surfaced only in the admin "Deactivated" section.
  ///
  /// Staff who have *left* are excluded: discontinuing also switches the
  /// login off, so without this they would appear in both Deactivated and
  /// the Discontinued archive, with two different sets of actions.
  Future<List<Teacher>> getInactive() async {
    try {
      final response = await client
          .from(tableName)
          .select()
          .eq('is_active', false)
          .isFilter('exit_reason', null)
          .timeout(kRemoteTimeout);
      return (response as List).map((json) => Teacher.fromJson(json)).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Creates the teacher's phone+password login (Edge Function, service role)
  /// then the `teachers` row. Returns the one-time temp password.
  Future<String> createWithLogin(Teacher teacher) async {
    final res = await client.functions.invoke('admin-create-teacher', body: {
      'id': teacher.id,
      'name': teacher.name,
      'phone': teacher.contactNumber,
      'dob': teacher.dob?.toIso8601String(),
      'qualification': teacher.qualification,
      'address': teacher.address,
      'salary': teacher.salary,
      'classroomId': teacher.classroomId,
      'role': teacher.role.name,
      'subjects': teacher.subjects,
    });
    _throwIfError(res);
    return res.data['tempPassword'] as String;
  }

  /// Issues a fresh temp password and forces a change on next login.
  Future<String> resetPassword(String teacherId) async {
    final res = await client.functions.invoke('admin-reset-teacher-password', body: {'teacherId': teacherId});
    _throwIfError(res);
    return res.data['tempPassword'] as String;
  }

  /// Changes the phone a teacher signs in with. The database trigger
  /// `trg_teachers_login_phone` moves their login to the new number in the
  /// same transaction, or rejects it if another login already has it — so
  /// unlike [upsert], this surfaces the failure instead of swallowing it.
  Future<void> changeLoginPhone(String teacherId, String phone) async {
    await client
        .from(tableName)
        .update({'contact_number': phone})
        .eq('id', teacherId)
        .timeout(kRemoteTimeout);
    final index = _items.indexWhere((t) => t.id == teacherId);
    if (index >= 0) _items[index] = _items[index].copyWith(contactNumber: phone);
  }

  /// A readable reason for a failed [changeLoginPhone].
  static String describeError(Object error) {
    if (error is PostgrestException) {
      if (error.code == '23505') return 'another staff login already uses that number.';
      return error.message;
    }
    return 'check your connection and try again.';
  }

  /// Deactivate (revokes their session immediately) or reactivate.
  Future<void> setActive(String teacherId, bool active) async {
    final res = await client.functions
        .invoke('admin-set-teacher-active', body: {'teacherId': teacherId, 'active': active});
    _throwIfError(res);
  }

  /// The leaver archive: staff who have left, newest exit first.
  Future<List<Teacher>> getArchived() async {
    try {
      final response = await client
          .from(tableName)
          .select()
          .not('exit_reason', 'is', null)
          .order('exit_at', ascending: false)
          .timeout(kRemoteTimeout);
      return (response as List).map((json) => Teacher.fromJson(json)).toList();
    } catch (_) {
      return _items.where((t) => t.hasLeft).toList();
    }
  }

  /// Records that a staff member has left, revokes their login immediately
  /// and starts the retention clock. Throws on failure — an admin must never
  /// be told someone was archived while their login still works.
  Future<Teacher> recordExit(
    Teacher teacher, {
    ExitReason reason = ExitReason.discontinued,
    String note = '',
    DateTime? at,
  }) async {
    final exit = ExitRecord.starting(reason, at: at, note: note);
    // Revoke access first: if the archive write then fails, the worst case is
    // a locked-out account an admin can reactivate, not a departed teacher
    // who can still open the app.
    await setActive(teacher.id, false);
    final updated = teacher.copyWith(
      isActive: false,
      deactivatedAt: exit.at,
      clearClassroom: true,
      exitReason: reason,
      exitAt: exit.at,
      purgeAfter: exit.purgeAfter,
      exitNote: note,
    );
    final payload = updated.toJson()..['classroom_id'] = null;
    await client.from(tableName).upsert(payload).timeout(kRemoteTimeout);
    _items.removeWhere((t) => t.id == updated.id);
    return updated;
  }

  /// Brings a leaver back: stops the clock and restores their login. Their
  /// old classroom and periods are not restored — those are the admin's call.
  Future<void> undoExit(Teacher teacher) async {
    final updated = teacher.copyWith(isActive: true, clearExit: true, clearDeactivatedAt: true);
    final payload = updated.toJson()
      ..['exit_reason'] = null
      ..['exit_at'] = null
      ..['purge_after'] = null
      ..['exit_note'] = '';
    await client.from(tableName).upsert(payload).timeout(kRemoteTimeout);
    await setActive(teacher.id, true);
  }

  /// Permanent purge — only valid once the teacher is already deactivated.
  Future<void> deletePermanently(String teacherId) async {
    final res = await client.functions.invoke('admin-delete-teacher', body: {'teacherId': teacherId});
    _throwIfError(res);
  }

  void _throwIfError(FunctionResponse res) {
    if (res.status != 200) {
      final message = (res.data is Map) ? res.data['error']?.toString() : null;
      throw Exception(message ?? 'Request failed (${res.status})');
    }
  }

  @override
  Future<Teacher?> getById(String id) async {
    try {
      return _items.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(Teacher item) {
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
}
