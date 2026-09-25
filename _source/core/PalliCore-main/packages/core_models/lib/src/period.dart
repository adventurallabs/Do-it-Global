import 'package:json_annotation/json_annotation.dart';

part 'period.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Period {
  final String id;
  final String name;
  final String staffId;
  final String startTime; // "HH:mm" format e.g. "09:00"
  final int durationMinutes;
  final String dayOfWeek; // Monday, Tuesday, etc.
  final bool isTemporary;
  final DateTime? date;

  Period({
    required this.id,
    required this.name,
    required this.staffId,
    required this.startTime,
    required this.durationMinutes,
    required this.dayOfWeek,
    this.isTemporary = false,
    this.date,
  });

  Period copyWith({
    String? id,
    String? name,
    String? staffId,
    String? startTime,
    int? durationMinutes,
    String? dayOfWeek,
    bool? isTemporary,
    DateTime? date,
  }) {
    return Period(
      id: id ?? this.id,
      name: name ?? this.name,
      staffId: staffId ?? this.staffId,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      isTemporary: isTemporary ?? this.isTemporary,
      date: date ?? this.date,
    );
  }

  factory Period.fromJson(Map<String, dynamic> json) => _$PeriodFromJson(json);
  Map<String, dynamic> toJson() => _$PeriodToJson(this);
}
