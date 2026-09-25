import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import 'student_result_screen.dart';

/// One section's results for one exam: which subject teachers have
/// submitted, and every student with their running total.
class SectionResultsScreen extends StatefulWidget {
  final ExamOverview overview;
  final Classroom classroom;

  const SectionResultsScreen({super.key, required this.overview, required this.classroom});

  static Future<void> open(BuildContext context, {required ExamOverview overview, required Classroom classroom}) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SectionResultsScreen(overview: overview, classroom: classroom)),
    );
  }

  @override
  State<SectionResultsScreen> createState() => _SectionResultsScreenState();
}

class _SectionResultsScreenState extends State<SectionResultsScreen> {
  late List<ExamMarkSheet> _sheets = widget.overview.sheets.where((s) => s.classroomId == widget.classroom.id).toList();
  List<Student> _students = const [];
  List<Mark> _marks = const [];
  Map<String, String> _teacherNames = const {};
  Map<String, Set<String>> _subjectTeachers = const {};
  bool _loading = true;
  bool _error = false;
  String _query = '';
  StreamSubscription<List<ExamMarkSheet>>? _live;

  List<ExamPaper> get _papers => widget.overview.papersFor(widget.classroom.resolvedGradeKey);

  @override
  void initState() {
    super.initState();
    _load();
    _live = context.read<ExamRepository>().watchSheets(widget.overview.exam.id).listen((sheets) {
      if (!mounted) return;
      final mine = sheets.where((s) => s.classroomId == widget.classroom.id).toList();
      final changed = mine.any((s) => _sheetOf(s.paperId)?.status != s.status || _sheetOf(s.paperId)?.enteredCount != s.enteredCount);
      setState(() => _sheets = mine);
      if (changed) _loadMarks();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  ExamMarkSheet? _sheetOf(String paperId) {
    for (final s in _sheets) {
      if (s.paperId == paperId) return s;
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = _students.isEmpty;
      _error = false;
    });
    try {
      final (students, marks, teachers, timetables) = await (
        context.read<StudentRepository>().getByClassroom(widget.classroom.id, strict: true),
        context.read<ExamRepository>().examMarks(widget.overview.exam.id, classroomId: widget.classroom.id),
        context.read<TeacherRepository>().getAll(),
        context.read<TimetableRepository>().getForClass(widget.classroom.id),
      ).wait;
      if (!mounted) return;
      setState(() {
        _students = _sorted(students);
        _marks = marks;
        _teacherNames = {for (final t in teachers) t.id: t.name};
        _subjectTeachers = {
          for (final p in _papers)
            p.id: ExamPlanning.teachersFor(widget.classroom.id, p.subject, timetables: timetables),
        };
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _students.isEmpty;
        });
      }
    }
  }

  Future<void> _loadMarks() async {
    try {
      final marks =
          await context.read<ExamRepository>().examMarks(widget.overview.exam.id, classroomId: widget.classroom.id);
      if (mounted) setState(() => _marks = marks);
    } catch (_) {}
  }

  static List<Student> _sorted(List<Student> list) {
    int roll(Student s) => int.tryParse(s.rollNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1 << 30;
    return [...list]
      ..sort((a, b) {
        final r = roll(a).compareTo(roll(b));
        return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  StudentExamResult _resultOf(Student s) => StudentExamResult.build(
        studentId: s.id,
        papers: _papers,
        marks: _marks,
        // The admin reads what's been handed in; drafts are shown on the
        // student's own sheet, marked as drafts.
        isReleased: (p) => _sheetOf(p.id)?.isSubmitted == true,
        mode: widget.overview.exam.resultMode,
        scale: widget.overview.exam.gradeScale,
      );

  Future<void> _paperActions(ExamPaper paper) async {
    final sheet = _sheetOf(paper.id);
    if (sheet?.isSubmitted != true) return;
    final ok = await confirmExamAction(
      context,
      title: 'Reopen ${paper.subject}?',
      message: 'The teacher will be able to change these marks again and must submit them once more. '
          'Parents stop seeing ${paper.subject} until it is resubmitted.',
      confirmLabel: 'Reopen',
      icon: Icons.lock_open_rounded,
      color: AppColors.warning,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<ExamRepository>().reopenSheet(paper.id, widget.classroom.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ExamRepository.describeError(e))));
      }
    }
  }

  Future<void> _openStudent(Student s) async {
    final changed = await StudentResultScreen.open(
      context,
      exam: widget.overview.exam,
      classroom: widget.classroom,
      student: s,
      papers: _papers,
      sheets: _sheets,
      marks: _marks.where((m) => m.studentId == s.id).toList(),
    );
    if (changed == true) _loadMarks();
  }

  @override
  Widget build(BuildContext context) {
    final papers = _papers;
    final submitted = papers.where((p) => _sheetOf(p.id)?.isSubmitted == true).length;
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? _students
        : _students.where((s) => s.name.toLowerCase().contains(q) || s.rollNumber.toLowerCase().contains(q)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.classroom.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(widget.overview.exam.name,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.onSurfaceMuted(context))),
          ],
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error
                ? EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load this class",
                    subtitle: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: _load,
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SUBJECTS · $submitted OF ${papers.length} SUBMITTED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: AppColors.onSurfaceHint(context),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                for (final p in papers)
                                  _PaperStatusRow(
                                    paper: p,
                                    sheet: _sheetOf(p.id),
                                    roster: _students.length,
                                    teachers: (_subjectTeachers[p.id] ?? const <String>{})
                                        .map((id) => _teacherNames[id])
                                        .whereType<String>()
                                        .toList(),
                                    onReopen: () => _paperActions(p),
                                  ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'STUDENTS · ${_students.length}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: AppColors.onSurfaceHint(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_students.length > 12) ...[
                                  const SizedBox(height: 10),
                                  SoftField(
                                    child: TextField(
                                      onChanged: (v) => setState(() => _query = v),
                                      decoration: const InputDecoration(
                                        hintText: 'Search by name or roll no.',
                                        prefixIcon: Icon(Icons.search_rounded),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                        if (_students.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(icon: Icons.groups_outlined, title: 'No students in this class'),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            sliver: SliverList.separated(
                              itemCount: shown.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final s = shown[i];
                                return _StudentRow(student: s, result: _resultOf(s), onTap: () => _openStudent(s));
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _PaperStatusRow extends StatelessWidget {
  final ExamPaper paper;
  final ExamMarkSheet? sheet;
  final int roster;
  final List<String> teachers;
  final VoidCallback onReopen;

  const _PaperStatusRow({
    required this.paper,
    required this.sheet,
    required this.roster,
    required this.teachers,
    required this.onReopen,
  });

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    final submitted = sheet?.isSubmitted == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SoftSurface(
        depth: SoftDepth.none,
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        onTap: submitted ? onReopen : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(paper.subject, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    teachers.isEmpty ? 'No teacher on the timetable' : teachers.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: teachers.isEmpty ? AppColors.warning : mute),
                  ),
                ],
              ),
            ),
            SheetStatusBadge(sheet: sheet, rosterSize: roster),
            if (submitted)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(Icons.more_vert_rounded, size: 18, color: AppColors.onSurfaceHint(context)),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final Student student;
  final StudentExamResult result;
  final VoidCallback onTap;

  const _StudentRow({required this.student, required this.result, required this.onTap});

  static String _summary(StudentExamResult r) {
    if (r.releasedCount == 0) return 'No subjects submitted yet';
    if (!r.mode.usesMarks) {
      // Grades-only: there is no total to show, only the grades so far.
      final grades = r.subjects.map((s) => s.mark?.isAbsent == true && s.hasResult ? 'AB' : s.grade).whereType<String>();
      return r.isComplete
          ? grades.join(' · ')
          : '${r.releasedCount} of ${r.subjects.length} graded · ${grades.join(' · ')}';
    }
    final grade = r.overallGrade == null ? '' : ' · ${r.overallGrade}';
    return r.isComplete
        ? 'Total ${fmtMark(r.scored)} / ${fmtMark(r.maxTotal)} · ${r.percent!.toStringAsFixed(1)}%$grade'
        : '${fmtMark(r.scored)} / ${fmtMark(r.releasedMax)} so far · ${r.awaitedCount} awaited';
  }

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    final overall = result.overall;
    final color = outcomeColor(overall, context);
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              student.rollNumber.isEmpty ? '—' : student.rollNumber,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(
                  _summary(result),
                  style: TextStyle(fontSize: 12, color: mute),
                ),
              ],
            ),
          ),
          if (overall != PaperOutcome.pending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
              child: Text(overall.label.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.4)),
            ),
          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
        ],
      ),
    );
  }
}
