import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import 'exam_compose_screen.dart';
import 'exam_results_screen.dart';
import 'exam_ui.dart';
import 'grade_timetable_screen.dart';

/// One exam: every class taking it, and how far each timetable has got.
class ExamDetailScreen extends StatefulWidget {
  final String examId;
  const ExamDetailScreen({super.key, required this.examId});

  static Future<void> open(BuildContext context, {required String examId}) {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => ExamDetailScreen(examId: examId)));
  }

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  ExamOverview? _overview;
  List<Classroom> _classrooms = const [];
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final (overview, classrooms) = await (
        context.read<ExamRepository>().overview(widget.examId),
        context.read<ClassroomRepository>().getAll(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _classrooms = classrooms;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _edit() async {
    final o = _overview;
    if (o == null) return;
    final saved = await ExamComposeScreen.open(context, classrooms: _classrooms, editing: o);
    if (saved != null) _load();
  }

  Future<void> _delete() async {
    final o = _overview;
    if (o == null) return;
    final marked = o.sheets.where((s) => s.enteredCount > 0).length;
    final ok = await confirmExamAction(
      context,
      title: 'Delete ${o.exam.name}?',
      message: 'This removes the exam for every class — its timetables, and every mark entered for it. '
          'Parents and teachers will no longer see it.',
      confirmLabel: 'Delete exam',
      icon: Icons.delete_forever_rounded,
      color: AppColors.error,
      bullets: [
        '${o.schedules.length} class${o.schedules.length == 1 ? '' : 'es'}, ${o.papers.length} subject papers',
        if (marked > 0) '$marked mark sheet${marked == 1 ? '' : 's'} already started',
      ],
    );
    if (!ok || !mounted) return;
    try {
      await context.read<ExamRepository>().delete(o.exam.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ExamRepository.describeError(e))));
      }
    }
  }

  Future<void> _openGrade(String gradeKey) async {
    final o = _overview!;
    await GradeTimetableScreen.open(
      context,
      exam: o.exam,
      gradeKey: gradeKey,
      classrooms: _classrooms,
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final o = _overview;
    return Scaffold(
      appBar: AppBar(
        title: Text(o?.exam.name ?? 'Exam'),
        actions: [
          if (o != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _edit();
                if (v == 'results') ExamResultsScreen.open(context, examId: o.exam.id);
                if (v == 'delete') _delete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit name & classes'))),
                PopupMenuItem(value: 'results', child: ListTile(leading: Icon(Icons.fact_check_outlined), title: Text('View results'))),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    title: Text('Delete exam', style: TextStyle(color: AppColors.error)),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: o == null
            ? (_error
                ? EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load this exam",
                    subtitle: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: _load,
                  )
                : const Center(child: CircularProgressIndicator()))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    _Header(overview: o),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        'Tap a class to build its timetable',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurfaceMuted(context)),
                      ),
                    ),
                    for (final g in sortGrades(o.schedules.map((s) => s.gradeKey)))
                      _GradeCard(
                        schedule: o.scheduleFor(g)!,
                        sections: ExamPlanning.sectionsOf(g, _classrooms),
                        papers: o.papersFor(g),
                        onTap: () => _openGrade(g),
                      ),
                    if (o.schedules.isEmpty)
                      EmptyState(
                        icon: Icons.class_outlined,
                        title: 'No classes picked',
                        subtitle: 'Add the classes taking this exam.',
                        actionLabel: 'Pick classes',
                        onAction: _edit,
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ExamOverview overview;
  const _Header({required this.overview});

  @override
  Widget build(BuildContext context) {
    final published = overview.schedules.where((s) => s.isPublished).length;
    final total = overview.schedules.length;
    final mute = AppColors.onSurfaceMuted(context);
    return SoftSurface(
      depth: SoftDepth.two,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          AdminIconWell(icon: Icons.quiz_outlined, color: AppColors.examCard, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overview.papers.isEmpty
                      ? 'No papers scheduled yet'
                      : ExamDates.range(overview.papers.first.examDate, overview.papers.last.examDate),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '$published of $total class timetable${total == 1 ? '' : 's'} published',
                  style: TextStyle(fontSize: 13, color: mute),
                ),
                const SizedBox(height: 2),
                Text(
                  overview.exam.resultMode.usesGrades
                      ? 'Results: ${overview.exam.resultMode.label} · ${overview.exam.gradeScale.map((b) => b.label).join(' ')}'
                      : 'Results: ${overview.exam.resultMode.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent),
                ),
              ],
            ),
          ),
          if (overview.papers.isNotEmpty) ExamPhasePill(phase: overview.phase),
        ],
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  final ExamSchedule schedule;
  final List<Classroom> sections;
  final List<ExamPaper> papers;
  final VoidCallback onTap;

  const _GradeCard({required this.schedule, required this.sections, required this.papers, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final names = sections.map((c) => c.resolvedSection).where((s) => s.isNotEmpty).toList();
    final mute = AppColors.onSurfaceMuted(context);
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(GradeCatalog.label(schedule.gradeKey),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    if (names.isNotEmpty)
                      Text('Sections ${names.join(' · ')}', style: TextStyle(fontSize: 12, color: mute)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  papers.isEmpty
                      ? 'No subjects added yet'
                      : '${papers.length} subject${papers.length == 1 ? '' : 's'} · ${ExamDates.range(papers.first.examDate, papers.last.examDate)}',
                  style: TextStyle(fontSize: 13, color: mute),
                ),
                const SizedBox(height: 10),
                GradeStatusChip(schedule: schedule),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
        ],
      ),
    );
  }
}
