import 'package:json_annotation/json_annotation.dart';
import 'exit_record.dart';

part 'academic_year.g.dart';

enum StudentLifecycle {
  @JsonValue('enrolled')
  enrolled,
  @JsonValue('retained')
  retained,
  @JsonValue('graduated')
  graduated,
  @JsonValue('transferred')
  transferred,
  /// Withdrawn mid-year — left for a reason other than finishing or moving
  /// school. Kept distinct from [transferred] so the archive can say which.
  @JsonValue('discontinued')
  discontinued,
}

extension StudentLifecycleX on StudentLifecycle {
  /// The lifecycles that mean the child has left the school. Each one starts
  /// the archive's retention clock; [StudentLifecycle.retained] and
  /// [StudentLifecycle.enrolled] do not.
  bool get hasLeft =>
      this == StudentLifecycle.graduated ||
      this == StudentLifecycle.transferred ||
      this == StudentLifecycle.discontinued;

  ExitReason? get exitReason => switch (this) {
        StudentLifecycle.graduated => ExitReason.graduated,
        StudentLifecycle.transferred => ExitReason.transferred,
        StudentLifecycle.discontinued => ExitReason.discontinued,
        _ => null,
      };

  String get label => switch (this) {
        StudentLifecycle.enrolled => 'Enrolled',
        StudentLifecycle.retained => 'Retained',
        StudentLifecycle.graduated => 'Graduated',
        StudentLifecycle.transferred => 'Transferred out',
        StudentLifecycle.discontinued => 'Discontinued',
      };
}

@JsonSerializable(fieldRename: FieldRename.snake)
class AcademicYear {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;

  AcademicYear({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.isCurrent = false,
  });

  factory AcademicYear.fromJson(Map<String, dynamic> json) =>
      _$AcademicYearFromJson(json);
  Map<String, dynamic> toJson() => _$AcademicYearToJson(this);
}
