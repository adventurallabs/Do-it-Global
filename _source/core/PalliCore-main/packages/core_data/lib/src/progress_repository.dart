import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'remote_sync.dart';

/// Everything a teacher records about student progress: star points,
/// activities, observations, skill levels and the teacher's own reusable
/// presets.
///
/// Unlike most repositories here, writes do NOT fall back to a local cache —
/// they throw, so the recorder can tell the teacher a save didn't reach
/// parents instead of silently pretending it did.
class ProgressRepository {
  ProgressRepository(this.client);
  final SupabaseClient client;

  Future<T> _run<T>(Future<T> Function() fn) => fn().timeout(kRemoteTimeout);

  List<Map<String, dynamic>> _rows(Object rows) =>
      (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();

  // ---------------------------------------------------------------------------
  // reads
  // ---------------------------------------------------------------------------

  /// Star totals per student (students with none are absent from the map).
  Future<Map<String, int>> starTotals(List<String> studentIds) async {
    if (studentIds.isEmpty) return const {};
    final rows = await _run(() => client
        .from('star_points')
        .select('student_id, points')
        .inFilter('student_id', studentIds));
    final totals = <String, int>{};
    for (final r in _rows(rows)) {
      final id = r['student_id'] as String;
      totals[id] = (totals[id] ?? 0) + ((r['points'] as num?)?.toInt() ?? 1);
    }
    return totals;
  }

  Future<List<StarPoint>> recentStars(List<String> studentIds, {int limit = 120}) async {
    if (studentIds.isEmpty) return const [];
    final rows = await _run(() => client
        .from('star_points')
        .select()
        .inFilter('student_id', studentIds)
        .order('created_at', ascending: false)
        .limit(limit));
    return _rows(rows).map(StarPoint.fromJson).toList();
  }

  Future<List<Activity>> recentActivities(List<String> studentIds, {int limit = 120}) async {
    if (studentIds.isEmpty) return const [];
    final rows = await _run(() => client
        .from('activities')
        .select()
        .inFilter('student_id', studentIds)
        .order('date', ascending: false)
        .limit(limit));
    return _rows(rows).map(Activity.fromJson).toList();
  }

  Future<List<GrowthObservation>> recentObservations(List<String> studentIds,
      {int limit = 120}) async {
    if (studentIds.isEmpty) return const [];
    final rows = await _run(() => client
        .from('growth_observations')
        .select()
        .inFilter('student_id', studentIds)
        .order('date', ascending: false)
        .limit(limit));
    return _rows(rows).map(GrowthObservation.fromJson).toList();
  }

  Future<List<GrowthSkill>> skillsFor(List<String> studentIds) async {
    if (studentIds.isEmpty) return const [];
    final rows = await _run(() => client
        .from('growth_skills')
        .select()
        .inFilter('student_id', studentIds));
    return _rows(rows).map(GrowthSkill.fromJson).toList();
  }

  // ---------------------------------------------------------------------------
  // writes — one round trip per teacher action, however many students
  // ---------------------------------------------------------------------------

  Future<void> awardStars(List<StarPoint> stars) async {
    if (stars.isEmpty) return;
    await _run(() => client.from('star_points').insert(stars.map((s) => s.toJson()).toList()));
  }

  Future<void> recordActivities(List<Activity> items) async {
    if (items.isEmpty) return;
    await _run(() => client.from('activities').insert(items.map((a) => a.toJson()).toList()));
  }

  Future<void> recordObservations(List<GrowthObservation> items) async {
    if (items.isEmpty) return;
    await _run(() => client
        .from('growth_observations')
        .insert(items.map((o) => o.toJson()).toList()));
  }

  /// One current level per (student, skill) — re-rating overwrites it.
  Future<void> rateSkills(List<GrowthSkill> items) async {
    if (items.isEmpty) return;
    await _run(() => client
        .from('growth_skills')
        .upsert(items.map((s) => s.toJson()).toList(), onConflict: 'student_id,name'));
  }

  static String _table(ProgressKind kind) => switch (kind) {
        ProgressKind.star => 'star_points',
        ProgressKind.activity => 'activities',
        ProgressKind.observation => 'growth_observations',
        ProgressKind.skill => 'growth_skills',
      };

  Future<void> deleteEntries(ProgressKind kind, List<String> ids) async {
    if (ids.isEmpty) return;
    await _run(() => client.from(_table(kind)).delete().inFilter('id', ids));
  }

  /// Stable id so re-rating the same student+skill reuses the same row.
  static String skillRowId(String studentId, String skillName) =>
      'skl-$studentId-${skillName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';

  // ---------------------------------------------------------------------------
  // the teacher's own presets
  // ---------------------------------------------------------------------------

  Future<List<ProgressTemplate>> myTemplates(String teacherId) async {
    final rows = await _run(() => client
        .from('progress_templates')
        .select()
        .eq('created_by', teacherId)
        .order('created_at', ascending: false));
    return _rows(rows).map(ProgressTemplate.fromJson).toList();
  }

  Future<void> saveTemplate(ProgressTemplate template) async {
    await _run(() => client.from('progress_templates').upsert(template.toJson()));
  }

  Future<void> deleteTemplate(String id) async {
    await _run(() => client.from('progress_templates').delete().eq('id', id));
  }
}
