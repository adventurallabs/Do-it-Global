import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class BusRepository extends BaseRepository<Bus> {
  BusRepository(SupabaseClient client) : super(client, 'buses');

  static final List<Bus> _items = [
    Bus(id: 'b1', busNumber: 'TN-45-AB-1234', driverName: 'Rajesh Kumar', driverContact: '9876543210', latitude: 10.7905, longitude: 78.7047, lastUpdate: DateTime.now().subtract(const Duration(minutes: 8))),
    Bus(id: 'b2', busNumber: 'TN-45-CD-5678', driverName: 'Suresh Babu', driverContact: '9876543211', latitude: 10.8155, longitude: 78.6960, lastUpdate: DateTime.now().subtract(const Duration(hours: 5))),
  ];

  @override
  Future<List<Bus>> getAll() {
    return remoteOrLocal(
      () async {
        final response = await client.from(tableName).select();
        final remote = (response as List).map((json) => Bus.fromJson(json)).toList();
        if (remote.isNotEmpty) {
          _items
            ..clear()
            ..addAll(remote);
        }
        return List<Bus>.from(_items);
      },
      () => List<Bus>.from(_items),
    );
  }

  @override
  Future<Bus?> getById(String id) async {
    try {
      return _items.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(Bus item) {
    return writeLocalThenRemote(() {
      final index = _items.indexWhere((b) => b.id == item.id);
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
      () => _items.removeWhere((b) => b.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }

  Stream<List<Bus>> subscribeToBusLocations() {
    try {
      return client.from(tableName).stream(primaryKey: ['id']).map((data) {
        return data.map((json) => Bus.fromJson(json)).toList();
      });
    } catch (_) {
      return Stream.value(List<Bus>.from(_items));
    }
  }
}
