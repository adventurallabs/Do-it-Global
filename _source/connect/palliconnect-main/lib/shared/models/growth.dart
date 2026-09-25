enum ObservationTone { positive, neutral, attention }

class GrowthObservation {
  final String id;
  final String title;
  final String body;
  final String source; // teacher name
  final DateTime date;
  final ObservationTone tone;
  final String category;

  const GrowthObservation({
    required this.id,
    required this.title,
    required this.body,
    required this.source,
    required this.date,
    this.tone = ObservationTone.positive,
    this.category = '',
  });
}

class AssessedSkill {
  final String name;
  final String level; // 'Emerging' | 'Developing' | 'Proficient' | 'Advanced'
  final String category;
  final DateTime? updatedAt;

  const AssessedSkill({
    required this.name,
    required this.level,
    this.category = '',
    this.updatedAt,
  });

  static const levels = ['Emerging', 'Developing', 'Proficient', 'Advanced'];

  /// 1..4, or 0 when the level text isn't on the scale.
  int get step {
    final i = levels.indexWhere((l) => l.toLowerCase() == level.toLowerCase());
    return i < 0 ? 0 : i + 1;
  }
}

/// What teachers have recorded about the child's growth.
class GrowthProfile {
  final List<GrowthObservation> observations;
  final List<AssessedSkill> skills;

  const GrowthProfile({
    required this.observations,
    required this.skills,
  });

  bool get isEmpty => observations.isEmpty && skills.isEmpty;
}

/// A star a teacher gave for something good the child did.
class StarAward {
  final String id;
  final int points;
  final String reason;
  final String teacherName;
  final DateTime date;

  const StarAward({
    required this.id,
    required this.points,
    required this.reason,
    required this.teacherName,
    required this.date,
  });
}

class StarSummary {
  final List<StarAward> awards;
  const StarSummary(this.awards);

  static const empty = StarSummary([]);

  int get total => awards.fold(0, (sum, a) => sum + a.points);

  int get thisWeek {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return awards.where((a) => !a.date.isBefore(start)).fold(0, (sum, a) => sum + a.points);
  }

  StarAward? get latest => awards.isEmpty ? null : awards.first;
}
