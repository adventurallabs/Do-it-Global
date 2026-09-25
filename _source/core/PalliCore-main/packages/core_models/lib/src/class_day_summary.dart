import 'package:json_annotation/json_annotation.dart';

part 'class_day_summary.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class LearningItem {
  final String subject;
  final String topic;

  LearningItem({required this.subject, required this.topic});

  factory LearningItem.fromJson(Map<String, dynamic> json) =>
      _$LearningItemFromJson(json);
  Map<String, dynamic> toJson() => _$LearningItemToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class GrowthSignal {
  final String name;
  final String indicator; // '↑', '👍', 'steady' ...

  GrowthSignal({required this.name, this.indicator = '↑'});

  factory GrowthSignal.fromJson(Map<String, dynamic> json) =>
      _$GrowthSignalFromJson(json);
  Map<String, dynamic> toJson() => _$GrowthSignalToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class ClassDaySummary {
  final String id;
  final String classroomId;
  final DateTime summaryDate;
  @JsonKey(defaultValue: '')
  final String teacherNote;
  @JsonKey(defaultValue: <LearningItem>[])
  final List<LearningItem> learning;
  @JsonKey(defaultValue: <GrowthSignal>[])
  final List<GrowthSignal> growthSignals;
  @JsonKey(defaultValue: '')
  final String createdBy;

  ClassDaySummary({
    required this.id,
    required this.classroomId,
    required this.summaryDate,
    this.teacherNote = '',
    this.learning = const [],
    this.growthSignals = const [],
    this.createdBy = '',
  });

  factory ClassDaySummary.fromJson(Map<String, dynamic> json) =>
      _$ClassDaySummaryFromJson(json);
  Map<String, dynamic> toJson() => _$ClassDaySummaryToJson(this);
}
