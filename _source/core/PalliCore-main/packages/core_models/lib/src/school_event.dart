import 'package:json_annotation/json_annotation.dart';

part 'school_event.g.dart';

enum EventAudience {
  @JsonValue('school')
  school,
  @JsonValue('classrooms')
  classrooms,
}

@JsonSerializable(fieldRename: FieldRename.snake)
class SchoolEvent {
  final String id;
  final String name;
  final String description;
  final DateTime eventDate;
  final DateTime? lastPayDate;
  final double feeAmount;
  final EventAudience audience;
  final List<String> classroomIds;
  final DateTime createdAt;

  SchoolEvent({
    required this.id,
    required this.name,
    required this.description,
    required this.eventDate,
    this.lastPayDate,
    this.feeAmount = 0,
    required this.audience,
    this.classroomIds = const [],
    required this.createdAt,
  });

  bool get requiresFee => feeAmount > 0;

  bool get isSchoolWide => audience == EventAudience.school;

  factory SchoolEvent.fromJson(Map<String, dynamic> json) =>
      _$SchoolEventFromJson(json);
  Map<String, dynamic> toJson() => _$SchoolEventToJson(this);
}
