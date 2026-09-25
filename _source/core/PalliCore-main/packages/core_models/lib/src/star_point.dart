import 'package:json_annotation/json_annotation.dart';

part 'star_point.g.dart';

/// A teacher recognising a student for something good they did.
@JsonSerializable(fieldRename: FieldRename.snake)
class StarPoint {
  final String id;
  final String studentId;
  final String? classroomId;
  @JsonKey(defaultValue: 1)
  final int points;
  final String reason;
  final String? batchId;
  final String awardedBy;
  /// Filled server-side from `teachers.name` when left blank.
  @JsonKey(defaultValue: '')
  final String awardedByName;
  @JsonKey(includeToJson: false)
  final DateTime? createdAt;

  StarPoint({
    required this.id,
    required this.studentId,
    this.classroomId,
    this.points = 1,
    required this.reason,
    this.batchId,
    required this.awardedBy,
    this.awardedByName = '',
    this.createdAt,
  });

  factory StarPoint.fromJson(Map<String, dynamic> json) => _$StarPointFromJson(json);
  Map<String, dynamic> toJson() => _$StarPointToJson(this);
}
