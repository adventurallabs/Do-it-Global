import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class SchoolEventRepository extends BaseRepository<SchoolEvent> {
  SchoolEventRepository(SupabaseClient client) : super(client, 'school_events');

  static final List<SchoolEvent> _items = [
    SchoolEvent(
      id: 'ev1',
      name: 'Annual Day',
      description: 'Cultural evening for the whole school. Costumes and refreshments included.',
      eventDate: DateTime.now().add(const Duration(days: 28)),
      lastPayDate: DateTime.now().add(const Duration(days: 14)),
      feeAmount: 500,
      audience: EventAudience.school,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  @override
  Future<List<SchoolEvent>> getAll() {
    return remoteOrLocal(
      () async {
        final response = await client.from(tableName).select();
        final remote = (response as List)
            .map((json) => SchoolEvent.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
        if (remote.isNotEmpty) {
          _items
            ..clear()
            ..addAll(remote);
        }
        return List<SchoolEvent>.from(_items);
      },
      () => List<SchoolEvent>.from(_items),
    );
  }

  @override
  Future<SchoolEvent?> getById(String id) async {
    try {
      return _items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(SchoolEvent item) {
    return writeLocalThenRemote(() {
      final index = _items.indexWhere((e) => e.id == item.id);
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
      () => _items.removeWhere((e) => e.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }
}
