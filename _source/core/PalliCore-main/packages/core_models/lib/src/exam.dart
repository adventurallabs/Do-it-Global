import 'package:json_annotation/json_annotation.dart';

import 'grade_scale.dart';

part 'exam.g.dart';

List<GradeBand> _bandsFromJson(Object? v) =>
    v is List ? v.map((e) => GradeBand.fromJson(Map<String, dynamic>.from(e as Map))).toList() : const [];

List<Map<String, dynamic>> _bandsToJson(List<GradeBand> bands) => bands.map((b) => b.toJson()).toList();

/// One exam event — "Quarterly", "Half-yearly" — sat by several standards.
///
/// The standards taking part are [gradeKeys]; each gets its own timetable
/// ([ExamSchedule] + [ExamPaper]s). Sections never appear here: every section
/// of 4th Std sits the same papers on the same days.
@JsonSerializable(fieldRename: FieldRename.snake)
class Exam {
  final String id;
  final String name;
  final String academicYearId;
  final String? examGroup;

  /// Kept in step with the papers by the database — the earliest and latest
  /// paper date across every standard.
  final DateTime startDate;
  final DateTime endDate;

  /// Standards sitting this exam ('LKG', '1', '10' …).
  @JsonKey(defaultValue: <String>[])
  final List<String> gradeKeys;

  /// Legacy: the classrooms picked before exams were planned per standard.
  /// Still written (every section of [gradeKeys]) for older readers.
  @JsonKey(defaultValue: <String>[])
  final List<String> classroomIds;
  @JsonKey(defaultValue: <String>[])
  final List<String> subjects;
  @JsonKey(defaultValue: 100)
  final double totalMarks;
  final String? createdBy;

  /// Marks, grades or both — what teachers enter and parents read.
  @JsonKey(defaultValue: ExamResultMode.marks, unknownEnumValue: ExamResultMode.marks)
  final ExamResultMode resultMode;

  /// Best → worst. Empty for a marks-only exam.
  @JsonKey(fromJson: _bandsFromJson, toJson: _bandsToJson)
  final List<GradeBand> gradeScale;

  Exam({
    required this.id,
    required this.name,
    required this.academicYearId,
    this.examGroup,
    required this.startDate,
    required this.endDate,
    this.gradeKeys = const [],
    required this.classroomIds,
    required this.subjects,
    this.totalMarks = 100,
    this.createdBy,
    this.resultMode = ExamResultMode.marks,
    this.gradeScale = const [],
  });

  Exam copyWith({
    String? name,
    List<String>? gradeKeys,
    List<String>? classroomIds,
    DateTime? startDate,
    DateTime? endDate,
    ExamResultMode? resultMode,
    List<GradeBand>? gradeScale,
  }) {
    return Exam(
      id: id,
      name: name ?? this.name,
      academicYearId: academicYearId,
      examGroup: examGroup,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      gradeKeys: gradeKeys ?? this.gradeKeys,
      classroomIds: classroomIds ?? this.classroomIds,
      subjects: subjects,
      totalMarks: totalMarks,
      createdBy: createdBy,
      resultMode: resultMode ?? this.resultMode,
      gradeScale: gradeScale ?? this.gradeScale,
    );
  }

  factory Exam.fromJson(Map<String, dynamic> json) => _$ExamFromJson(json);
  Map<String, dynamic> toJson() => _$ExamToJson(this);
}
