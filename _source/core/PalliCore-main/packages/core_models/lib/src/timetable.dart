import 'package:json_annotation/json_annotation.dart';
import 'period.dart';

part 'timetable.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Timetable {
  final String id;
  final String classroomId;
  final String name;
  final bool isActive;
  final List<Period> periods;
  final String startTime; // e.g., "08:30"
  final String endTime;   // e.g., "15:30"
  final int intervalCount;

  Timetable({
    required this.id,
    required this.classroomId,
    required this.name,
    required this.isActive,
    required this.periods,
    this.startTime = "08:30",
    this.endTime = "15:30",
    this.intervalCount = 11,
  });

  factory Timetable.fromJson(Map<String, dynamic> json) => _$TimetableFromJson(json);
  Map<String, dynamic> toJson() => _$TimetableToJson(this);
}
