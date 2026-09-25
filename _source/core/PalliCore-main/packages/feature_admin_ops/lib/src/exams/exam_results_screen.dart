import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import 'exam_ui.dart';
import 'section_results_screen.dart';

/// Results of one exam: each class, and within it each section, with how
/// many subject teachers have submitted. Updates live as they submit.
class ExamResultsScreen extends StatefulWidget {
  final String examId;
  const ExamResultsScreen({super.key, required this.examId});

  static Future<void> open(BuildContext context, {required String examId}) {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => ExamResultsScreen(examId: examId)));
  }

  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> {
  ExamOverview? _overview;
  List<Classroom> _classrooms = const [];
  bool _error = false;
  String? _expanded;
  StreamSubscription<List<ExamMarkSheet>>? _live;

  @override
  void initState() {
    super.initState();
    _load();
    _live = context.read<ExamRepository>().watchSheets(widget.examId).listen((sheets) {
      final o = _overview;
      if (!mounted || o == null) return;
      setState(() => _overview = ExamOverview(exam: o.exam, schedules: o.schedules, papers: o.papers, sheets: sheets));
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
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

  Future<void> _openSection(Classroom classroom) async {
    final o = _overview!;
    await SectionResultsScreen.open(context, overview: o, classroom: classroom);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final o = _overview;
    return Scaffold(
      appBar: AppBar(title: Text(o == null ? 'Results' : '${o.exam.name} results')),
      body: SafeArea(
        child: o == null
            ? (_error
                ? EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load results",
                    subtitle: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: _load,
                  )
                : const Center(child: CircularProgressIndicator()))
            : _body(o),
      ),
    );
  }

  Widget _body(ExamOverview o) {
    final progress = ResultsProgress.of(o, _classrooms);
    final grades = progress.byGrade.keys.toList();
    if (grades.isEmpty) {
      return const EmptyState(
        icon: Icons.table_chart_outlined,
        title: 'No timetable yet',
        subtitle: 'Results come in once a class has subjects on its exam timetable.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SoftSurface(
            depth: SoftDepth.two,
            borderRadius: BorderRadius.circular(22),
            padding: const EdgeInsets.all(18),
            child: SubmissionBar(submitted: progress.submitted, total: progress.expected),
          ),
          const SizedBox(height: 18),
          for (final g in grades)
            _GradeResultsCard(
              gradeKey: g,
              overview: o,
              sections: ExamPlanning.sectionsOf(g, _classrooms),
              progress: progress.byGrade[g]!,
              expanded: _expanded == g,
              onTap: () {
                final sections = ExamPlanning.sectionsOf(g, _classrooms);
                if (sections.length == 1) {
                  _openSection(sections.single);
                } else {
                  setState(() => _expanded = _expanded == g ? null : g);
                }
              },
              onSection: _openSection,
            ),
        ],
      ),
    );
  }
}

class _GradeResultsCard extends StatelessWidget {
  final String gradeKey;
  final ExamOverview overview;
  final List<Classroom> sections;
  final (int, int) progress;
  final bool expanded;
  final VoidCallback onTap;
  final ValueChanged<Classroom> onSection;

  const _GradeResultsCard({
    required this.gradeKey,
    required this.overview,
    required this.sections,
    required this.progress,
    required this.expanded,
    required this.onTap,
    required this.onSection,
  });

  @override
  Widget build(BuildContext context) {
    final papers = overview.papersFor(gradeKey);
    final multi = sections.length > 1;
    final mute = AppColors.onSurfaceMuted(context);
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(GradeCatalog.label(gradeKey),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          '${papers.length} subject${papers.length == 1 ? '' : 's'}'
                          '${multi ? ' · ${sections.length} sections' : ''}',
                          style: TextStyle(fontSize: 12.5, color: mute),
                        ),
                        const SizedBox(height: 10),
                        SubmissionBar(submitted: progress.$1, total: progress.$2, noun: 'sheets'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: multi && expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !(multi && expanded)
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      const Divider(height: 1),
                      for (final c in sections)
                        ListTile(
                          onTap: () => onSection(c),
                          contentPadding: const EdgeInsets.fromLTRB(20, 2, 12, 2),
                          title: Text('Section ${c.resolvedSection.isEmpty ? c.displayName : c.resolvedSection}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(_sectionLine(c, papers), style: TextStyle(fontSize: 12, color: mute)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        ),
                      const SizedBox(height: 6),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _sectionLine(Classroom c, List<ExamPaper> papers) {
    final done = papers.where((p) => overview.sheetFor(p.id, c.id)?.isSubmitted == true).length;
    if (papers.isEmpty) return 'No subjects';
    if (done == papers.length) return 'All ${papers.length} subjects submitted';
    return '$done of ${papers.length} subjects submitted';
  }
}
