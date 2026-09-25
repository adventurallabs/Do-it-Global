import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class AdmissionRepository extends BaseRepository<Admission> {
  AdmissionRepository(SupabaseClient client) : super(client, 'admissions');

  static final List<Admission> _items = [
    Admission(
      id: 'ad1',
      studentName: 'Kabir Shah',
      parentName: 'Naveen Shah',
      contactNumber: '9847091111',
      appliedGradeKey: '1',
      notes: 'Walk-in enquiry for 1st Std.',
      stage: AdmissionStage.enquiry,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Admission(
      id: 'ad2',
      studentName: 'Sara Thomas',
      parentName: 'Mary Thomas',
      contactNumber: '9847092222',
      appliedGradeKey: 'LKG',
      notes: 'Birth certificate uploaded.',
      stage: AdmissionStage.documents,
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
    ),
    Admission(
      id: 'ad3',
      studentName: 'Advait Nair',
      parentName: 'Ramesh Nair',
      contactNumber: '9847093333',
      appliedGradeKey: '10',
      notes: 'Awaiting TC verification.',
      stage: AdmissionStage.verification,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
  ];

  @override
  Future<List<Admission>> getAll() {
    return remoteOrLocal(
      () async {
        final response = await client.from(tableName).select();
        final remote = (response as List)
            .map((j) => Admission.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _items
          ..clear()
          ..addAll(remote);
        return List<Admission>.from(_items)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      },
      () => List<Admission>.from(_items)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  @override
  Future<Admission?> getById(String id) async {
    try {
      return _items.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(Admission item) {
    return writeLocalThenRemote(() {
      final index = _items.indexWhere((a) => a.id == item.id);
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
      () => _items.removeWhere((a) => a.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }
}
