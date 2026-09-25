import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_provider.dart';
import '../../core/data/parent_repository.dart';
import '../../shared/models/exams.dart';
import '../parent/parent_store.dart';

/// Published exam timetables for the current child. Refetches on its own when
/// the school publishes or edits one (see [examFeedTickProvider]).
/// Errors propagate so the screen can offer a retry instead of "no exams".
final parentExamsProvider = FutureProvider<List<ParentExam>>((ref) async {
  ref.watch(examFeedTickProvider);
  final student = ref.watch(currentStudentProvider);
  if (student == null) return const [];
  return ref.read(parentRepositoryProvider).examTimetables();
});

/// The child's released exam marks, keyed by paper id.
final parentExamMarksProvider = FutureProvider<Map<String, ({double score, bool absent, String? grade})>>((ref) async {
  // Refetches only when this child's marks or mark sheets change (the store's
  // channel bumps the tick) — not on every attendance or homework sync.
  ref.watch(examFeedTickProvider);
  final student = ref.watch(currentStudentProvider);
  if (student == null) return const {};
  return ref.read(parentRepositoryProvider).examMarks(student.id);
});

/// Every exam's result statement for this child — all subjects their
/// standard sits, released or not. Only exams that have started, or already
/// have a mark out, are listed.
final parentExamResultsProvider = Provider<AsyncValue<List<ExamResultSheet>>>((ref) {
  final exams = ref.watch(parentExamsProvider);
  final marks = ref.watch(parentExamMarksProvider);
  if (exams.hasError) return AsyncValue.error(exams.error!, exams.stackTrace ?? StackTrace.current);
  if (marks.hasError) return AsyncValue.error(marks.error!, marks.stackTrace ?? StackTrace.current);
  final e = exams.valueOrNull;
  final m = marks.valueOrNull;
  if (e == null || m == null) return const AsyncValue.loading();
  final sheets = <ExamResultSheet>[];
  for (final exam in e) {
    final rows = [
      for (final p in exam.papers)
        ResultRow(
          exam: exam,
          paper: p,
          released: m[p.id] != null,
          score: m[p.id] == null || m[p.id]!.absent || !exam.mode.usesMarks ? null : m[p.id]!.score,
          grade: m[p.id] == null || m[p.id]!.absent || !exam.mode.usesGrades ? null : m[p.id]!.grade,
          absent: m[p.id]?.absent ?? false,
        ),
    ];
    final sheet = ExamResultSheet(exam: exam, rows: rows);
    if (exam.phase == ExamPhase.upcoming && sheet.releasedCount == 0) continue;
    sheets.add(sheet);
  }
  return AsyncValue.data(sheets);
});

/// The Today / Progress card lines.
final examSummaryProvider = Provider<({ParentExam? ongoing, ParentExam? upcoming, ExamResultSheet? latest})>((ref) {
  final exams = ref.watch(parentExamsProvider).valueOrNull ?? const <ParentExam>[];
  final results = ref.watch(parentExamResultsProvider).valueOrNull ?? const <ExamResultSheet>[];
  ParentExam? ongoing;
  ParentExam? upcoming;
  for (final e in exams) {
    if (e.phase == ExamPhase.ongoing) ongoing ??= e;
    if (e.phase == ExamPhase.upcoming) {
      if (upcoming == null || (e.firstDate ?? DateTime(2100)).isBefore(upcoming.firstDate ?? DateTime(2100))) {
        upcoming = e;
      }
    }
  }
  final withMarks = results.where((r) => r.releasedCount > 0).toList();
  return (
    ongoing: ongoing,
    upcoming: upcoming,
    latest: withMarks.isEmpty ? null : withMarks.first,
  );
});
