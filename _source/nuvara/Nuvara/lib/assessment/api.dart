import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../models.dart';
import 'pending.dart';
import 'scores.dart';
import '../store.dart';
import 'model.dart';

/// Someone else saved the assessment since this device loaded it, so nothing was written.
class AssessmentConflict implements Exception {
  const AssessmentConflict();
  @override
  String toString() => 'This assessment was changed on another device.';
}

/// Reads and writes assessments. Every write is a database function that checks who may do it (RLS keeps the
/// tables read-only to the app).
extension AssessmentApi on AppStore {
  Future<T> _call<T>(Future<T> Function() job) async {
    try {
      return await job();
    } on PostgrestException catch (e) {
      if (e.message.contains('ASSESSMENT_CONFLICT')) throw const AssessmentConflict();
      throw Exception(e.message);
    }
  }

  /// A child's assessments, newest first.
  Future<List<AssessmentSummary>> loadAssessments(String childId) => _call(() async {
        final rows = await db
            .from('assessments')
            .select(AssessmentSummary.columns)
            .eq('child_id', childId)
            .order('assessment_date', ascending: false)
            .order('created_at', ascending: false);
        final list = [for (final r in rows) AssessmentSummary(r)];
        assessmentsByChild[childId] = list;
        touch();
        return list;
      });

  /// Null until loaded.
  List<AssessmentSummary>? assessmentsOf(String childId) => assessmentsByChild[childId];

  /// The child's completed assessments as chart points, oldest first.
  Future<List<AssessmentPoint>> loadAssessmentTimeline(String childId) => _call(() async {
        final rows = (await db.rpc('assessment_timeline', params: {'p_child': childId}) as List).cast<Map>();
        final list = [for (final r in rows) AssessmentPoint.of(r.cast<String, dynamic>())];
        assessmentTimeline[childId] = list;
        touch();
        return list;
      });

  /// Admin: assessments started from "Add child" whose child hasn't been created yet, newest first.
  Future<List<AssessmentSummary>> loadIntakeDrafts() => _call(() async {
        final rows = await db.from('assessments').select(AssessmentSummary.columns).isFilter('child_id', null).neq('status', 'archived').order('updated_at', ascending: false);
        intakeDrafts = [for (final r in rows) AssessmentSummary(r)];
        touch();
        return intakeDrafts;
      });

  Future<AssessmentSummary> fetchAssessmentSummary(String id) => _call(() async => AssessmentSummary(await db.from('assessments').select(AssessmentSummary.columns).eq('id', id).single()));

  Future<Assessment> fetchAssessment(String id) => _call(() async {
        final row = await db.from('assessments').select('*, assessment_findings(*), assessment_problems(*), assessment_goals(*)').eq('id', id).single();
        return Assessment.of(row);
      });

  /// Starts an assessment, optionally pre-filled from [copyFrom]. [childId] null starts the intake assessment of a
  /// child about to be created, with the [name] and [dob] typed on the Add child form (one step, so a dropped
  /// connection never leaves a half-made draft behind).
  Future<String> createAssessment({String? childId, required String kind, String? therapistId, String? copyFrom, String? name, String? dob}) => _call(() async {
        final id = await db.rpc('create_assessment', params: {
          'p_child': childId,
          'p_kind': kind,
          'p_therapist': therapistId,
          'p_copy_from': copyFrom,
          'p_name': childId == null ? name?.trim() : null,
          'p_dob': childId == null ? dob : null,
        }) as String;
        if (childId != null) await loadAssessments(childId).catchError((_) => const <AssessmentSummary>[]);
        return id;
      });

  /// Saves everything; returns the new revision. Throws [AssessmentConflict] if [rev] is out of date.
  Future<int> saveAssessment(String id, int rev, Json payload) =>
      _call(() async => ((await db.rpc('save_assessment', params: {'p_id': id, 'p_rev': rev, 'p_data': payload})) as num).toInt());

  /// Marks it completed (the server checks the essentials first); returns the new revision.
  Future<int> completeAssessment(String id, int rev) => _call(() async => ((await db.rpc('complete_assessment', params: {'p_id': id, 'p_rev': rev})) as num).toInt());

  /// Reloads a child's history and chart after an assessment changed state (completed, archived, deleted).
  /// (Families can't read assessment records, only the chart.)
  Future<void> refreshAssessments(String childId) async {
    await Future.wait([
      if (role != Role.parent) loadAssessments(childId).then((_) {}, onError: (_) {}),
      loadAssessmentTimeline(childId).then((_) {}, onError: (_) {}),
    ]);
  }

  Future<void> archiveAssessment(String id, bool archived) => _call(() => db.rpc('set_assessment_archived', params: {'p_id': id, 'p_archived': archived}));

  Future<void> deleteAssessment(String id) => _call(() => db.rpc('delete_assessment', params: {'p_id': id}));

  /// Whether the signed-in user may change an assessment with this [status], child and therapist. The server
  /// decides (`private.can_edit_assessment`); this only hides buttons that would fail.
  bool canEditAssessment({required String status, required String? childId, required String? assessedBy}) {
    if (status == 'archived') return false;
    if (isAdmin) return true;
    if (role != Role.therapist || childId == null) return false;
    return !(status == 'completed') || assessedBy == therapistId;
  }

  bool canStartAssessment(String childId) => isAdmin || role == Role.therapist;

  /// Sends assessment changes this device kept after failed saves (e.g. the app was closed while offline).
  /// One that was saved from elsewhere in the meantime is left for the editor to ask about when it's opened.
  /// Returns how many were sent.
  Future<int> syncPendingAssessments() async {
    final uid = userId;
    if (uid == null || offline) return 0;
    var n = 0;
    for (final id in await PendingAssessments.ids(uid)) {
      // One at a time with the editor: an assessment opened meanwhile waits for this, then finds nothing to recover.
      final sent = await PendingAssessments.exclusive(id, () async {
        final p = await PendingAssessments.read(uid, id);
        if (p == null) return false;
        try {
          await saveAssessment(id, p.rev, p.payload);
          await PendingAssessments.remove(uid, id);
          return true;
        } catch (_) {
          // Saved elsewhere since (the editor asks when it's opened), offline again, or no longer allowed: keep it.
          return false;
        }
      });
      if (sent) n++;
    }
    return n;
  }
}
