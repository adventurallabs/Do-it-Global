class ExamResult {
  final String examName;
  final String examGroup;
  final String subject;
  final int scored;
  final int maxMarks;

  const ExamResult({
    required this.examName,
    required this.examGroup,
    required this.subject,
    required this.scored,
    required this.maxMarks,
  });
}

class SubjectProgress {
  final String subject;
  final List<ExamResult> results;

  const SubjectProgress({required this.subject, required this.results});

  int? get averagePercent {
    if (results.isEmpty) return null;
    final total = results.fold<double>(
      0,
      (sum, r) => sum + (r.scored / r.maxMarks) * 100,
    );
    return (total / results.length).round();
  }
}
