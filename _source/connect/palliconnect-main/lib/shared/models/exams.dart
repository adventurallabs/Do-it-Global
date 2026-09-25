/// Exam timetables and results as a parent reads them. The school side
/// builds these per standard (every section sits the same papers), and marks
/// per section; a parent only ever sees what has been published/submitted —
/// the database enforces that, not this code.

enum ExamPhase { upcoming, ongoing, past }

/// What the exam records — chosen by the school when it creates the exam.
enum ExamResultMode { marks, grades, marksAndGrades }

extension ExamResultModeX on ExamResultMode {
  bool get usesMarks => this != ExamResultMode.grades;
  bool get usesGrades => this != ExamResultMode.marks;

  static ExamResultMode parse(Object? v) => switch (v) {
        'grades' => ExamResultMode.grades,
        'marks_grades' => ExamResultMode.marksAndGrades,
        _ => ExamResultMode.marks,
      };
}

/// One grade on the exam's scale, best first. [min] is a percentage when the
/// scale is percentage-based; descriptive scales have none.
class GradeBand {
  final String label;
  final double? min;
  final bool pass;

  const GradeBand({required this.label, this.min, this.pass = true});

  factory GradeBand.fromJson(Map<String, dynamic> j) => GradeBand(
        label: (j['label'] ?? '').toString(),
        min: (j['min'] as num?)?.toDouble(),
        pass: j['pass'] != false,
      );
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

int _minutes(String hhmm) {
  final p = hhmm.split(':');
  if (p.length != 2) return 0;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

ExamPhase phaseBetween(DateTime? first, DateTime? last, {DateTime? now}) {
  final today = _day(now ?? DateTime.now());
  if (first == null || last == null) return ExamPhase.upcoming;
  if (today.isBefore(_day(first))) return ExamPhase.upcoming;
  if (today.isAfter(_day(last))) return ExamPhase.past;
  return ExamPhase.ongoing;
}

/// Whole days from today to [date] (negative once it has passed).
int daysUntil(DateTime date, {DateTime? now}) =>
    _day(date).difference(_day(now ?? DateTime.now())).inDays;

String fmtMarks(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

class ExamPaper {
  final String id;
  final String subject;
  final DateTime date;
  final String startTime; // 'HH:mm'
  final String endTime;
  final String syllabus;
  final double maxMarks;
  final double passMarks;

  const ExamPaper({
    required this.id,
    required this.subject,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.syllabus = '',
    this.maxMarks = 100,
    this.passMarks = 35,
  });

  int get startMinutes => _minutes(startTime);
  int get endMinutes => _minutes(endTime);

  bool get isToday => daysUntil(date) == 0;

  ExamPhase get phase {
    final now = DateTime.now();
    final p = phaseBetween(date, date, now: now);
    if (p != ExamPhase.ongoing) return p;
    final m = now.hour * 60 + now.minute;
    if (m < startMinutes) return ExamPhase.upcoming;
    if (m >= endMinutes) return ExamPhase.past;
    return ExamPhase.ongoing;
  }

  static int compare(ExamPaper a, ExamPaper b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    return a.startMinutes.compareTo(b.startMinutes);
  }
}

/// One exam, as the child's standard sits it.
class ParentExam {
  final String examId;
  final String name;
  final String gradeKey;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime? publishedAt;
  final List<ExamPaper> papers;
  final ExamResultMode mode;
  final List<GradeBand> scale;

  const ParentExam({
    required this.examId,
    required this.name,
    required this.gradeKey,
    this.firstDate,
    this.lastDate,
    this.publishedAt,
    this.papers = const [],
    this.mode = ExamResultMode.marks,
    this.scale = const [],
  });

  ExamPhase get phase => phaseBetween(firstDate, lastDate);

  ExamPaper? get nextPaper {
    for (final p in papers) {
      if (p.phase != ExamPhase.past) return p;
    }
    return null;
  }

  GradeBand? band(String? label) {
    if (label == null) return null;
    for (final b in scale) {
      if (b.label == label) return b;
    }
    return null;
  }

  /// The grade a percentage earns on a percentage-based scale.
  String? gradeFor(double percent) {
    if (scale.isEmpty || scale.any((b) => b.min == null)) return null;
    final sorted = [...scale]..sort((a, b) => b.min!.compareTo(a.min!));
    for (final b in sorted) {
      if (percent >= b.min!) return b.label;
    }
    return sorted.last.label;
  }
}

enum SubjectOutcome { pass, fail, absent, awaited }

class ResultRow {
  final ParentExam exam;
  final ExamPaper paper;

  /// Null while the subject teacher hasn't submitted — the row stays in the
  /// table, blank. Always null for a grades-only exam.
  final double? score;
  final String? grade;
  final bool absent;

  /// The row has been released (a mark row exists for it).
  final bool released;

  const ResultRow({
    required this.exam,
    required this.paper,
    this.score,
    this.grade,
    this.absent = false,
    this.released = false,
  });

  bool get isOut => released;

  /// A grades-only exam passes on the grade's own pass flag; otherwise the
  /// paper's pass mark decides.
  SubjectOutcome get outcome {
    if (!released) return SubjectOutcome.awaited;
    if (absent) return SubjectOutcome.absent;
    if (exam.mode == ExamResultMode.grades) {
      final b = exam.band(grade);
      if (b == null) return SubjectOutcome.awaited;
      return b.pass ? SubjectOutcome.pass : SubjectOutcome.fail;
    }
    final s = score;
    if (s == null) return SubjectOutcome.awaited;
    return s >= paper.passMarks ? SubjectOutcome.pass : SubjectOutcome.fail;
  }
}

/// A child's result for one exam: every subject their standard sits.
class ExamResultSheet {
  final ParentExam exam;
  final List<ResultRow> rows;

  const ExamResultSheet({required this.exam, required this.rows});

  int get releasedCount => rows.where((r) => r.isOut).length;
  int get awaitedCount => rows.length - releasedCount;
  bool get isComplete => rows.isNotEmpty && awaitedCount == 0;

  double get scored => rows.fold(0, (s, r) => s + (r.absent ? 0 : (r.score ?? 0)));
  double get maxTotal => rows.fold(0, (s, r) => s + r.paper.maxMarks);

  /// Never for a grades-only exam.
  double? get percent =>
      exam.mode.usesMarks && isComplete && maxTotal > 0 ? scored / maxTotal * 100 : null;

  String? get overallGrade {
    final p = percent;
    if (p == null || !exam.mode.usesGrades) return null;
    return exam.gradeFor(p);
  }

  /// Null while any subject is awaited.
  bool? get passed {
    if (!isComplete) return null;
    return rows.every((r) => r.outcome == SubjectOutcome.pass);
  }
}

/// 'LKG' → 'LKG', '4' → '4th Std' — matches how the school app names classes.
String gradeLabel(String key) {
  switch (key) {
    case 'LKG':
    case 'UKG':
      return key;
    case '1':
      return '1st Std';
    case '2':
      return '2nd Std';
    case '3':
      return '3rd Std';
    default:
      return int.tryParse(key) != null ? '${key}th Std' : key;
  }
}
