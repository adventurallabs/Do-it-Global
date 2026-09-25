import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class LeaveRequestRepository extends BaseRepository<LeaveRequest> {
  LeaveRequestRepository(SupabaseClient client) : super(client, 'leave_requests');

  static final List<LeaveRequest> _items = [
    LeaveRequest(
      id: 'lv1',
      teacherId: 't2',
      fromDate: DateTime.now().add(const Duration(days: 1)),
      toDate: DateTime.now().add(const Duration(days: 1)),
      reason: 'Medical appointment',
      status: LeaveStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  @override
  Future<List<LeaveRequest>> getAll() {
    return remoteOrLocal(
      () async {
        final response = await client.from(tableName).select();
        final remote = (response as List)
            .map((j) => LeaveRequest.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _items
          ..clear()
          ..addAll(remote);
        final items = List<LeaveRequest>.from(_items)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return items;
      },
      () => List<LeaveRequest>.from(_items)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  Future<List<LeaveRequest>> getByTeacher(String teacherId) async {
    return (await getAll()).where((l) => l.teacherId == teacherId).toList();
  }

  @override
  Future<LeaveRequest?> getById(String id) async {
    try {
      return _items.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(LeaveRequest item) {
    return writeLocalThenRemote(() {
      final index = _items.indexWhere((l) => l.id == item.id);
      if (index >= 0) {
        _items[index] = item;
      } else {
        _items.insert(0, item);
      }
    }, () => client.from(tableName).upsert(item.toJson()));
  }

  @override
  Future<void> delete(String id) {
    return writeLocalThenRemote(
      () => _items.removeWhere((l) => l.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }
}
