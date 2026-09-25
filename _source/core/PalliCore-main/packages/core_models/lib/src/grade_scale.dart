import 'package:json_annotation/json_annotation.dart';

/// How an exam's results are recorded. Chosen when the exam is created and
/// fixed once any mark exists (the database enforces that).
enum ExamResultMode {
  @JsonValue('marks')
  marks,
  @JsonValue('grades')
  grades,
  @JsonValue('marks_grades')
  marksAndGrades,
}

extension ExamResultModeX on ExamResultMode {
  bool get usesMarks => this != ExamResultMode.grades;
  bool get usesGrades => this != ExamResultMode.marks;

  String get label => switch (this) {
        ExamResultMode.marks => 'Marks',
        ExamResultMode.grades => 'Grades',
        ExamResultMode.marksAndGrades => 'Marks & grades',
      };

  String get description => switch (this) {
        ExamResultMode.marks => 'Teachers enter a mark out of the paper\'s total.',
        ExamResultMode.grades => 'Teachers pick a grade — no marks.',
        ExamResultMode.marksAndGrades => 'Teachers enter a mark and a grade for each student.',
      };
}

/// One grade on a scale. [min] is the lowest percentage that earns it, when
/// the scale is percentage-based; descriptive scales leave it null.
class GradeBand {
  final String label;
  final double? min;
  final bool pass;

  const GradeBand({required this.label, this.min, this.pass = true});

  factory GradeBand.fromJson(Map<String, dynamic> json) => GradeBand(
        label: (json['label'] ?? '').toString(),
        min: (json['min'] as num?)?.toDouble(),
        pass: json['pass'] != false,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        if (min != null) 'min': min,
        'pass': pass,
      };

  @override
  bool operator ==(Object other) =>
      other is GradeBand && other.label == label && other.min == min && other.pass == pass;

  @override
  int get hashCode => Object.hash(label, min, pass);
}

class GradeScalePreset {
  final String id;
  final String name;
  final String hint;
  final List<GradeBand> bands;
  const GradeScalePreset({required this.id, required this.name, required this.hint, required this.bands});
}

/// Grade scales and the arithmetic on them. Bands run best → worst.
class GradeScale {
  GradeScale._();

  static const presets = <GradeScalePreset>[
    GradeScalePreset(
      id: 'cbse',
      name: 'A1 – E',
      hint: '8 grades by percentage · E is a fail',
      bands: [
        GradeBand(label: 'A1', min: 91),
        GradeBand(label: 'A2', min: 81),
        GradeBand(label: 'B1', min: 71),
        GradeBand(label: 'B2', min: 61),
        GradeBand(label: 'C1', min: 51),
        GradeBand(label: 'C2', min: 41),
        GradeBand(label: 'D', min: 33),
        GradeBand(label: 'E', min: 0, pass: false),
      ],
    ),
    GradeScalePreset(
      id: 'ae',
      name: 'A – E',
      hint: '5 grades by percentage · E is a fail',
      bands: [
        GradeBand(label: 'A', min: 80),
        GradeBand(label: 'B', min: 60),
        GradeBand(label: 'C', min: 45),
        GradeBand(label: 'D', min: 35),
        GradeBand(label: 'E', min: 0, pass: false),
      ],
    ),
    GradeScalePreset(
      id: 'descriptive',
      name: 'Descriptive',
      hint: 'For early years · no fail grade',
      bands: [
        GradeBand(label: 'Outstanding'),
        GradeBand(label: 'Very good'),
        GradeBand(label: 'Good'),
        GradeBand(label: 'Satisfactory'),
        GradeBand(label: 'Needs support'),
      ],
    ),
  ];

  static GradeScalePreset? presetMatching(List<GradeBand> bands) {
    for (final p in presets) {
      if (p.bands.length == bands.length &&
          List.generate(bands.length, (i) => p.bands[i] == bands[i]).every((x) => x)) {
        return p;
      }
    }
    return null;
  }

  /// True when every band carries a percentage, so a grade can be suggested
  /// from a mark.
  static bool isBanded(List<GradeBand> bands) => bands.isNotEmpty && bands.every((b) => b.min != null);

  /// The grade a percentage earns, or null when the scale isn't banded.
  static String? gradeFor(List<GradeBand> bands, double percent) {
    if (!isBanded(bands)) return null;
    final sorted = [...bands]..sort((a, b) => b.min!.compareTo(a.min!));
    for (final b in sorted) {
      if (percent >= b.min!) return b.label;
    }
    return sorted.last.label;
  }

  static GradeBand? band(List<GradeBand> bands, String? label) {
    if (label == null) return null;
    for (final b in bands) {
      if (b.label == label) return b;
    }
    return null;
  }

  static bool isPass(List<GradeBand> bands, String label) => band(bands, label)?.pass ?? true;

  /// Problems with a custom scale, or null when it is usable.
  static String? validate(List<GradeBand> bands) {
    if (bands.length < 2) return 'A scale needs at least two grades.';
    final seen = <String>{};
    for (final b in bands) {
      final l = b.label.trim();
      if (l.isEmpty) return 'Every grade needs a name.';
      if (l.length > 16) return 'Keep grade names short (16 letters at most).';
      if (!seen.add(l.toLowerCase())) return '"$l" appears twice.';
    }
    return null;
  }
}
