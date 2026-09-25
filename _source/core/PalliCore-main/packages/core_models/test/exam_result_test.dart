import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

ExamPaper paper(String id, String subject, DateTime date, {String start = '10:00', String end = '12:00'}) => ExamPaper(
      id: id,
      examId: 'ex',
      gradeKey: '4',
      subject: subject,
      examDate: date,
      startTime: start,
      endTime: end,
      maxMarks: 100,
      passMarks: 35,
    );

Mark mark(String paperId, double score, {bool absent = false}) => Mark(
      id: 'm_$paperId',
      studentId: 's1',
      subject: 'x',
      score: score,
      totalMarks: 100,
      testType: 'Quarterly',
      date: DateTime(2026, 10, 1),
      updatedBy: 't',
      examId: 'ex',
      paperId: paperId,
      isAbsent: absent,
    );

void main() {
  final d = DateTime(2026, 10, 12);
  final papers = [
    paper('p1', 'Tamil', d),
    paper('p2', 'English', d.add(const Duration(days: 1))),
    paper('p3', 'Maths', d.add(const Duration(days: 2))),
    paper('p4', 'Science', d.add(const Duration(days: 3))),
    paper('p5', 'Social', d.add(const Duration(days: 4))),
  ];

  test('an unsubmitted subject stays in the table, blank', () {
    final r = StudentExamResult.build(
      studentId: 's1',
      papers: papers,
      marks: [mark('p1', 80), mark('p2', 70), mark('p3', 90), mark('p4', 60), mark('p5', 99)],
      isReleased: (p) => p.id != 'p5',
    );
    expect(r.subjects.length, 5);
    expect(r.subjects.last.outcome, PaperOutcome.pending);
    expect(r.subjects.last.score, isNull);
    expect(r.isComplete, isFalse);
    expect(r.percent, isNull);
    expect(r.overall, PaperOutcome.pending);
    expect(r.scored, 300);
    expect(r.releasedMax, 400);
  });

  test('absent and below-pass both fail the whole result; totals exclude AB', () {
    final r = StudentExamResult.build(
      studentId: 's1',
      papers: papers,
      marks: [mark('p1', 80), mark('p2', 0, absent: true), mark('p3', 34), mark('p4', 60), mark('p5', 35)],
      isReleased: (_) => true,
    );
    expect(r.subjects[1].outcome, PaperOutcome.absent);
    expect(r.subjects[2].outcome, PaperOutcome.fail);
    expect(r.subjects[4].outcome, PaperOutcome.pass, reason: 'exactly the pass mark passes');
    expect(r.scored, 209);
    expect(r.percent, closeTo(41.8, 0.001));
    expect(r.overall, PaperOutcome.fail);
  });

  test('grades-only: pass/fail follows the grade, no marks or percentage', () {
    final scale = GradeScale.presets.firstWhere((p) => p.id == 'ae').bands;
    Mark g(String paperId, String grade, {bool absent = false}) => Mark(
          id: 'g_$paperId',
          studentId: 's1',
          subject: 'x',
          score: 0,
          totalMarks: 0,
          testType: 'Q',
          date: d,
          updatedBy: 't',
          paperId: paperId,
          grade: absent ? null : grade,
          isAbsent: absent,
        );
    final r = StudentExamResult.build(
      studentId: 's1',
      papers: papers,
      marks: [g('p1', 'A'), g('p2', 'B'), g('p3', 'E'), g('p4', 'C'), g('p5', '', absent: true)],
      isReleased: (_) => true,
      mode: ExamResultMode.grades,
      scale: scale,
    );
    expect(r.subjects[0].grade, 'A');
    expect(r.subjects[0].score, isNull);
    expect(r.subjects[2].outcome, PaperOutcome.fail, reason: 'E is a failing grade');
    expect(r.subjects[4].outcome, PaperOutcome.absent);
    expect(r.percent, isNull);
    expect(r.overallGrade, isNull);
    expect(r.overall, PaperOutcome.fail);
  });

  test('marks & grades: marks decide, overall grade comes from the percentage', () {
    final scale = GradeScale.presets.firstWhere((p) => p.id == 'ae').bands;
    Mark mg(String paperId, double score, String grade) => Mark(
          id: 'mg_$paperId',
          studentId: 's1',
          subject: 'x',
          score: score,
          totalMarks: 100,
          testType: 'Q',
          date: d,
          updatedBy: 't',
          paperId: paperId,
          grade: grade,
        );
    final r = StudentExamResult.build(
      studentId: 's1',
      papers: papers,
      marks: [mg('p1', 90, 'A'), mg('p2', 80, 'A'), mg('p3', 70, 'B'), mg('p4', 60, 'B'), mg('p5', 50, 'C')],
      isReleased: (_) => true,
      mode: ExamResultMode.marksAndGrades,
      scale: scale,
    );
    expect(r.percent, 70);
    expect(r.overallGrade, 'B');
    expect(r.subjects.first.grade, 'A');
    expect(r.overall, PaperOutcome.pass);
    expect(GradeScale.gradeFor(scale, 34.9), 'E');
    expect(GradeScale.gradeFor(GradeScale.presets.last.bands, 90), isNull, reason: 'descriptive scales have no bands');
    expect(GradeScale.validate(const [GradeBand(label: 'A'), GradeBand(label: 'a')]), isNotNull);
  });

  test('papers of one standard clash only when their times overlap on the same day', () {
    final a = paper('a', 'Tamil', d);
    expect(a.overlaps(paper('b', 'Art', d, start: '11:00', end: '13:00')), isTrue);
    expect(a.overlaps(paper('c', 'Art', d, start: '12:00', end: '13:00')), isFalse, reason: 'back to back is fine');
    expect(a.overlaps(paper('e', 'Art', d.add(const Duration(days: 1)))), isFalse);
  });

  test('phase runs on calendar days', () {
    expect(ExamDates.phase(d, d.add(const Duration(days: 4)), now: d.subtract(const Duration(days: 1))), ExamPhase.upcoming);
    expect(ExamDates.phase(d, d.add(const Duration(days: 4)), now: d.add(const Duration(hours: 23))), ExamPhase.ongoing);
    expect(ExamDates.phase(d, d.add(const Duration(days: 4)), now: d.add(const Duration(days: 5))), ExamPhase.past);
    expect(ExamDates.display('13:05'), '1:05 PM');
    expect(ExamDates.range(d, d.add(const Duration(days: 6))), '12 – 18 Oct');
  });

  test('a standard is examined in what its sections are taught, breaks excluded', () {
    final a = Classroom(id: 'a', name: '4th Std A', classTeacherId: 't1', baseFees: 0, gradeKey: '4', section: 'A');
    final b = Classroom(id: 'b', name: '4th Std B', classTeacherId: 't2', baseFees: 0, gradeKey: '4', section: 'B');
    final other = Classroom(id: 'c', name: '5th Std', classTeacherId: 't3', baseFees: 0, gradeKey: '5');
    Period p(String name, String staff) =>
        Period(id: '$name$staff', name: name, staffId: staff, startTime: '09:00', durationMinutes: 45, dayOfWeek: 'Monday');
    final tts = [
      Timetable(id: '1', classroomId: 'a', name: 'w', isActive: true, startTime: '', endTime: '', intervalCount: 0,
          periods: [p('Tamil', 't1'), p('Break', 'N/A'), p('Maths', 't2')]),
      Timetable(id: '2', classroomId: 'b', name: 'w', isActive: true, startTime: '', endTime: '', intervalCount: 0,
          periods: [p('tamil', 't9'), p('Science', 't3')]),
      Timetable(id: '3', classroomId: 'c', name: 'w', isActive: true, startTime: '', endTime: '', intervalCount: 0,
          periods: [p('Hindi', 't4')]),
    ];
    final subjects = ExamPlanning.subjectsForGrade('4', classrooms: [a, b, other], timetables: tts);
    expect(subjects, ['Maths', 'Science', 'Tamil']);
    expect(ExamPlanning.teachersFor('b', 'Tamil', timetables: tts), {'t9'});
  });

  group('coverage', () {
    Period p(String name, String staff) =>
        Period(id: '$name$staff', name: name, staffId: staff, startTime: '09:00', durationMinutes: 45, dayOfWeek: 'Monday');
    final a = Classroom(id: 'a', name: 'LKG A', classTeacherId: 't1', baseFees: 0, gradeKey: 'LKG', section: 'A');
    final b = Classroom(id: 'b', name: 'LKG B', classTeacherId: 't2', baseFees: 0, gradeKey: 'LKG', section: 'B');
    final c = Classroom(id: 'c', name: 'LKG C', classTeacherId: 't3', baseFees: 0, gradeKey: 'LKG', section: 'C');

    test('names the sections that have no timetable at all', () {
      // The real shape of the bug: LKG A is timetabled, B and C are not, and
      // the exam is published for the whole standard. Marks are owned per
      // section, so B and C have no owner for any subject — and the Maths
      // teacher of LKG A is refused their sheets.
      final tts = [
        Timetable(id: '1', classroomId: 'a', name: 'w', isActive: true, startTime: '', endTime: '', intervalCount: 0,
            periods: [p('Tamil', 't1'), p('Maths', 't2')]),
      ];
      final cover = ExamPlanning.coverage('LKG',
          classrooms: [a, b, c], timetables: tts, subjects: ['Tamil', 'Maths']);

      expect(cover.isComplete, isFalse);
      expect(cover.untimetabled.map((s) => s.name), ['LKG B', 'LKG C']);
      // Not reported subject-by-subject — the whole section is the problem.
      expect(cover.unowned, isEmpty);
      expect(cover.adminWarning, contains('LKG B and LKG C'));
      expect(cover.adminWarning, contains('no class timetable'));
    });

    test('a timetabled section reports only the subject nobody takes', () {
      final tts = [
        Timetable(id: '1', classroomId: 'a', name: 'w', isActive: true, startTime: '', endTime: '', intervalCount: 0,
            periods: [p('Tamil', 't1')]),
      ];
      final cover = ExamPlanning.coverage('LKG',
          classrooms: [a], timetables: tts, subjects: ['Tamil', 'Maths']);

      expect(cover.untimetabled, isEmpty);
      expect(cover.unowned.single.subject, 'Maths');
      expect(cover.adminWarning, contains('Maths in LKG A'));
    });

    test('a fully timetabled standard is clean', () {
      final tts = [
        for (final room in ['a', 'b', 'c'])
          Timetable(id: room, classroomId: room, name: 'w', isActive: true, startTime: '', endTime: '', intervalCount: 0,
              periods: [p('Tamil', 't1'), p('Maths', 't2')]),
      ];
      final cover = ExamPlanning.coverage('LKG',
          classrooms: [a, b, c], timetables: tts, subjects: ['Tamil', 'Maths']);

      expect(cover.isComplete, isTrue);
      expect(cover.adminWarning, isNull);
    });
  });
}
