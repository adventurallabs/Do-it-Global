class SchoolActivity {
  final String id;
  final String studentId;
  final String name;
  final DateTime date;
  final String category;
  final String? achievement;
  final String? result;
  final String? teacherRemarks;
  final String? documentLabel;

  const SchoolActivity({
    required this.id,
    required this.studentId,
    required this.name,
    required this.date,
    required this.category,
    this.achievement,
    this.result,
    this.teacherRemarks,
    this.documentLabel,
  });
}
