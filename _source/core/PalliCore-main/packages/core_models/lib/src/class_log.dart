import 'package:json_annotation/json_annotation.dart';

part 'class_log.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class ClassLog {
  final String id;
  final String periodId;
  final String staffId;
  final DateTime startTime;
  final String status; // 'started', 'missed', 'ended'

  ClassLog({
    required this.id,
    required this.periodId,
    required this.staffId,
    required this.startTime,
    required this.status,
  });

  factory ClassLog.fromJson(Map<String, dynamic> json) => _$ClassLogFromJson(json);
  Map<String, dynamic> toJson() => _$ClassLogToJson(this);
}
