import 'package:json_annotation/json_annotation.dart';

part 'mark.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Mark {
  final String id;
  final String studentId;
  final String subject;
  final double score;
  final double totalMarks;
  final String testType;
  final DateTime date;
  final String updatedBy;
  @JsonKey(defaultValue: '')
  final String examId;

  /// Set for a formal exam mark — the [ExamPaper] it answers. Null for a
  /// class test recorded from the marks board.
  final String? paperId;

  /// The section the child sat the paper in. The submit lock and the
  /// parent's visibility are both per section, so this is stamped at entry.
  @JsonKey(defaultValue: '')
  final String classroomId;

  /// "AB" on the sheet. The score is 0 and does not count as a fail.
  @JsonKey(defaultValue: false)
  final bool isAbsent;

  /// The grade given, when the exam records grades. For a grades-only exam
  /// [score] and [totalMarks] are 0 and mean nothing.
  final String? grade;

  Mark({
    required this.id,
    required this.studentId,
    required this.subject,
    required this.score,
    required this.totalMarks,
    required this.testType,
    required this.date,
    required this.updatedBy,
    this.examId = '',
    this.paperId,
    this.classroomId = '',
    this.isAbsent = false,
    this.grade,
  });

  bool get isExamPaper => paperId != null && paperId!.isNotEmpty;

  factory Mark.fromJson(Map<String, dynamic> json) => _$MarkFromJson(json);
  Map<String, dynamic> toJson() => _$MarkToJson(this);
}
