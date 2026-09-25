import 'package:json_annotation/json_annotation.dart';
import 'attendance.dart';

part 'staff_attendance.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class StaffAttendance {
  final String id;
  final String staffId;
  final DateTime date;
  @JsonKey(unknownEnumValue: AttendanceStatus.od)
  final AttendanceStatus status;

  StaffAttendance({
    required this.id,
    required this.staffId,
    required this.date,
    required this.status,
  });

  factory StaffAttendance.fromJson(Map<String, dynamic> json) =>
      _$StaffAttendanceFromJson(json);
  Map<String, dynamic> toJson() => _$StaffAttendanceToJson(this);
}
