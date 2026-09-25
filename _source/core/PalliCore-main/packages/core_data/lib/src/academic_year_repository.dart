import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class AcademicYearRepository extends BaseRepository<AcademicYear> {
  AcademicYearRepository(SupabaseClient client) : super(client, 'academic_years');

  static final List<AcademicYear> _items = [
    AcademicYear(
      id: 'ay-previous',
      name: '2024–25',
      startDate: DateTime(2024, 6, 1),
      endDate: DateTime(2025, 3, 31),
    ),
    AcademicYear(
      id: 'ay-current',
      name: '2025–26',
      startDate: DateTime(2025, 6, 1),
      endDate: DateTime(2026, 3, 31),
      isCurrent: true,
    ),
  ];

  @override
  Future<List<AcademicYear>> getAll() {
    return remoteOrLocal(
      () async {
        final response = await client.from(tableName).select();
        final remote = (response as List)
            .map((j) => AcademicYear.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        if (remote.isNotEmpty) {
          _items
            ..clear()
            ..addAll(remote);
        }
        return List<AcademicYear>.from(_items);
      },
      () => List<AcademicYear>.from(_items),
    );
  }

  Future<AcademicYear?> getCurrent() async {
    final all = await getAll();
    try {
      return all.firstWhere((y) => y.isCurrent);
    } catch (_) {
      return all.isEmpty ? null : all.last;
    }
  }

  @override
  Future<AcademicYear?> getById(String id) async {
    try {
      return _items.firstWhere((y) => y.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(AcademicYear item) {
    return writeLocalThenRemote(() {
      if (item.isCurrent) {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = AcademicYear(
            id: _items[i].id,
            name: _items[i].name,
            startDate: _items[i].startDate,
            endDate: _items[i].endDate,
            isCurrent: _items[i].id == item.id,
          );
        }
      }
      final index = _items.indexWhere((y) => y.id == item.id);
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
      () => _items.removeWhere((y) => y.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }
}
