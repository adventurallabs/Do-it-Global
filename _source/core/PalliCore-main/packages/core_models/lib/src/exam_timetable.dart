import 'package:json_annotation/json_annotation.dart';

import 'classroom.dart';
import 'period.dart';
import 'schedule.dart';
import 'timetable.dart';

part 'exam_timetable.g.dart';

DateTime _dateFromJson(Object? v) {
  final d = DateTime.parse(v as String);
  return DateTime(d.year, d.month, d.day);
}

DateTime? _dateFromJsonOrNull(Object? v) => v == null ? null : _dateFromJson(v);

String _dateToJson(DateTime d) => ExamDates.key(d);

String? _dateToJsonOrNull(DateTime? d) => d == null ? null : ExamDates.key(d);

/// Where an exam — or one standard's timetable of it — sits relative to today.
enum ExamPhase { upcoming, ongoing, past }

extension ExamPhaseX on ExamPhase {
  String get label => switch (this) {
        ExamPhase.upcoming => 'Upcoming',
        ExamPhase.ongoing => 'Ongoing',
        ExamPhase.past => 'Completed',
      };
}

/// Date arithmetic for exams, done on calendar days so a paper at 10:00 today
/// is "today" all day, not "past" from 10:01.
class ExamDates {
  ExamDates._();

  static DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  static String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static ExamPhase phase(DateTime? first, DateTime? last, {DateTime? now}) {
    final today = day(now ?? DateTime.now());
    if (first == null || last == null) return ExamPhase.upcoming;
    if (today.isBefore(day(first))) return ExamPhase.upcoming;
    if (today.isAfter(day(last))) return ExamPhase.past;
    return ExamPhase.ongoing;
  }

  /// "In 3 days", "Tomorrow", "Today" — only meaningful for future dates.
  static String countdown(DateTime date, {DateTime? now}) {
    final diff = day(date).difference(day(now ?? DateTime.now())).inDays;
    if (diff < 0) return 'Done';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return 'In $diff days';
  }

  static int minutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  static String hhmm(int minutes) {
    final m = minutes.clamp(0, 23 * 60 + 59);
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// "12 Oct"
  static String short(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  /// "Mon"
  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  static String month(DateTime d) => _months[d.month - 1];

  /// "Mon, 12 Oct 2026"
  static String long(DateTime d) => '${weekday(d)}, ${short(d)} ${d.year}';

  /// "12 – 18 Oct", "28 Sep – 3 Oct", or a single day.
  static String range(DateTime? first, DateTime? last) {
    if (first == null || last == null) return 'Dates not set';
    if (key(first) == key(last)) return short(first);
    if (first.month == last.month && first.year == last.year) {
      return '${first.day} – ${short(last)}';
    }
    return '${short(first)} – ${short(last)}';
  }

  /// "10:00" → "10:00 AM" — how a timetable is read aloud.
  static String display(String hhmm) {
    final total = minutes(hhmm);
    final h = total ~/ 60;
    final m = total % 60;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $suffix';
  }
}

enum ExamScheduleStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('published')
  published,
}

/// One standard's timetable for one exam. Draft until the admin publishes it;
/// only then do teachers and parents see it.
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ExamSchedule {
  final String examId;
  final String gradeKey;
  @JsonKey(defaultValue: ExamScheduleStatus.draft, unknownEnumValue: ExamScheduleStatus.draft)
  final ExamScheduleStatus status;
  final DateTime? publishedAt;
  @JsonKey(fromJson: _dateFromJsonOrNull, toJson: _dateToJsonOrNull)
  final DateTime? firstDate;
  @JsonKey(fromJson: _dateFromJsonOrNull, toJson: _dateToJsonOrNull)
  final DateTime? lastDate;
  @JsonKey(defaultValue: 0)
  final int paperCount;

  /// Published, then edited — the people who received it haven't seen the
  /// change yet.
  @JsonKey(defaultValue: false)
  final bool hasChanges;

  const ExamSchedule({
    required this.examId,
    required this.gradeKey,
    this.status = ExamScheduleStatus.draft,
    this.publishedAt,
    this.firstDate,
    this.lastDate,
    this.paperCount = 0,
    this.hasChanges = false,
  });

  bool get isPublished => status == ExamScheduleStatus.published;

  ExamPhase phase({DateTime? now}) => ExamDates.phase(firstDate, lastDate, now: now);

  String get key => '$examId|$gradeKey';

  factory ExamSchedule.fromJson(Map<String, dynamic> json) => _$ExamScheduleFromJson(json);

  /// Only the columns a client may write — the counts and dates belong to the
  /// database trigger.
  Map<String, dynamic> toInsertJson() => {'exam_id': examId, 'grade_key': gradeKey};
}

/// One subject's slot in a standard's exam timetable.
@JsonSerializable(fieldRename: FieldRename.snake)
class ExamPaper {
  final String id;
  final String examId;
  final String gradeKey;
  final String subject;
  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime examDate;

  /// 'HH:mm', 24-hour.
  final String startTime;
  final String endTime;
  @JsonKey(defaultValue: '')
  final String syllabus;
  final double maxMarks;
  final double passMarks;

  const ExamPaper({
    required this.id,
    required this.examId,
    required this.gradeKey,
    required this.subject,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    this.syllabus = '',
    this.maxMarks = 100,
    this.passMarks = 35,
  });

  int get startMinutes => ExamDates.minutes(startTime);
  int get endMinutes => ExamDates.minutes(endTime);
  int get durationMinutes => endMinutes - startMinutes;

  String get timeLabel => '${ExamDates.display(startTime)} – ${ExamDates.display(endTime)}';

  bool isOn(DateTime day) => ExamDates.key(day) == ExamDates.key(examDate);

  /// Two papers of one standard can't be sat at the same time.
  bool overlaps(ExamPaper other) =>
      ExamDates.key(examDate) == ExamDates.key(other.examDate) &&
      startMinutes < other.endMinutes &&
      other.startMinutes < endMinutes;

  ExamPhase phase({DateTime? now}) {
    final n = now ?? DateTime.now();
    final p = ExamDates.phase(examDate, examDate, now: n);
    if (p != ExamPhase.ongoing) return p;
    final m = n.hour * 60 + n.minute;
    if (m < startMinutes) return ExamPhase.upcoming;
    if (m >= endMinutes) return ExamPhase.past;
    return ExamPhase.ongoing;
  }

  bool sameSubject(String other) => subject.trim().toLowerCase() == other.trim().toLowerCase();

  ExamPaper copyWith({
    String? subject,
    DateTime? examDate,
    String? startTime,
    String? endTime,
    String? syllabus,
    double? maxMarks,
    double? passMarks,
  }) {
    return ExamPaper(
      id: id,
      examId: examId,
      gradeKey: gradeKey,
      subject: subject ?? this.subject,
      examDate: examDate ?? this.examDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      syllabus: syllabus ?? this.syllabus,
      maxMarks: maxMarks ?? this.maxMarks,
      passMarks: passMarks ?? this.passMarks,
    );
  }

  /// Date, then start time, then subject — the order a timetable is read in.
  static int compare(ExamPaper a, ExamPaper b) {
    final byDate = a.examDate.compareTo(b.examDate);
    if (byDate != 0) return byDate;
    final byTime = a.startMinutes.compareTo(b.startMinutes);
    if (byTime != 0) return byTime;
    return a.subject.toLowerCase().compareTo(b.subject.toLowerCase());
  }

  factory ExamPaper.fromJson(Map<String, dynamic> json) => _$ExamPaperFromJson(json);
  Map<String, dynamic> toJson() => _$ExamPaperToJson(this);
}

enum ExamSheetStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('submitted')
  submitted,
}

/// One section's marks for one paper. A teacher saves it as a draft as often
/// as they like; submitting locks it and releases it to parents.
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ExamMarkSheet {
  final String paperId;
  final String classroomId;
  final String examId;
  final String subject;
  @JsonKey(defaultValue: ExamSheetStatus.draft, unknownEnumValue: ExamSheetStatus.draft)
  final ExamSheetStatus status;
  @JsonKey(defaultValue: 0)
  final int enteredCount;
  @JsonKey(defaultValue: '')
  final String teacherId;
  final DateTime? submittedAt;
  final String? submittedBy;
  final DateTime? updatedAt;

  const ExamMarkSheet({
    required this.paperId,
    required this.classroomId,
    required this.examId,
    required this.subject,
    this.status = ExamSheetStatus.draft,
    this.enteredCount = 0,
    this.teacherId = '',
    this.submittedAt,
    this.submittedBy,
    this.updatedAt,
  });

  bool get isSubmitted => status == ExamSheetStatus.submitted;

  String get key => keyOf(paperId, classroomId);

  static String keyOf(String paperId, String classroomId) => '$paperId|$classroomId';

  factory ExamMarkSheet.fromJson(Map<String, dynamic> json) => _$ExamMarkSheetFromJson(json);

  /// A draft save. Submitting goes through the `submit_exam_marks` RPC, which
  /// checks the roster is complete — a client can't mark a sheet submitted.
  Map<String, dynamic> toDraftJson() => {
        'paper_id': paperId,
        'classroom_id': classroomId,
        'exam_id': examId,
        'subject': subject,
        'entered_count': enteredCount,
        'teacher_id': teacherId,
      };
}

/// Which subjects a standard can be examined in, and who marks each one.
///
/// Both answers come from the timetable, the same way [TeachingScope] does —
/// so the subject list the admin picks from and the subjects a teacher is
/// allowed to mark can never disagree.
class ExamPlanning {
  ExamPlanning._();

  /// Every section of [gradeKey], in section order.
  static List<Classroom> sectionsOf(String gradeKey, Iterable<Classroom> classrooms) {
    return classrooms.where((c) => c.resolvedGradeKey == gradeKey).toList()
      ..sort((a, b) => a.resolvedSection.compareTo(b.resolvedSection));
  }

  /// The subjects taught in any section of [gradeKey]: the classroom's
  /// active timetable, or any timetable when none has been activated. Sorted.
  static List<String> subjectsForGrade(
    String gradeKey, {
    required Iterable<Classroom> classrooms,
    required Iterable<Timetable> timetables,
  }) {
    final ids = sectionsOf(gradeKey, classrooms).map((c) => c.id).toSet();
    final seen = <String, String>{};
    for (final id in ids) {
      for (final period in _periodsOf(id, timetables)) {
        final name = period.name.trim();
        if (name.isEmpty) continue;
        seen.putIfAbsent(name.toLowerCase(), () => name);
      }
    }
    final list = seen.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// The staff who teach [subject] in [classroomId] — the people whose marks
  /// sheet it is.
  static Set<String> teachersFor(
    String classroomId,
    String subject, {
    required Iterable<Timetable> timetables,
  }) {
    final wanted = subject.trim().toLowerCase();
    return {
      for (final p in _periodsOf(classroomId, timetables))
        if (p.name.trim().toLowerCase() == wanted) p.staffId,
    };
  }

  /// Everyone who teaches anything in [classroomId] — the staff a published
  /// timetable is sent to (with the class teacher). Same rule as the
  /// database's `_classroom_staff()`.
  static Set<String> staffOf(String classroomId, {required Iterable<Timetable> timetables}) =>
      {for (final p in _periodsOf(classroomId, timetables)) p.staffId};

  /// True when [classroomId] has no timetable at all — not an empty one, but
  /// none ever built. Nobody teaches a subject there, so nobody owns its
  /// marks, and every teacher who opens it is turned away.
  static bool hasNoTimetable(String classroomId, {required Iterable<Timetable> timetables}) =>
      !timetables.any((t) => t.classroomId == classroomId);

  /// Which sections of [gradeKey] nobody can enter marks for, and why.
  ///
  /// Marks follow the timetable, per section — so a section with no timetable
  /// of its own strands every teacher in it, however plainly they take the
  /// subject in the section next door. The admin needs to see that before the
  /// exam, not when a teacher is turned away from the mark sheet.
  static ExamCoverage coverage(
    String gradeKey, {
    required Iterable<Classroom> classrooms,
    required Iterable<Timetable> timetables,
    required Iterable<String> subjects,
  }) {
    final untimetabled = <Classroom>[];
    final unowned = <ExamCoverageGap>[];
    for (final section in sectionsOf(gradeKey, classrooms)) {
      if (hasNoTimetable(section.id, timetables: timetables)) {
        untimetabled.add(section);
        continue;
      }
      for (final subject in subjects) {
        if (teachersFor(section.id, subject, timetables: timetables).isEmpty) {
          unowned.add(ExamCoverageGap(section: section, subject: subject));
        }
      }
    }
    return ExamCoverage(untimetabled: untimetabled, unowned: unowned);
  }

  static Iterable<Period> _periodsOf(String classroomId, Iterable<Timetable> timetables) sync* {
    final mine = timetables.where((t) => t.classroomId == classroomId).toList();
    final active = mine.where((t) => t.isActive).toList();
    for (final t in active.isNotEmpty ? active : mine) {
      for (final p in t.periods) {
        if (p.isTemporary || Schedule.isBreak(p)) continue;
        yield p;
      }
    }
  }
}

/// One subject, in one section, that no teacher on the timetable takes.
class ExamCoverageGap {
  final Classroom section;
  final String subject;

  const ExamCoverageGap({required this.section, required this.subject});
}

/// Where a standard's marks have no owner. [untimetabled] is the serious
/// one — a whole section nobody can mark; [unowned] is a single subject the
/// section's timetable never names.
class ExamCoverage {
  final List<Classroom> untimetabled;
  final List<ExamCoverageGap> unowned;

  const ExamCoverage({this.untimetabled = const [], this.unowned = const []});

  bool get isComplete => untimetabled.isEmpty && unowned.isEmpty;

  /// Sections named in reading order, e.g. "LKG B and LKG C".
  static String listSections(Iterable<Classroom> sections) =>
      _join([for (final c in sections) c.displayName]);

  /// A sentence for the admin, or null when nothing is missing.
  String? get adminWarning {
    if (untimetabled.isNotEmpty) {
      final names = listSections(untimetabled);
      final plural = untimetabled.length > 1;
      return '$names ${plural ? 'have' : 'has'} no class timetable, so no teacher '
          "can enter ${plural ? 'their' : 'its'} marks. Build ${plural ? 'those timetables' : 'that timetable'} "
          'first, or you will have to enter every subject yourself.';
    }
    if (unowned.isNotEmpty) {
      final shown = unowned.take(3).map((g) => '${g.subject} in ${g.section.displayName}');
      final rest = unowned.length - 3;
      return 'Nobody on the timetable takes ${_join(shown.toList())}'
          '${rest > 0 ? ' and $rest more' : ''} — you will enter those marks yourself.';
    }
    return null;
  }

  static String _join(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.single;
    return '${items.take(items.length - 1).join(', ')} and ${items.last}';
  }
}
