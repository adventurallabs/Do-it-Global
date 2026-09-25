import 'mark.dart';

/// One column of a class's results: a single subject, tested once, on one day.
///
/// This is the unit a teacher actually records, the unit a parent reads as a
/// row in the report card, and therefore the unit the marks board lists and
/// re-opens for correction. Grouping marks any other way makes "edit the test
/// I entered yesterday" impossible to express.
class MarkSheet {
  final String subject;
  final String testType;

  /// Non-empty when the teacher tied this sheet to a formal exam, which is
  /// what makes the parent app group it into one report card instead of a
  /// loose test.
  final String examId;
  final DateTime date;
  final double totalMarks;
  final List<Mark> marks;

  const MarkSheet({
    required this.subject,
    required this.testType,
    required this.examId,
    required this.date,
    required this.totalMarks,
    required this.marks,
  });

  static String dayKey(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  /// Identity of the sheet a mark belongs to. Two marks share a sheet when
  /// they are the same exam-or-test, of the same subject, on the same day.
  static String keyOf(Mark mark) =>
      '${mark.examId}|${mark.subject.trim().toLowerCase()}|'
      '${mark.testType.trim().toLowerCase()}|${dayKey(mark.date)}';

  String get key => marks.isEmpty
      ? '$examId|${subject.trim().toLowerCase()}|${testType.trim().toLowerCase()}|${dayKey(date)}'
      : keyOf(marks.first);

  bool get isExam => examId.isNotEmpty;

  int get entered => marks.length;

  /// True when the same test was saved with different maximums — a typo worth
  /// showing rather than silently averaging over.
  bool get hasMixedTotals => marks.any((m) => m.totalMarks != totalMarks);

  double? get averagePercent {
    if (marks.isEmpty) return null;
    var sum = 0.0;
    var counted = 0;
    for (final m in marks) {
      if (m.totalMarks <= 0) continue;
      sum += (m.score / m.totalMarks) * 100;
      counted++;
    }
    return counted == 0 ? null : sum / counted;
  }

  double? get highest =>
      marks.isEmpty ? null : marks.map((m) => m.score).reduce((a, b) => a > b ? a : b);

  double? get lowest =>
      marks.isEmpty ? null : marks.map((m) => m.score).reduce((a, b) => a < b ? a : b);

  Mark? forStudent(String studentId) {
    for (final m in marks) {
      if (m.studentId == studentId) return m;
    }
    return null;
  }

  /// Bundles loose marks into sheets, newest day first, then by subject.
  static List<MarkSheet> group(Iterable<Mark> marks) {
    final buckets = <String, List<Mark>>{};
    for (final mark in marks) {
      buckets.putIfAbsent(keyOf(mark), () => []).add(mark);
    }
    final sheets = <MarkSheet>[];
    for (final bucket in buckets.values) {
      // The most recently written row wins for the sheet's own fields, so a
      // corrected maximum shows through instead of the original typo.
      final first = bucket.first;
      sheets.add(MarkSheet(
        subject: first.subject,
        testType: first.testType,
        examId: first.examId,
        date: first.date,
        totalMarks: _commonTotal(bucket),
        marks: bucket,
      ));
    }
    sheets.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      final bySubject = a.subject.toLowerCase().compareTo(b.subject.toLowerCase());
      return bySubject != 0 ? bySubject : a.testType.compareTo(b.testType);
    });
    return sheets;
  }

  /// The maximum most of the sheet agrees on — one mistyped row shouldn't
  /// redefine what the test was out of.
  static double _commonTotal(List<Mark> marks) {
    final counts = <double, int>{};
    for (final m in marks) {
      counts[m.totalMarks] = (counts[m.totalMarks] ?? 0) + 1;
    }
    var best = marks.first.totalMarks;
    var bestCount = 0;
    counts.forEach((total, count) {
      if (count > bestCount || (count == bestCount && total > best)) {
        best = total;
        bestCount = count;
      }
    });
    return best;
  }
}
