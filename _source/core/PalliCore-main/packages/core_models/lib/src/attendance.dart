import 'package:json_annotation/json_annotation.dart';

part 'attendance.g.dart';

enum AttendanceStatus {
  @JsonValue('present')
  present,
  @JsonValue('absent')
  absent,
  @JsonValue('od')
  od,
  @JsonValue('delayed')
  delayed
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Attendance {
  final String id;
  final String studentId;
  @JsonKey(defaultValue: '')
  final String classroomId;
  final String periodId;
  final DateTime date;
  // DB also stores 'late'/'excused'/'half_day' (e.g. from approved leave) —
  // decode those as `od` so the school app treats them as present-but-noted.
  @JsonKey(unknownEnumValue: AttendanceStatus.od)
  final AttendanceStatus status;
  final String markedBy;

  Attendance({
    required this.id,
    required this.studentId,
    this.classroomId = '',
    required this.periodId,
    required this.date,
    required this.status,
    required this.markedBy,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) => _$AttendanceFromJson(json);
  Map<String, dynamic> toJson() => _$AttendanceToJson(this);
}
