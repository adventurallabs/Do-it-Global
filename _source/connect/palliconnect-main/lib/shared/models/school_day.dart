class LearningItem {
  final String subject;
  final String topic;

  const LearningItem({required this.subject, required this.topic});

  String get label => '$subject $topic';
}

class GrowthSignal {
  final String name;
  final String indicator;

  const GrowthSignal({required this.name, required this.indicator});
}

class SchoolDaySnapshot {
  final String teacherNote;
  final List<LearningItem> learning;
  final List<GrowthSignal> growingIn;

  const SchoolDaySnapshot({
    required this.teacherNote,
    required this.learning,
    required this.growingIn,
  });
}
