import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'remote_sync.dart';

class HomeworkCompletionRepository {
  HomeworkCompletionRepository(this.client);
  final SupabaseClient client;

  static final List<HomeworkCompletion> _items = [];

  Future<List<HomeworkCompletion>> forHomework(String homeworkId) {
    return remoteOrLocal(
      () async {
        final rows = await client
            .from('homework_completions')
            .select()
            .eq('homework_id', homeworkId);
        final list = (rows as List)
            .map((j) =>
                HomeworkCompletion.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _merge(list);
        return list;
      },
      () => _items.where((c) => c.homeworkId == homeworkId).toList(),
    );
  }

  /// Every completion row for a batch of homework, in one round trip.
  ///
  /// The teacher board shows a "to review" count on each card; fetching those
  /// one homework at a time would be a query per card.
  Future<List<HomeworkCompletion>> forHomeworkIds(List<String> homeworkIds) {
    if (homeworkIds.isEmpty) return Future.value(const []);
    return remoteOrLocal(
      () async {
        final rows = await client
            .from('homework_completions')
            .select()
            .inFilter('homework_id', homeworkIds);
        final list = (rows as List)
            .map((j) =>
                HomeworkCompletion.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _merge(list);
        return list;
      },
      () {
        final wanted = homeworkIds.toSet();
        return _items.where((c) => wanted.contains(c.homeworkId)).toList();
      },
    );
  }

  Future<List<HomeworkCompletion>> forStudent(String studentId) {
    return remoteOrLocal(
      () async {
        final rows = await client
            .from('homework_completions')
            .select()
            .eq('student_id', studentId);
        final list = (rows as List)
            .map((j) =>
                HomeworkCompletion.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _merge(list);
        return list;
      },
      () => _items.where((c) => c.studentId == studentId).toList(),
    );
  }

  Future<void> review(
    HomeworkCompletion completion, {
    required HomeworkCompletionStatus status,
    required String reviewedBy,
  }) {
    final approved = status == HomeworkCompletionStatus.completed;
    final updated = approved
        ? completion.copyWith(
            status: status, reviewedBy: reviewedBy, reviewedAt: DateTime.now())
        : completion.copyWith(status: status, clearReview: true);
    return writeLocalThenRemote(
      () => _merge([updated]),
      () => client
          .from('homework_completions')
          .upsert(updated.toJson(), onConflict: 'homework_id,student_id'),
    );
  }

  /// Review several students in one round trip. Throws on failure so the
  /// screen can roll back its optimistic update.
  Future<void> reviewMany(
    List<HomeworkCompletion> completions, {
    required HomeworkCompletionStatus status,
    required String reviewedBy,
  }) async {
    if (completions.isEmpty) return;
    final now = DateTime.now();
    final approved = status == HomeworkCompletionStatus.completed;
    final updated = [
      for (final c in completions)
        approved
            ? c.copyWith(status: status, reviewedBy: reviewedBy, reviewedAt: now)
            : c.copyWith(status: status, clearReview: true),
    ];
    await client
        .from('homework_completions')
        .upsert(updated.map((c) => c.toJson()).toList(), onConflict: 'homework_id,student_id')
        .timeout(kRemoteTimeout);
    _merge(updated);
  }

  void _merge(List<HomeworkCompletion> list) {
    for (final c in list) {
      _items.removeWhere(
          (x) => x.homeworkId == c.homeworkId && x.studentId == c.studentId);
      _items.add(c);
    }
  }
}
