import 'package:json_annotation/json_annotation.dart';

part 'homework_completion.g.dart';

enum HomeworkCompletionStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('under_review')
  underReview,
  @JsonValue('completed')
  completed,
}

@JsonSerializable(fieldRename: FieldRename.snake)
class HomeworkCompletion {
  final String homeworkId;
  final String studentId;
  @JsonKey(
      defaultValue: HomeworkCompletionStatus.pending,
      unknownEnumValue: HomeworkCompletionStatus.pending)
  final HomeworkCompletionStatus status;
  final DateTime? submittedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  HomeworkCompletion({
    required this.homeworkId,
    required this.studentId,
    this.status = HomeworkCompletionStatus.pending,
    this.submittedAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  /// [clearReview] drops the reviewer and review timestamp — needed when a
  /// teacher undoes an approval, where plain `reviewedAt: null` would fall
  /// through the `??` and keep the stale values.
  HomeworkCompletion copyWith({
    HomeworkCompletionStatus? status,
    DateTime? submittedAt,
    String? reviewedBy,
    DateTime? reviewedAt,
    bool clearReview = false,
  }) {
    return HomeworkCompletion(
      homeworkId: homeworkId,
      studentId: studentId,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedBy: clearReview ? null : (reviewedBy ?? this.reviewedBy),
      reviewedAt: clearReview ? null : (reviewedAt ?? this.reviewedAt),
    );
  }

  factory HomeworkCompletion.fromJson(Map<String, dynamic> json) =>
      _$HomeworkCompletionFromJson(json);
  Map<String, dynamic> toJson() => _$HomeworkCompletionToJson(this);
}
