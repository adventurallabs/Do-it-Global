import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class PeriodReassignmentRepository extends BaseRepository<PeriodReassignment> {
  PeriodReassignmentRepository(SupabaseClient client) : super(client, 'period_reassignments');

  static final List<PeriodReassignment> _items = [];

  @override
  Future<List<PeriodReassignment>> getAll() {
    return remoteOrLocal(
      () async {
        final rows = await client.from(tableName).select().order('created_at', ascending: false);
        final list = (rows as List)
            .map((j) => PeriodReassignment.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _items
          ..clear()
          ..addAll(list);
        return list;
      },
      () => List<PeriodReassignment>.from(_items)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  /// Pending requests waiting on this teacher to accept/reject.
  Future<List<PeriodReassignment>> pendingFor(String teacherId) async {
    final all = await getAll();
    return all
        .where((r) => r.toStaffId == teacherId && r.status == PeriodReassignmentStatus.pending)
        .toList();
  }

  /// Requests this teacher has sent out today (any status) — drives the
  /// "Re-assigned today" stat card, which stays hidden until this is non-empty.
  Future<List<PeriodReassignment>> sentToday(String teacherId, DateTime today) async {
    final all = await getAll();
    return all.where((r) => r.fromStaffId == teacherId && _sameDay(r.periodDate, today)).toList();
  }

  Stream<List<PeriodReassignment>> watch() {
    try {
      return client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((rows) => rows
              .map((j) => PeriodReassignment.fromJson(Map<String, dynamic>.from(j)))
              .toList());
    } catch (_) {
      return Stream.value(List<PeriodReassignment>.from(_items));
    }
  }

  Future<void> respond(PeriodReassignment request, {required PeriodReassignmentStatus status}) {
    return upsert(request.copyWith(status: status, respondedAt: DateTime.now()));
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Future<PeriodReassignment?> getById(String id) async {
    try {
      return _items.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(PeriodReassignment item) {
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

  @override
  Future<void> delete(String id) {
    return writeLocalThenRemote(
      () => _items.removeWhere((r) => r.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }
}
