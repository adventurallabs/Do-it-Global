import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';

/// One mark sheet a teacher owes: a paper, in one section they teach it in.
class ExamAssignment {
  final ExamOverview overview;
  final ExamPaper paper;
  final Classroom classroom;

  const ExamAssignment({required this.overview, required this.paper, required this.classroom});

  ExamMarkSheet? get sheet => overview.sheetFor(paper.id, classroom.id);
  bool get isSubmitted => sheet?.isSubmitted == true;
}

/// One published standard timetable a teacher should see.
class TeacherTimetableEntry {
  final ExamOverview overview;
  final ExamSchedule schedule;

  /// Sections of this standard the teacher has any standing in.
  final List<Classroom> myClassrooms;

  /// Subjects (lower-cased) the teacher marks in this standard.
  final Set<String> mySubjects;

  /// They are class teacher of one of these sections.
  final bool isHomeroom;

  const TeacherTimetableEntry({
    required this.overview,
    required this.schedule,
    required this.myClassrooms,
    required this.mySubjects,
    this.isHomeroom = false,
  });

  List<ExamPaper> get papers => overview.papersFor(schedule.gradeKey);
  ExamPhase get phase => schedule.phase();

  /// The next paper still to be sat, if any.
  ExamPaper? get nextPaper {
    for (final p in papers) {
      if (p.phase() != ExamPhase.past) return p;
    }
    return null;
  }
}

/// What a teacher sees of exams: published timetables for the standards they
/// teach or are class teacher of, and the mark sheets that are theirs.
///
/// "Theirs" is [TeachingScope] — the same rule the database checks on every
/// mark they save — so a sheet they can open is always a sheet they can save.
class TeacherExamData {
  final String teacherId;
  final List<ExamOverview> exams;
  final List<Classroom> classrooms;
  final Map<String, TeachingScope> scopes;

  const TeacherExamData({
    required this.teacherId,
    required this.exams,
    required this.classrooms,
    required this.scopes,
  });

  static TeacherExamData? _cache;
  static DateTime? _cachedAt;
  static const _ttl = Duration(seconds: 45);

  /// Drops the cache — call after a save or submit so every exam surface
  /// shows the new state.
  static void invalidate() => _cache = null;

  static Future<TeacherExamData> load({
    required String teacherId,
    required ExamRepository exams,
    required ClassroomRepository classrooms,
    required TimetableRepository timetables,
    bool force = false,
  }) async {
    final cached = _cache;
    if (!force &&
        cached != null &&
        cached.teacherId == teacherId &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _ttl) {
      return cached;
    }
    final results = await Future.wait<dynamic>([
      exams.overviews(publishedOnly: true),
      classrooms.getAll(),
      timetables.getAll(),
    ]);
    final overviews = results[0] as List<ExamOverview>;
    final rooms = results[1] as List<Classroom>;
    final tts = results[2] as List<Timetable>;
    final scopes = TeachingScope.asDatabaseSees(
      teacherId: teacherId,
      classrooms: rooms,
      timetables: tts,
    );
    final data = TeacherExamData(teacherId: teacherId, exams: overviews, classrooms: rooms, scopes: scopes);
    _cache = data;
    _cachedAt = DateTime.now();
    return data;
  }

  List<Classroom> get myClassrooms => classrooms.where((c) => scopes.containsKey(c.id)).toList()
    ..sort((a, b) => a.displayName.compareTo(b.displayName));

  Set<String> get myGrades => myClassrooms.map((c) => c.resolvedGradeKey).toSet();

  /// Published timetables for the teacher's standards, newest exam first.
  List<TeacherTimetableEntry> get timetables {
    final grades = myGrades;
    final out = <TeacherTimetableEntry>[];
    for (final o in exams) {
      for (final s in o.published) {
        if (!grades.contains(s.gradeKey)) continue;
        if (o.papersFor(s.gradeKey).isEmpty) continue;
        final rooms = myClassrooms.where((c) => c.resolvedGradeKey == s.gradeKey).toList();
        out.add(TeacherTimetableEntry(
          overview: o,
          schedule: s,
          myClassrooms: rooms,
          mySubjects: {
            for (final c in rooms)
              for (final sub in scopes[c.id]?.subjects ?? const <String>[]) sub.trim().toLowerCase(),
          },
          isHomeroom: rooms.any((c) => scopes[c.id]?.isClassTeacher == true),
        ));
      }
    }
    out.sort((a, b) {
      final ad = a.schedule.firstDate ?? DateTime(2100);
      final bd = b.schedule.firstDate ?? DateTime(2100);
      return bd.compareTo(ad);
    });
    return out;
  }

  /// Every sheet this teacher owes, optionally for one exam.
  List<ExamAssignment> assignments({String? examId}) {
    final out = <ExamAssignment>[];
    for (final o in exams) {
      if (examId != null && o.exam.id != examId) continue;
      final published = {for (final s in o.published) s.gradeKey};
      for (final c in myClassrooms) {
        final grade = c.resolvedGradeKey;
        if (!published.contains(grade)) continue;
        final scope = scopes[c.id];
        if (scope == null) continue;
        for (final p in o.papersFor(grade)) {
          if (scope.canEnterMarksFor(p.subject)) {
            out.add(ExamAssignment(overview: o, paper: p, classroom: c));
          }
        }
      }
    }
    return out;
  }

  /// Exams with at least one sheet for this teacher, newest first.
  List<ExamOverview> get examsToMark {
    final ids = {for (final a in assignments()) a.overview.exam.id};
    return exams.where((o) => ids.contains(o.exam.id)).toList();
  }

  int get pendingSheets => assignments().where((a) => !a.isSubmitted).length;
}
