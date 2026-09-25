import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class ParentNoticeRepository extends BaseRepository<ParentNotice> {
  ParentNoticeRepository(SupabaseClient client) : super(client, 'parent_notices');

  static final List<ParentNotice> _items = [
    ParentNotice(
      id: 'ev1-s1',
      eventId: 'ev1',
      studentId: 's1',
      studentName: 'Aarav Menon',
      guardianName: 'Ravi Menon',
      contactNumber: '9847010001',
      title: 'Annual Day',
      body: 'Cultural evening for the whole school.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  @override
  Future<List<ParentNotice>> getAll() {
    return remoteOrLocal(
      () async {
        final response = await client.from(tableName).select();
        final remote = (response as List)
            .map((json) => ParentNotice.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
        if (remote.isNotEmpty) {
          _items
            ..clear()
            ..addAll(remote);
        }
        return List<ParentNotice>.from(_items);
      },
      () => List<ParentNotice>.from(_items),
    );
  }

  Future<List<ParentNotice>> getByEvent(String eventId) async {
    final all = await getAll();
    return all.where((n) => n.eventId == eventId).toList();
  }

  /// Bulk create/update — used when an event notice fans out to every
  /// parent in a classroom or the whole school, so this can be dozens to
  /// hundreds of rows. One batched upsert instead of one round trip per
  /// notice is the difference between an instant save and a very slow one.
  Future<void> upsertAll(List<ParentNotice> notices) async {
    if (notices.isEmpty) return;
    for (final notice in notices) {
      final index = _items.indexWhere((n) => n.id == notice.id);
      if (index >= 0) {
        _items[index] = notice;
      } else {
        _items.add(notice);
      }
    }
    try {
      await client
          .from(tableName)
          .upsert(notices.map((n) => n.toJson()).toList())
          .timeout(kRemoteTimeout);
    } catch (_) {}
  }

  @override
  Future<ParentNotice?> getById(String id) async {
    try {
      return _items.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(ParentNotice item) {
    return writeLocalThenRemote(() {
      final index = _items.indexWhere((n) => n.id == item.id);
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
      () => _items.removeWhere((n) => n.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }
}
