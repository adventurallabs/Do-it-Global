import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class ClassroomRepository extends BaseRepository<Classroom> {
  ClassroomRepository(SupabaseClient client) : super(client, 'classrooms');

  static final List<Classroom> _items = [
    Classroom(
      id: 'lkg',
      name: 'LKG',
      classTeacherId: 't3',
      baseFees: 12000,
      gradeKey: 'LKG',
    ),
    Classroom(
      id: 'ukg',
      name: 'UKG',
      classTeacherId: 't4',
      baseFees: 12000,
      gradeKey: 'UKG',
    ),
    Classroom(
      id: '1',
      name: '2nd Std A',
      classTeacherId: 't1',
      baseFees: 15000,
      gradeKey: '2',
      section: 'A',
    ),
    Classroom(
      id: '2',
      name: '2nd Std B',
      classTeacherId: 't2',
      baseFees: 15000,
      gradeKey: '2',
      section: 'B',
    ),
    Classroom(
      id: '10a',
      name: '10th Std A',
      classTeacherId: 't5',
      baseFees: 22000,
      gradeKey: '10',
      section: 'A',
    ),
    Classroom(
      id: '10b',
      name: '10th Std B',
      classTeacherId: 't6',
      baseFees: 22000,
      gradeKey: '10',
      section: 'B',
    ),
    Classroom(
      id: '12',
      name: '12th Std',
      classTeacherId: 't7',
      baseFees: 25000,
      gradeKey: '12',
    ),
  ];

  @override
  Future<List<Classroom>> getAll() {
    return remoteOrLocal(
      () async {
        final response = await client.from(tableName).select();
        final remote = (response as List).map((json) => Classroom.fromJson(json)).toList();
        if (remote.isNotEmpty) {
          _items
            ..clear()
            ..addAll(remote);
        }
        return List<Classroom>.from(_items);
      },
      () => List<Classroom>.from(_items),
    );
  }

  @override
  Future<Classroom?> getById(String id) async {
    try {
      return _items.firstWhere((c) => c.id == id);
    } catch (_) {
      return remoteOrLocal(
        () async {
          final response = await client.from(tableName).select().eq('id', id).maybeSingle();
          return response == null ? null : Classroom.fromJson(response);
        },
        () => null,
      );
    }
  }

  @override
  Future<void> upsert(Classroom item) {
    return writeLocalThenRemote(() {
      final index = _items.indexWhere((c) => c.id == item.id);
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
      () => _items.removeWhere((c) => c.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }
}
