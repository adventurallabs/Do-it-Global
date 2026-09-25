import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';

ExamPhase examPhaseOf(ExamOverview overview) => overview.phase;

List<String> sortGrades(Iterable<String> keys) => GradeCatalog.sortKeys(keys);

/// How many section-subject sheets an exam needs, and how many are in.
/// Expected = papers of a standard × its sections.
class ResultsProgress {
  final int expected;
  final int submitted;

  /// grade → (submitted, expected), in grade order.
  final Map<String, (int, int)> byGrade;

  const ResultsProgress({required this.expected, required this.submitted, required this.byGrade});

  factory ResultsProgress.of(ExamOverview overview, List<Classroom> classrooms) {
    final byGrade = <String, (int, int)>{};
    var expected = 0;
    var submitted = 0;
    for (final grade in GradeCatalog.sortKeys(overview.papers.map((p) => p.gradeKey))) {
      final sections = ExamPlanning.sectionsOf(grade, classrooms);
      final papers = overview.papersFor(grade);
      final need = papers.length * sections.length;
      var done = 0;
      for (final p in papers) {
        for (final c in sections) {
          if (overview.sheetFor(p.id, c.id)?.isSubmitted == true) done++;
        }
      }
      byGrade[grade] = (done, need);
      expected += need;
      submitted += done;
    }
    return ResultsProgress(expected: expected, submitted: submitted, byGrade: byGrade);
  }
}
