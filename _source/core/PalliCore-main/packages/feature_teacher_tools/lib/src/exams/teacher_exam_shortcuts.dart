import 'package:flutter/material.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import 'teacher_exam_data.dart';
import 'teacher_exams_screen.dart';
import 'teacher_results_screen.dart';

/// The two exam doors on a teacher's Home: the timetables, and the marks
/// they still owe. Each says what's waiting before it's opened.
class TeacherExamShortcuts extends StatefulWidget {
  final String teacherId;

  /// Changes whenever Home refreshes, so these counts refresh with it.
  final Object? refreshToken;

  const TeacherExamShortcuts({super.key, required this.teacherId, this.refreshToken});

  @override
  State<TeacherExamShortcuts> createState() => _TeacherExamShortcutsState();
}

class _TeacherExamShortcutsState extends State<TeacherExamShortcuts> {
  TeacherExamData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TeacherExamShortcuts old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken || old.teacherId != widget.teacherId) _load(force: true);
  }

  Future<void> _load({bool force = false}) async {
    if (widget.teacherId.isEmpty) return;
    try {
      final data = await loadTeacherExamData(context, widget.teacherId, force: force);
      if (mounted) setState(() => _data = data);
    } catch (_) {
      // The cards still open their screens, which show their own errors.
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final timetables = data?.timetables ?? const <TeacherTimetableEntry>[];
    final ongoing = timetables.where((e) => e.phase == ExamPhase.ongoing).toList();
    final upcoming = timetables.where((e) => e.phase == ExamPhase.upcoming).toList()
      ..sort((a, b) => (a.schedule.firstDate ?? DateTime(2100)).compareTo(b.schedule.firstDate ?? DateTime(2100)));
    final pending = data?.pendingSheets ?? 0;
    final toMark = data?.assignments().length ?? 0;

    final examLine = data == null
        ? 'Timetables'
        : ongoing.isNotEmpty
            ? 'On now · ${ongoing.first.overview.exam.name}'
            : upcoming.isNotEmpty
                ? '${upcoming.first.overview.exam.name} · ${ExamDates.countdown(upcoming.first.schedule.firstDate!).toLowerCase()}'
                : 'Nothing scheduled';
    final resultLine = data == null
        ? 'Enter marks'
        : pending > 0
            ? '$pending sheet${pending == 1 ? '' : 's'} to submit'
            : toMark > 0
                ? 'All submitted'
                : 'Nothing to mark';

    return Row(
      children: [
        Expanded(
          child: _Door(
            icon: Icons.event_note_rounded,
            color: AppColors.examCard,
            title: 'Exams',
            subtitle: examLine,
            live: ongoing.isNotEmpty,
            onTap: () async {
              await TeacherExamsScreen.open(context, teacherId: widget.teacherId);
              if (mounted) _load();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Door(
            icon: Icons.grading_rounded,
            color: AppColors.academicsCard,
            title: 'Results',
            subtitle: resultLine,
            badge: pending,
            onTap: () async {
              await TeacherResultsScreen.open(context, teacherId: widget.teacherId);
              if (mounted) _load(force: true);
            },
          ),
        ),
      ],
    );
  }
}

class _Door extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int badge;
  final bool live;
  final VoidCallback onTap;

  const _Door({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
    this.live = false,
  });

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.two,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      onTap: onTap,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              if (badge > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(9)),
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                )
              else if (live)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                      border: Border.all(color: AdminLook.canvasOf(context), width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.onSurface(context))),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, height: 1.3, color: AppColors.onSurfaceMuted(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
