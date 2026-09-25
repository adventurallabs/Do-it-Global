import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/localization/l10n_ext.dart';
import '../../shared/models/exams.dart';

Color phaseColor(ExamPhase phase) => switch (phase) {
      ExamPhase.upcoming => AppColors.primaryBlue,
      ExamPhase.ongoing => AppColors.warning,
      ExamPhase.past => AppColors.success,
    };

String phaseLabel(BuildContext context, ExamPhase phase) {
  final l10n = context.l10n;
  return switch (phase) {
    ExamPhase.upcoming => l10n.exUpcoming,
    ExamPhase.ongoing => l10n.exOngoing,
    ExamPhase.past => l10n.exCompleted,
  };
}

/// "Today", "Tomorrow", "In 4 days", "Done".
String whenLabel(BuildContext context, DateTime date) {
  final l10n = context.l10n;
  final d = daysUntil(date);
  if (d < 0) return l10n.exDone;
  if (d == 0) return l10n.exToday;
  if (d == 1) return l10n.exTomorrow;
  return l10n.exInDays(d);
}

String _locale(BuildContext context) => Localizations.localeOf(context).toString();

/// "10:00 AM"
String timeLabel(BuildContext context, String hhmm) {
  final parts = hhmm.split(':');
  final h = int.tryParse(parts.first) ?? 0;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return DateFormat.jm(_locale(context)).format(DateTime(2000, 1, 1, h, m));
}

String paperTime(BuildContext context, ExamPaper p) => '${timeLabel(context, p.startTime)} – ${timeLabel(context, p.endTime)}';

/// "12 – 18 Oct"
String dateRange(BuildContext context, DateTime? first, DateTime? last) {
  if (first == null || last == null) return '';
  final loc = _locale(context);
  if (daysUntil(first) == daysUntil(last)) return DateFormat.MMMEd(loc).format(first);
  return '${DateFormat.MMMd(loc).format(first)} – ${DateFormat.MMMd(loc).format(last)}';
}

class ExamPhaseBadge extends StatelessWidget {
  final ExamPhase phase;
  const ExamPhaseBadge({super.key, required this.phase});

  @override
  Widget build(BuildContext context) {
    final color = phaseColor(phase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            phaseLabel(context, phase),
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// Full detail of one paper, syllabus included.
Future<void> showPaperSheet(BuildContext context, ExamPaper paper, {String? heading, bool showMarks = true}) {
  final l10n = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      Widget line(IconData icon, String text) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: theme.textTheme.titleSmall)),
              ],
            ),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (heading != null) Text(heading, style: theme.textTheme.labelMedium),
              Text(paper.subject, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 14),
              line(Icons.event_rounded, DateFormat.yMMMMEEEEd(_locale(sheet)).format(paper.date)),
              line(Icons.schedule_rounded, paperTime(sheet, paper)),
              line(Icons.grading_rounded, !showMarks ? l10n.exGraded :
                  '${l10n.exOutOf(fmtMarks(paper.maxMarks))} · ${l10n.exPassMark(fmtMarks(paper.passMarks))}'),
              const SizedBox(height: 10),
              Text(l10n.exSyllabus.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.4),
                child: SingleChildScrollView(
                  child: Text(
                    paper.syllabus.trim().isEmpty ? l10n.exNoSyllabus : paper.syllabus.trim(),
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
