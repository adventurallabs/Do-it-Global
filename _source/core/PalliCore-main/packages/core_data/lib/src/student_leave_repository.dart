import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class StudentLeaveRepository extends BaseRepository<StudentLeaveRequest> {
  StudentLeaveRepository(SupabaseClient client)
      : super(client, 'student_leave_requests');

  static final List<StudentLeaveRequest> _items = [];

  @override
  Future<List<StudentLeaveRequest>> getAll() {
    return remoteOrLocal(
      () async {
        final rows = await client
            .from(tableName)
            .select()
            .order('created_at', ascending: false);
        final list = (rows as List)
            .map((j) =>
                StudentLeaveRequest.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _items
          ..clear()
          ..addAll(list);
        return list;
      },
      () => List<StudentLeaveRequest>.from(_items)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  Stream<List<StudentLeaveRequest>> watch() {
    try {
      return client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((rows) => rows
              .map((j) =>
                  StudentLeaveRequest.fromJson(Map<String, dynamic>.from(j)))
              .toList());
    } catch (_) {
      return Stream.value(List<StudentLeaveRequest>.from(_items));
    }
  }

  Future<List<StudentLeaveRequest>> pending() async {
    final all = await getAll();
    return all
        .where((r) =>
            r.status == StudentLeaveStatus.requested ||
            r.status == StudentLeaveStatus.underReview)
        .toList();
  }

  Future<List<StudentLeaveRequest>> forStudent(String studentId) async {
    final all = await getAll();
    return all.where((r) => r.studentId == studentId).toList();
  }

  @override
  Future<StudentLeaveRequest?> getById(String id) async {
    try {
      return _items.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(StudentLeaveRequest item) {
    return writeLocalThenRemote(
      () {
        final i = _items.indexWhere((r) => r.id == item.id);
        if (i >= 0) {
          _items[i] = item;
        } else {
          _items.insert(0, item);
        }
      },
      () => client.from(tableName).upsert(item.toJson()),
    );
  }

  Future<void> review(
    StudentLeaveRequest request, {
    required StudentLeaveStatus status,
    required String reviewedBy,
    String? note,
  }) {
    return upsert(request.copyWith(
      status: status,
      reviewedBy: reviewedBy,
      reviewedAt: DateTime.now(),
      reviewNote: note,
    ));
  }

  @override
  Future<void> delete(String id) {
    return writeLocalThenRemote(
      () => _items.removeWhere((r) => r.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }
}
