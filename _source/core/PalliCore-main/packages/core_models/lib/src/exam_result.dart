import 'exam_timetable.dart';
import 'grade_scale.dart';
import 'mark.dart';

/// How one subject of one exam came out for one child.
enum PaperOutcome { pass, fail, absent, pending }

extension PaperOutcomeX on PaperOutcome {
  String get label => switch (this) {
        PaperOutcome.pass => 'Pass',
        PaperOutcome.fail => 'Fail',
        PaperOutcome.absent => 'Absent',
        PaperOutcome.pending => 'Awaited',
      };
}

/// One row of a mark statement.
class SubjectResult {
  final ExamPaper paper;
  final Mark? mark;

  /// The subject teacher has submitted this section's sheet. Until then a
  /// saved draft is not a result, and the row shows blank.
  final bool released;
  final ExamResultMode mode;
  final List<GradeBand> scale;

  const SubjectResult({
    required this.paper,
    this.mark,
    required this.released,
    this.mode = ExamResultMode.marks,
    this.scale = const [],
  });

  bool get hasResult => released && mark != null;

  /// Pass/fail follows what the exam records: a grades-only exam by the
  /// grade's own pass flag, otherwise by the paper's pass mark.
  PaperOutcome get outcome {
    final m = mark;
    if (!released || m == null) return PaperOutcome.pending;
    if (m.isAbsent) return PaperOutcome.absent;
    if (mode == ExamResultMode.grades) {
      final g = m.grade;
      if (g == null) return PaperOutcome.pending;
      return GradeScale.isPass(scale, g) ? PaperOutcome.pass : PaperOutcome.fail;
    }
    return m.score >= paper.passMarks ? PaperOutcome.pass : PaperOutcome.fail;
  }

  /// Null while awaited, absent, or when the exam has no marks.
  double? get score {
    final m = mark;
    if (!mode.usesMarks || !hasResult || m!.isAbsent) return null;
    return m.score;
  }

  String? get grade {
    final m = mark;
    if (!mode.usesGrades || !hasResult || m!.isAbsent) return null;
    return m.grade;
  }
}

/// A child's whole result for one exam — every paper their standard sits,
/// whether or not its marks are out yet.
class StudentExamResult {
  final String studentId;
  final List<SubjectResult> subjects;
  final ExamResultMode mode;
  final List<GradeBand> scale;

  const StudentExamResult({
    required this.studentId,
    required this.subjects,
    this.mode = ExamResultMode.marks,
    this.scale = const [],
  });

  /// [isReleased] decides whether a paper's marks count as out: for a parent,
  /// "the sheet was submitted"; for the admin, "a mark exists".
  factory StudentExamResult.build({
    required String studentId,
    required Iterable<ExamPaper> papers,
    required Iterable<Mark> marks,
    required bool Function(ExamPaper paper) isReleased,
    ExamResultMode mode = ExamResultMode.marks,
    List<GradeBand> scale = const [],
  }) {
    final byPaper = <String, Mark>{
      for (final m in marks)
        if (m.studentId == studentId && m.isExamPaper) m.paperId!: m,
    };
    final sorted = papers.toList()..sort(ExamPaper.compare);
    return StudentExamResult(
      studentId: studentId,
      mode: mode,
      scale: scale,
      subjects: [
        for (final p in sorted)
          SubjectResult(paper: p, mark: byPaper[p.id], released: isReleased(p), mode: mode, scale: scale),
      ],
    );
  }

  int get releasedCount => subjects.where((s) => s.hasResult).length;
  int get awaitedCount => subjects.length - releasedCount;
  bool get isComplete => subjects.isNotEmpty && awaitedCount == 0;

  double get scored => subjects.fold(0, (sum, s) => sum + (s.score ?? 0));
  double get maxTotal => subjects.fold(0, (sum, s) => sum + s.paper.maxMarks);
  double get releasedMax =>
      subjects.where((s) => s.hasResult).fold(0, (sum, s) => sum + s.paper.maxMarks);

  /// Only once every subject is out — a percentage over half the papers
  /// reads as a final score and misleads. Never for a grades-only exam.
  double? get percent =>
      mode.usesMarks && isComplete && maxTotal > 0 ? scored / maxTotal * 100 : null;

  /// The grade the overall percentage earns, when the scale is banded.
  String? get overallGrade {
    final p = percent;
    if (p == null || !mode.usesGrades) return null;
    return GradeScale.gradeFor(scale, p);
  }

  PaperOutcome get overall {
    if (!isComplete) return PaperOutcome.pending;
    final failed = subjects.any(
        (s) => s.outcome == PaperOutcome.fail || s.outcome == PaperOutcome.absent);
    return failed ? PaperOutcome.fail : PaperOutcome.pass;
  }
}
