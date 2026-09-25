import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:go_router/go_router.dart';

import 'exams/exam_compose_screen.dart';
import 'exams/exam_detail_screen.dart';
import 'exams/exam_results_screen.dart';
import 'exams/exam_ui.dart';

/// What the admin came to do. The same list of exams serves both — building
/// timetables, and reading the results that come back.
enum ExamsMode { timetable, results }

class ExamsScreen extends StatefulWidget {
  final ExamsMode mode;
  const ExamsScreen({super.key, this.mode = ExamsMode.timetable});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  List<ExamOverview> _exams = const [];
  List<Classroom> _classrooms = const [];
  bool _loading = true;
  bool _hasError = false;
  int _filter = 0; // 0 all · 1 upcoming · 2 ongoing · 3 completed

  bool get _results => widget.mode == ExamsMode.results;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _exams.isEmpty;
      _hasError = false;
    });
    try {
      final (exams, classrooms) = await (
        context.read<ExamRepository>().overviews(),
        context.read<ClassroomRepository>().getAll(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _exams = exams;
        _classrooms = classrooms;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = _exams.isEmpty;
      });
    }
  }

  List<ExamOverview> get _visible {
    var list = _exams;
    if (_results) list = list.where((o) => o.papers.isNotEmpty).toList();
    if (_filter == 0) return list;
    final wanted = ExamPhase.values[_filter - 1];
    return list.where((o) => examPhaseOf(o) == wanted).toList();
  }

  Future<void> _compose() async {
    final created = await ExamComposeScreen.open(context, classrooms: _classrooms);
    if (created == null || !mounted) return;
    await _load();
    if (!mounted) return;
    await ExamDetailScreen.open(context, examId: created.id);
    if (mounted) _load();
  }

  Future<void> _open(ExamOverview o) async {
    if (_results) {
      await ExamResultsScreen.open(context, examId: o.exam.id);
    } else {
      await ExamDetailScreen.open(context, examId: o.exam.id);
    }
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(
        title: Text(_results ? 'Exam results' : 'Exams'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/admin'),
        ),
      ),
      floatingActionButton: _results
          ? null
          : FloatingActionButton.extended(
              onPressed: _compose,
              icon: const Icon(Icons.add),
              label: const Text('Create exam'),
              shape: const StadiumBorder(),
            ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _hasError
                ? EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load exams",
                    subtitle: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: _load,
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      children: [
                        if (_exams.isNotEmpty) ...[
                          SoftSegmentedControl(
                            labels: const ['All', 'Upcoming', 'Ongoing', 'Done'],
                            index: _filter,
                            onChanged: (i) => setState(() => _filter = i),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (visible.isEmpty)
                          SizedBox(
                            height: 360,
                            child: _exams.isEmpty || (_results && _filter == 0)
                                ? EmptyState(
                                    icon: _results ? Icons.fact_check_outlined : Icons.quiz_outlined,
                                    title: _results ? 'No results yet' : 'No exams yet',
                                    subtitle: _results
                                        ? 'Results appear here once an exam has a timetable and teachers start entering marks.'
                                        : 'Create an exam, pick the classes sitting it, then build each class\'s timetable.',
                                    actionLabel: _results ? null : 'Create exam',
                                    onAction: _results ? null : _compose,
                                  )
                                : const EmptyState(
                                    icon: Icons.filter_alt_off_outlined,
                                    title: 'Nothing here',
                                    subtitle: 'No exam falls under this filter.',
                                  ),
                          )
                        else
                          for (var i = 0; i < visible.length; i++)
                            AnimatedListItem(
                              index: i,
                              child: _results
                                  ? _ResultsCard(overview: visible[i], classrooms: _classrooms, onTap: () => _open(visible[i]))
                                  : _ExamCard(overview: visible[i], onTap: () => _open(visible[i])),
                            ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final ExamOverview overview;
  final VoidCallback onTap;
  const _ExamCard({required this.overview, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final exam = overview.exam;
    final grades = sortGrades(overview.schedules.map((s) => s.gradeKey));
    final withPapers = overview.papers.isNotEmpty;
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(20),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(exam.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              ),
              if (withPapers) ExamPhasePill(phase: examPhaseOf(overview)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            withPapers
                ? '${ExamDates.range(exam.startDate, exam.endDate)} · ${grades.length} class${grades.length == 1 ? '' : 'es'}'
                : '${grades.length} class${grades.length == 1 ? '' : 'es'} · timetable not started',
            style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in grades) GradeStatusChip(schedule: overview.scheduleFor(g)!),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  final ExamOverview overview;
  final List<Classroom> classrooms;
  final VoidCallback onTap;
  const _ResultsCard({required this.overview, required this.classrooms, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = ResultsProgress.of(overview, classrooms);
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
              Expanded(
                child: Text(overview.exam.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              ),
              ExamPhasePill(phase: examPhaseOf(overview)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ExamDates.range(overview.exam.startDate, overview.exam.endDate),
            style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
          ),
          const SizedBox(height: 14),
          SubmissionBar(submitted: progress.submitted, total: progress.expected),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final g in progress.byGrade.entries)
                Text(
                  '${GradeCatalog.label(g.key)} ${g.value.$1}/${g.value.$2}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: g.value.$2 > 0 && g.value.$1 >= g.value.$2
                        ? AppColors.success
                        : AppColors.onSurfaceMuted(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
