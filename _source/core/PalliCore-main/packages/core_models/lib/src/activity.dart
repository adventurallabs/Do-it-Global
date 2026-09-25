import 'package:json_annotation/json_annotation.dart';

part 'activity.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Activity {
  final String id;
  final String studentId;
  final String? classroomId;
  final String name;
  final DateTime date;
  @JsonKey(defaultValue: '')
  final String category;
  final String? achievement;
  final String? result;
  final String? teacherRemarks;
  final String? documentLabel;
  @JsonKey(defaultValue: '')
  final String createdBy;
  /// Shared by every row recorded in the same teacher action.
  final String? batchId;

  Activity({
    required this.id,
    required this.studentId,
    this.classroomId,
    required this.name,
    required this.date,
    this.category = '',
    this.achievement,
    this.result,
    this.teacherRemarks,
    this.documentLabel,
    this.createdBy = '',
    this.batchId,
  });

  factory Activity.fromJson(Map<String, dynamic> json) => _$ActivityFromJson(json);
  Map<String, dynamic> toJson() => _$ActivityToJson(this);
}
