import 'package:json_annotation/json_annotation.dart';

import 'growth.dart';

part 'progress_template.g.dart';

/// The four things a teacher records about a student's progress.
enum ProgressKind {
  @JsonValue('star')
  star,
  @JsonValue('activity')
  activity,
  @JsonValue('observation')
  observation,
  @JsonValue('skill')
  skill,
}

/// A one-tap preset. Built-ins come from [ProgressCatalog]; the ones a teacher
/// creates are stored in `progress_templates` and reused across students.
@JsonSerializable(fieldRename: FieldRename.snake)
class ProgressTemplate {
  final String id;
  final ProgressKind kind;
  final String title;
  @JsonKey(defaultValue: '')
  final String category;
  /// Observation text / activity description. Empty for stars and skills.
  @JsonKey(defaultValue: '')
  final String body;
  @JsonKey(defaultValue: ObservationTone.positive, unknownEnumValue: ObservationTone.neutral)
  final ObservationTone tone;
  @JsonKey(defaultValue: '')
  final String createdBy;

  const ProgressTemplate({
    required this.id,
    required this.kind,
    required this.title,
    this.category = '',
    this.body = '',
    this.tone = ObservationTone.positive,
    this.createdBy = '',
  });

  /// Built-ins have no owner and are never written to the database.
  bool get isBuiltIn => createdBy.isEmpty;

  factory ProgressTemplate.fromJson(Map<String, dynamic> json) =>
      _$ProgressTemplateFromJson(json);
  Map<String, dynamic> toJson() => _$ProgressTemplateToJson(this);
}
