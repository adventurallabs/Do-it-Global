import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

class FeePaymentRepository extends BaseRepository<FeePayment> {
  FeePaymentRepository(SupabaseClient client) : super(client, 'fee_payments');

  static final List<FeePayment> _items = [
    FeePayment(
      id: 'p1',
      studentId: 's1',
      amount: 15000,
      paidOn: DateTime.now().subtract(const Duration(days: 40)),
      kind: FeeKind.tuition,
      note: 'Annual tuition — full',
    ),
    FeePayment(
      id: 'p2',
      studentId: 's2',
      amount: 7000,
      paidOn: DateTime.now().subtract(const Duration(days: 20)),
      kind: FeeKind.tuition,
      note: 'First instalment',
    ),
    FeePayment(
      id: 'p3',
      studentId: 's5',
      amount: 12000,
      paidOn: DateTime.now().subtract(const Duration(days: 10)),
      kind: FeeKind.tuition,
      note: 'Annual tuition — full',
    ),
    FeePayment(
      id: 'p4',
      studentId: 's7',
      amount: 10000,
      paidOn: DateTime.now().subtract(const Duration(days: 8)),
      kind: FeeKind.tuition,
      note: 'Term 1',
    ),
    FeePayment(
      id: 'p5',
      studentId: 's1',
      amount: 500,
      paidOn: DateTime.now().subtract(const Duration(days: 1)),
      kind: FeeKind.event,
      eventId: 'ev1',
      note: 'Annual Day',
    ),
  ];

  @override
  Future<List<FeePayment>> getAll() {
    return remoteOrLocal(
      () async {
        final response = await client.from(tableName).select();
        final remote = (response as List)
            .map((json) => FeePayment.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
        if (remote.isNotEmpty) {
          _items
            ..clear()
            ..addAll(remote);
        }
        return List<FeePayment>.from(_items);
      },
      () => List<FeePayment>.from(_items),
    );
  }

  Future<List<FeePayment>> getByStudent(String studentId) async {
    final all = await getAll();
    final payments = all.where((p) => p.studentId == studentId).toList()
      ..sort((a, b) => b.paidOn.compareTo(a.paidOn));
    return payments;
  }

  @override
  Future<FeePayment?> getById(String id) async {
    try {
      return _items.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(FeePayment item) {
    return writeLocalThenRemote(() {
      final index = _items.indexWhere((p) => p.id == item.id);
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
      () => _items.removeWhere((p) => p.id == id),
      () => client.from(tableName).delete().eq('id', id),
    );
  }
}
