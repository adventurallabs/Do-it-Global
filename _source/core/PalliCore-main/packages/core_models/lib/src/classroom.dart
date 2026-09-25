import 'package:json_annotation/json_annotation.dart';
import 'grade_catalog.dart';

part 'classroom.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Classroom {
  final String id;
  final String name;
  final String classTeacherId;
  final double baseFees;
  @JsonKey(defaultValue: '')
  final String gradeKey;
  @JsonKey(defaultValue: '')
  final String section;

  Classroom({
    required this.id,
    required this.name,
    required this.classTeacherId,
    required this.baseFees,
    this.gradeKey = '',
    this.section = '',
  });

  String get resolvedGradeKey {
    if (gradeKey.isNotEmpty) return gradeKey;
    return GradeCatalog.parse(name).gradeKey;
  }

  String get resolvedSection {
    if (gradeKey.isNotEmpty) return section.trim().toUpperCase();
    return GradeCatalog.parse(name).section;
  }

  String get gradeLabel => GradeCatalog.label(resolvedGradeKey);

  String get displayName {
    final sec = resolvedSection;
    if (sec.isEmpty) return gradeLabel;
    return '$gradeLabel $sec';
  }

  bool get hasSectionLabel => resolvedSection.isNotEmpty;

  Classroom copyWith({
    String? id,
    String? name,
    String? classTeacherId,
    double? baseFees,
    String? gradeKey,
    String? section,
  }) {
    return Classroom(
      id: id ?? this.id,
      name: name ?? this.name,
      classTeacherId: classTeacherId ?? this.classTeacherId,
      baseFees: baseFees ?? this.baseFees,
      gradeKey: gradeKey ?? this.gradeKey,
      section: section ?? this.section,
    );
  }

  factory Classroom.fromJson(Map<String, dynamic> json) {
    final generated = _$ClassroomFromJson(json);
    if (generated.gradeKey.isNotEmpty) return generated;
    final parsed = GradeCatalog.parse(generated.name);
    return generated.copyWith(
      gradeKey: parsed.gradeKey,
      section: generated.section.isNotEmpty ? generated.section : parsed.section,
    );
  }

  Map<String, dynamic> toJson() => _$ClassroomToJson(this);
}
