import 'package:flutter/material.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import 'exam_marks_entry_screen.dart';
import 'teacher_exam_data.dart';
import 'teacher_exams_screen.dart';

/// Exams this teacher has marks to enter for — pick one to see its classes.
class TeacherResultsScreen extends StatefulWidget {
  final String teacherId;
  const TeacherResultsScreen({super.key, required this.teacherId});

  static Future<void> open(BuildContext context, {required String teacherId}) {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherResultsScreen(teacherId: teacherId)));
  }

  @override
  State<TeacherResultsScreen> createState() => _TeacherResultsScreenState();
}

class _TeacherResultsScreenState extends State<TeacherResultsScreen> {
  TeacherExamData? _data;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _error = false);
    try {
      final data = await loadTeacherExamData(context, widget.teacherId, force: force);
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final exams = data?.examsToMark ?? const <ExamOverview>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: SafeArea(
        child: data == null
            ? (_error
                ? EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load exams",
                    subtitle: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: () => _load(force: true),
                  )
                : const Center(child: CircularProgressIndicator()))
            : RefreshIndicator(
                onRefresh: () => _load(force: true),
                child: exams.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(
                            height: 420,
                            child: EmptyState(
                              icon: Icons.grading_outlined,
                              title: 'Nothing to enter yet',
                              subtitle: 'When an exam timetable with your subjects is published, it shows up here.',
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        itemCount: exams.length,
                        itemBuilder: (context, i) {
                          final o = exams[i];
                          final mine = data.assignments(examId: o.exam.id);
                          return AnimatedListItem(
                            index: i,
                            child: _ExamCard(
                              overview: o,
                              assignments: mine,
                              onTap: () async {
                                await TeacherExamClassesScreen.open(context, teacherId: widget.teacherId, examId: o.exam.id);
                                if (mounted) _load();
                              },
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final ExamOverview overview;
  final List<ExamAssignment> assignments;
  final VoidCallback onTap;
  const _ExamCard({required this.overview, required this.assignments, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final submitted = assignments.where((a) => a.isSubmitted).length;
    final left = assignments.length - submitted;
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(20),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(overview.exam.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              if (left > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('$left to submit',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.warning)),
                )
              else
                const Icon(Icons.check_circle_rounded, color: AppColors.success),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ExamDates.range(overview.exam.startDate, overview.exam.endDate),
            style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted(context)),
          ),
          const SizedBox(height: 12),
          SubmissionBar(submitted: submitted, total: assignments.length, noun: 'of your sheets'),
        ],
      ),
    );
  }
}

/// The classes a teacher marks in one exam. A teacher of Tamil in 4th Std B
/// sees 4th Std B · Tamil — never 4th Std A, and never another subject.
class TeacherExamClassesScreen extends StatefulWidget {
  final String teacherId;
  final String examId;
  const TeacherExamClassesScreen({super.key, required this.teacherId, required this.examId});

  static Future<void> open(BuildContext context, {required String teacherId, required String examId}) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TeacherExamClassesScreen(teacherId: teacherId, examId: examId)),
    );
  }

  @override
  State<TeacherExamClassesScreen> createState() => _TeacherExamClassesScreenState();
}

class _TeacherExamClassesScreenState extends State<TeacherExamClassesScreen> {
  TeacherExamData? _data;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _error = false);
    try {
      final data = await loadTeacherExamData(context, widget.teacherId, force: force);
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _open(ExamAssignment a) async {
    final changed = await ExamMarksEntryScreen.open(
      context,
      teacherId: widget.teacherId,
      exam: a.overview.exam,
      paper: a.paper,
      classroom: a.classroom,
    );
    if (changed == true) {
      TeacherExamData.invalidate();
      _load(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final list = data?.assignments(examId: widget.examId) ?? const <ExamAssignment>[];
    final exam = list.isNotEmpty
        ? list.first.overview.exam
        : data?.exams.where((o) => o.exam.id == widget.examId).firstOrNull?.exam;
    final byClass = <String, List<ExamAssignment>>{};
    for (final a in list) {
      byClass.putIfAbsent(a.classroom.id, () => []).add(a);
    }
    return Scaffold(
      appBar: AppBar(title: Text(exam?.name ?? 'Exam')),
      body: SafeArea(
        child: data == null
            ? (_error
                ? EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load this exam",
                    subtitle: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: () => _load(force: true),
                  )
                : const Center(child: CircularProgressIndicator()))
            : RefreshIndicator(
                onRefresh: () => _load(force: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    if (list.isEmpty)
                      const SizedBox(
                        height: 400,
                        child: EmptyState(
                          icon: Icons.class_outlined,
                          title: 'Nothing for you here',
                          subtitle: 'None of your subjects are on this exam\'s timetable.',
                        ),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'Only the classes and subjects you teach are listed.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceMuted(context)),
                        ),
                      ),
                      for (final entry in byClass.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                          child: Row(
                            children: [
                              const Icon(Icons.class_outlined, size: 18, color: AppColors.classroomCard),
                              const SizedBox(width: 8),
                              Text(entry.value.first.classroom.displayName,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        for (final a in entry.value) _AssignmentTile(assignment: a, onTap: () => _open(a)),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  final ExamAssignment assignment;
  final VoidCallback onTap;
  const _AssignmentTile({required this.assignment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = assignment.paper;
    final sheet = assignment.sheet;
    final notYet = p.phase() == ExamPhase.upcoming;
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(16),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.subject, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${ExamDates.long(p.examDate)} · '
                  '${assignment.overview.exam.resultMode.usesMarks ? 'out of ${fmtMark(p.maxMarks)}' : assignment.overview.exam.resultMode.label.toLowerCase()}'
                  '${notYet ? ' · ${ExamDates.countdown(p.examDate).toLowerCase()}' : ''}',
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context)),
                ),
              ],
            ),
          ),
          SheetStatusBadge(sheet: sheet),
          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
        ],
      ),
    );
  }
}
