import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import 'remote_sync.dart';

/// Everything one exam is made of, loaded in one go: the standards taking it,
/// their timetables, and how far each section's marks have got.
class ExamOverview {
  final Exam exam;
  final List<ExamSchedule> schedules;
  final List<ExamPaper> papers;
  final List<ExamMarkSheet> sheets;

  const ExamOverview({
    required this.exam,
    this.schedules = const [],
    this.papers = const [],
    this.sheets = const [],
  });

  ExamSchedule? scheduleFor(String gradeKey) {
    for (final s in schedules) {
      if (s.gradeKey == gradeKey) return s;
    }
    return null;
  }

  List<ExamPaper> papersFor(String gradeKey) =>
      papers.where((p) => p.gradeKey == gradeKey).toList()..sort(ExamPaper.compare);

  ExamMarkSheet? sheetFor(String paperId, String classroomId) {
    for (final s in sheets) {
      if (s.paperId == paperId && s.classroomId == classroomId) return s;
    }
    return null;
  }

  /// Where the whole exam stands today, from its first to its last paper.
  ExamPhase get phase {
    if (papers.isEmpty) return ExamPhase.upcoming;
    return ExamDates.phase(papers.first.examDate, papers.last.examDate);
  }

  /// Published standards only, in grade order — what teachers and parents see.
  List<ExamSchedule> get published =>
      schedules.where((s) => s.isPublished).toList();
}

/// Exams, their per-standard timetables, and formal exam marks.
///
/// Every write throws on failure. The admin publishing a timetable or a
/// teacher submitting marks must never be told it worked when it didn't —
/// the old `writeLocalThenRemote` path swallowed exactly that.
class ExamRepository extends BaseRepository<Exam> {
  ExamRepository(SupabaseClient client) : super(client, 'exams');

  /// Offline cache only — never seeded with invented exams.
  static final List<Exam> _items = [];

  static String newId(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_${now.toRadixString(36)}';
  }

  /// Stable per paper + student, so a re-save overwrites instead of adding a
  /// second score.
  static String markId(String paperId, String studentId) => 'xm_${paperId}_$studentId';

  // ------------------------------------------------------------------ exams

  @override
  Future<List<Exam>> getAll() {
    return remoteOrLocal(
      () async {
        final rows = await client.from(tableName).select().order('start_date', ascending: false);
        final remote = (rows as List)
            .map((j) => Exam.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        _items
          ..clear()
          ..addAll(remote);
        return List<Exam>.from(remote);
      },
      () => List<Exam>.from(_items),
    );
  }

  @override
  Future<Exam?> getById(String id) async {
    final rows = await client.from(tableName).select().eq('id', id).limit(1).timeout(kRemoteTimeout);
    final list = rows as List;
    return list.isEmpty ? null : Exam.fromJson(Map<String, dynamic>.from(list.first as Map));
  }

  @override
  Future<void> upsert(Exam item) async {
    await client.from(tableName).upsert(item.toJson()).timeout(kRemoteTimeout);
  }

  @override
  Future<void> delete(String id) async {
    // Schedules, papers, sheets and exam marks all cascade.
    await client.from(tableName).delete().eq('id', id).timeout(kRemoteTimeout);
    _items.removeWhere((e) => e.id == id);
  }

  /// Creates the exam and an empty draft timetable for each standard.
  Future<void> createExam(Exam exam) async {
    await client.from(tableName).insert(exam.toJson()).timeout(kRemoteTimeout);
    if (exam.gradeKeys.isNotEmpty) {
      await client
          .from('exam_schedules')
          .insert([
            for (final g in exam.gradeKeys)
              ExamSchedule(examId: exam.id, gradeKey: g).toInsertJson(),
          ])
          .timeout(kRemoteTimeout);
    }
  }

  /// Renames the exam and brings its standards in line with [exam.gradeKeys]:
  /// new standards get an empty timetable, removed ones lose theirs (and any
  /// marks entered against it — the caller confirms that first).
  Future<void> updateExam(Exam exam, {required List<String> previousGrades}) async {
    await client.from(tableName).upsert(exam.toJson()).timeout(kRemoteTimeout);
    final added = exam.gradeKeys.where((g) => !previousGrades.contains(g)).toList();
    final removed = previousGrades.where((g) => !exam.gradeKeys.contains(g)).toList();
    if (added.isNotEmpty) {
      await client
          .from('exam_schedules')
          .upsert(
            [for (final g in added) ExamSchedule(examId: exam.id, gradeKey: g).toInsertJson()],
            onConflict: 'exam_id,grade_key',
            ignoreDuplicates: true,
          )
          .timeout(kRemoteTimeout);
    }
    if (removed.isNotEmpty) {
      await client
          .from('exam_schedules')
          .delete()
          .eq('exam_id', exam.id)
          .inFilter('grade_key', removed)
          .timeout(kRemoteTimeout);
    }
  }

  /// One exam with everything under it. Three reads fired together.
  Future<ExamOverview> overview(String examId, {Exam? exam}) async {
    final results = await Future.wait<dynamic>([
      if (exam == null) client.from(tableName).select().eq('id', examId).single(),
      client.from('exam_schedules').select().eq('exam_id', examId),
      client.from('exam_papers').select().eq('exam_id', examId),
      client.from('exam_mark_sheets').select().eq('exam_id', examId),
    ]).timeout(kRemoteTimeout);
    var i = 0;
    final resolved = exam ?? Exam.fromJson(Map<String, dynamic>.from(results[i++] as Map));
    return ExamOverview(
      exam: resolved,
      schedules: _list(results[i++], ExamSchedule.fromJson),
      papers: _list(results[i++], ExamPaper.fromJson)..sort(ExamPaper.compare),
      sheets: _list(results[i], ExamMarkSheet.fromJson),
    );
  }

  /// Every exam with its schedules, papers and sheets — the list screens.
  /// Four queries total, however many exams there are.
  Future<List<ExamOverview>> overviews({bool publishedOnly = false}) async {
    final results = await Future.wait<dynamic>([
      client.from(tableName).select().order('start_date', ascending: false),
      publishedOnly
          ? client.from('exam_schedules').select().eq('status', 'published')
          : client.from('exam_schedules').select(),
      client.from('exam_papers').select(),
      client.from('exam_mark_sheets').select(),
    ]).timeout(kRemoteTimeout);
    final exams = _list(results[0], Exam.fromJson);
    final schedules = _list(results[1], ExamSchedule.fromJson);
    final papers = _list(results[2], ExamPaper.fromJson);
    final sheets = _list(results[3], ExamMarkSheet.fromJson);
    final byExam = <String, List<ExamSchedule>>{};
    for (final s in schedules) {
      byExam.putIfAbsent(s.examId, () => []).add(s);
    }
    final papersByExam = <String, List<ExamPaper>>{};
    final shownGrades = {for (final s in schedules) s.key};
    for (final p in papers) {
      // A teacher never sees a draft standard's papers.
      if (publishedOnly && !shownGrades.contains('${p.examId}|${p.gradeKey}')) continue;
      papersByExam.putIfAbsent(p.examId, () => []).add(p);
    }
    final sheetsByExam = <String, List<ExamMarkSheet>>{};
    for (final s in sheets) {
      sheetsByExam.putIfAbsent(s.examId, () => []).add(s);
    }
    _items
      ..clear()
      ..addAll(exams);
    return [
      for (final e in exams)
        if (!publishedOnly || byExam.containsKey(e.id))
          ExamOverview(
            exam: e,
            schedules: byExam[e.id] ?? const [],
            papers: (papersByExam[e.id] ?? <ExamPaper>[])..sort(ExamPaper.compare),
            sheets: sheetsByExam[e.id] ?? const [],
          ),
    ];
  }

  // ----------------------------------------------------------------- papers

  Future<ExamPaper> savePaper(ExamPaper paper) async {
    final row = await client
        .from('exam_papers')
        .upsert(paper.toJson())
        .select()
        .single()
        .timeout(kRemoteTimeout);
    return ExamPaper.fromJson(Map<String, dynamic>.from(row));
  }

  /// Also removes every mark entered against it.
  Future<void> deletePaper(String paperId) async {
    await client.from('exam_papers').delete().eq('id', paperId).timeout(kRemoteTimeout);
  }

  Future<ExamSchedule?> schedule(String examId, String gradeKey) async {
    final rows = await client
        .from('exam_schedules')
        .select()
        .eq('exam_id', examId)
        .eq('grade_key', gradeKey)
        .limit(1)
        .timeout(kRemoteTimeout);
    final list = rows as List;
    return list.isEmpty ? null : ExamSchedule.fromJson(Map<String, dynamic>.from(list.first as Map));
  }

  /// Publishes (or re-shares after edits) one standard's timetable and
  /// notifies its parents, class teachers and subject teachers. Returns how
  /// many parents were told.
  Future<int> publish(String examId, String gradeKey) async {
    final result = await client
        .rpc('publish_exam_schedule', params: {'p_exam': examId, 'p_grade': gradeKey})
        .timeout(kRemoteTimeout);
    return (result as num?)?.toInt() ?? 0;
  }

  // ------------------------------------------------------------------ marks

  Future<List<ExamMarkSheet>> sheets({required String examId, String? classroomId}) async {
    var q = client.from('exam_mark_sheets').select().eq('exam_id', examId);
    if (classroomId != null) q = q.eq('classroom_id', classroomId);
    return _list(await q.timeout(kRemoteTimeout), ExamMarkSheet.fromJson);
  }

  Future<ExamMarkSheet?> sheet(String paperId, String classroomId) async {
    final rows = await client
        .from('exam_mark_sheets')
        .select()
        .eq('paper_id', paperId)
        .eq('classroom_id', classroomId)
        .limit(1)
        .timeout(kRemoteTimeout);
    final list = rows as List;
    return list.isEmpty ? null : ExamMarkSheet.fromJson(Map<String, dynamic>.from(list.first as Map));
  }

  /// One section's marks for one paper.
  Future<List<Mark>> paperMarks(String paperId, String classroomId) async {
    final rows = await client
        .from('marks')
        .select()
        .eq('paper_id', paperId)
        .eq('classroom_id', classroomId)
        .timeout(kRemoteTimeout);
    return _list(rows, Mark.fromJson);
  }

  /// Every exam mark for this exam in one section (or for given students).
  Future<List<Mark>> examMarks(String examId, {String? classroomId, List<String>? studentIds}) async {
    var q = client.from('marks').select().eq('exam_id', examId).not('paper_id', 'is', null);
    if (classroomId != null) q = q.eq('classroom_id', classroomId);
    if (studentIds != null) {
      if (studentIds.isEmpty) return const [];
      q = q.inFilter('student_id', studentIds);
    }
    return _list(await q.timeout(kRemoteTimeout), Mark.fromJson);
  }

  /// A draft save: writes what's typed, removes what was cleared, and records
  /// progress on the sheet. Throws — including the database's own refusal
  /// once the sheet has been submitted.
  Future<void> saveDraft({
    required ExamPaper paper,
    required String classroomId,
    required String teacherId,
    required List<Mark> marks,
    List<String> clearedIds = const [],
    required int enteredCount,
  }) async {
    if (marks.isNotEmpty) {
      await client
          .from('marks')
          .upsert(marks.map((m) => m.toJson()).toList())
          .timeout(kRemoteTimeout);
    }
    if (clearedIds.isNotEmpty) {
      await client.from('marks').delete().inFilter('id', clearedIds).timeout(kRemoteTimeout);
    }
    await client
        .from('exam_mark_sheets')
        .upsert(
          ExamMarkSheet(
            paperId: paper.id,
            classroomId: classroomId,
            examId: paper.examId,
            subject: paper.subject,
            enteredCount: enteredCount,
            teacherId: teacherId,
          ).toDraftJson(),
          onConflict: 'paper_id,classroom_id',
        )
        .timeout(kRemoteTimeout);
  }

  /// Locks the sheet and releases it to parents. The database re-checks that
  /// every student has a mark or AB, and that the caller teaches the subject.
  Future<int> submit(String paperId, String classroomId) async {
    final result = await client
        .rpc('submit_exam_marks', params: {'p_paper': paperId, 'p_classroom': classroomId})
        .timeout(kRemoteTimeout);
    return (result as num?)?.toInt() ?? 0;
  }

  /// Admin only: hands a submitted sheet back to its teacher to correct.
  Future<void> reopenSheet(String paperId, String classroomId) async {
    await client
        .from('exam_mark_sheets')
        .update({'status': 'draft', 'submitted_at': null, 'submitted_by': null})
        .eq('paper_id', paperId)
        .eq('classroom_id', classroomId)
        .timeout(kRemoteTimeout);
  }

  /// Admin correction of one student's marks across subjects.
  Future<void> saveStudentMarks({required List<Mark> upserts, List<String> clearedIds = const []}) async {
    if (upserts.isNotEmpty) {
      await client
          .from('marks')
          .upsert(upserts.map((m) => m.toJson()).toList())
          .timeout(kRemoteTimeout);
    }
    if (clearedIds.isNotEmpty) {
      await client.from('marks').delete().inFilter('id', clearedIds).timeout(kRemoteTimeout);
    }
  }

  /// Live sheet progress for one exam — the admin's results screen updates
  /// as teachers submit, without pulling to refresh.
  Stream<List<ExamMarkSheet>> watchSheets(String examId) {
    try {
      return client
          .from('exam_mark_sheets')
          .stream(primaryKey: ['paper_id', 'classroom_id'])
          .eq('exam_id', examId)
          .map((rows) => rows.map((j) => ExamMarkSheet.fromJson(Map<String, dynamic>.from(j))).toList());
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Plain-language text for a database refusal (lock, scope, range).
  static String describeError(Object error) {
    if (error is PostgrestException) {
      final msg = error.message.trim();
      if (msg.isNotEmpty) return msg;
    }
    final text = error.toString();
    if (text.contains('TimeoutException') || text.contains('SocketException')) {
      return "Couldn't reach the school server. Check your connection and try again.";
    }
    return 'Something went wrong. Please try again.';
  }

  static List<T> _list<T>(Object? rows, T Function(Map<String, dynamic>) fromJson) {
    return (rows as List).map((j) => fromJson(Map<String, dynamic>.from(j as Map))).toList();
  }
}
