import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import 'teacher_exam_data.dart';
import 'teacher_results_screen.dart';

Future<TeacherExamData> loadTeacherExamData(BuildContext context, String teacherId, {bool force = false}) {
  return TeacherExamData.load(
    teacherId: teacherId,
    exams: context.read<ExamRepository>(),
    classrooms: context.read<ClassroomRepository>(),
    timetables: context.read<TimetableRepository>(),
    force: force,
  );
}

/// Published exam timetables for the classes this teacher takes, sorted into
/// upcoming, ongoing and completed.
class TeacherExamsScreen extends StatefulWidget {
  final String teacherId;
  const TeacherExamsScreen({super.key, required this.teacherId});

  static Future<void> open(BuildContext context, {required String teacherId}) {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherExamsScreen(teacherId: teacherId)));
  }

  @override
  State<TeacherExamsScreen> createState() => _TeacherExamsScreenState();
}

class _TeacherExamsScreenState extends State<TeacherExamsScreen> {
  TeacherExamData? _data;
  bool _error = false;
  int? _tab;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _error = false);
    try {
      final data = await loadTeacherExamData(context, widget.teacherId, force: force);
      if (!mounted) return;
      setState(() {
        _data = data;
        // Open on whatever is happening now.
        _tab ??= data.timetables.any((e) => e.phase == ExamPhase.ongoing) ? 1 : 0;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final all = data?.timetables ?? const <TeacherTimetableEntry>[];
    final counts = [for (final p in ExamPhase.values) all.where((e) => e.phase == p).length];
    final tab = _tab ?? 0;
    final shown = all.where((e) => e.phase == ExamPhase.values[tab]).toList();
    if (tab != 2) {
      // Soonest first while it's still ahead.
      shown.sort((a, b) => (a.schedule.firstDate ?? DateTime(2100)).compareTo(b.schedule.firstDate ?? DateTime(2100)));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Exams')),
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
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    SoftSegmentedControl(
                      labels: [
                        'Upcoming${counts[0] > 0 ? ' · ${counts[0]}' : ''}',
                        'Ongoing${counts[1] > 0 ? ' · ${counts[1]}' : ''}',
                        'Done${counts[2] > 0 ? ' · ${counts[2]}' : ''}',
                      ],
                      index: tab,
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                    const SizedBox(height: 14),
                    if (shown.isEmpty)
                      SizedBox(
                        height: 340,
                        child: EmptyState(
                          icon: Icons.event_note_outlined,
                          title: switch (tab) {
                            0 => 'No upcoming exams',
                            1 => 'No exam going on',
                            _ => 'No completed exams',
                          },
                          subtitle: all.isEmpty
                              ? 'Exam timetables for your classes appear here once the admin publishes them.'
                              : null,
                        ),
                      )
                    else
                      for (var i = 0; i < shown.length; i++)
                        AnimatedListItem(
                          index: i,
                          child: _TimetableCard(
                            entry: shown[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TeacherExamTimetableScreen(entry: shown[i], teacherId: widget.teacherId),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TimetableCard extends StatelessWidget {
  final TeacherTimetableEntry entry;
  final VoidCallback onTap;
  const _TimetableCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    final papers = entry.papers;
    final next = entry.nextPaper;
    final mine = papers.where((p) => entry.mySubjects.contains(p.subject.trim().toLowerCase())).length;
    final isHomeroom = entry.isHomeroom;
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
                child: Text(entry.overview.exam.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              ExamPhasePill(phase: entry.phase),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${GradeCatalog.label(entry.schedule.gradeKey)} · ${ExamDates.range(entry.schedule.firstDate, entry.schedule.lastDate)}'
            '${isHomeroom ? ' · your class' : ''}',
            style: TextStyle(fontSize: 13, color: mute),
          ),
          if (next != null && entry.phase != ExamPhase.past) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Next: ${next.subject} · ${ExamDates.countdown(next.examDate)} · ${ExamDates.display(next.startTime)}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '${papers.length} subject${papers.length == 1 ? '' : 's'}'
            '${mine > 0 ? ' · you mark $mine' : ''}',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceHint(context)),
          ),
        ],
      ),
    );
  }
}

/// One standard's published timetable, read-only, with the teacher's own
/// subjects flagged.
class TeacherExamTimetableScreen extends StatelessWidget {
  final TeacherTimetableEntry entry;
  final String teacherId;
  const TeacherExamTimetableScreen({super.key, required this.entry, required this.teacherId});

  @override
  Widget build(BuildContext context) {
    final label = GradeCatalog.label(entry.schedule.gradeKey);
    final mine = entry.papers.where((p) => entry.mySubjects.contains(p.subject.trim().toLowerCase())).isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label timetable', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(entry.overview.exam.name,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.onSurfaceMuted(context))),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Row(
              children: [
                ExamPhasePill(phase: entry.phase),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ExamDates.range(entry.schedule.firstDate, entry.schedule.lastDate),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurfaceMuted(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ExamTimetableTable(
              papers: entry.papers,
              highlightSubjects: entry.mySubjects,
              highlightLabel: 'You mark',
              mode: entry.overview.exam.resultMode,
              onTap: (p) => showExamPaperDetails(
                context,
                p,
                heading: '$label · ${entry.overview.exam.name}',
                mode: entry.overview.exam.resultMode,
              ),
            ),
            const SizedBox(height: 8),
            Text('Tap a subject to read its full syllabus.',
                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceHint(context))),
            if (mine) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => TeacherExamClassesScreen.open(
                    context,
                    teacherId: teacherId,
                    examId: entry.overview.exam.id,
                  ),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Enter marks'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
