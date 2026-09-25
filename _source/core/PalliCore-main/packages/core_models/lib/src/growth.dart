import 'package:json_annotation/json_annotation.dart';

part 'growth.g.dart';

enum ObservationTone {
  @JsonValue('positive')
  positive,
  @JsonValue('neutral')
  neutral,
  @JsonValue('attention')
  attention,
}

@JsonSerializable(fieldRename: FieldRename.snake)
class GrowthObservation {
  final String id;
  final String studentId;
  final String? classroomId;
  @JsonKey(defaultValue: 'Note')
  final String title;
  final String body;
  @JsonKey(defaultValue: '')
  final String source; // teacher name — filled server-side when left blank
  final DateTime date;
  @JsonKey(defaultValue: '')
  final String createdBy;
  @JsonKey(defaultValue: ObservationTone.positive, unknownEnumValue: ObservationTone.neutral)
  final ObservationTone tone;
  @JsonKey(defaultValue: '')
  final String category;
  /// Shared by every row recorded in the same teacher action.
  final String? batchId;

  GrowthObservation({
    required this.id,
    required this.studentId,
    this.classroomId,
    this.title = 'Note',
    required this.body,
    this.source = '',
    required this.date,
    this.createdBy = '',
    this.tone = ObservationTone.positive,
    this.category = '',
    this.batchId,
  });

  factory GrowthObservation.fromJson(Map<String, dynamic> json) =>
      _$GrowthObservationFromJson(json);
  Map<String, dynamic> toJson() => _$GrowthObservationToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class GrowthSkill {
  final String id;
  final String studentId;
  final String? classroomId;
  final String name;
  @JsonKey(defaultValue: '')
  final String level; // one of SkillLevel.labels
  @JsonKey(defaultValue: '')
  final String framework;
  @JsonKey(defaultValue: '')
  final String category;
  final double? rating;
  @JsonKey(defaultValue: '')
  final String ratedBy;
  @JsonKey(includeToJson: false)
  final DateTime? updatedAt;

  GrowthSkill({
    required this.id,
    required this.studentId,
    this.classroomId,
    required this.name,
    this.level = '',
    this.framework = '',
    this.category = '',
    this.rating,
    this.ratedBy = '',
    this.updatedAt,
  });

  factory GrowthSkill.fromJson(Map<String, dynamic> json) =>
      _$GrowthSkillFromJson(json);
  Map<String, dynamic> toJson() => _$GrowthSkillToJson(this);
}

/// The four-step scale teachers rate skills on (stored as the label text).
class SkillLevel {
  static const labels = ['Emerging', 'Developing', 'Proficient', 'Advanced'];

  /// 1..4, or 0 when unrated / unknown.
  static int stepOf(String level) {
    final i = labels.indexWhere((l) => l.toLowerCase() == level.toLowerCase());
    return i < 0 ? 0 : i + 1;
  }
}
