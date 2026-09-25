import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../shared/models/exams.dart';
import '../../shared/widgets/premium_card.dart';
import 'exam_widgets.dart';

/// One exam's timetable for the child's class, read as a table.
class ExamTimetableScreen extends StatelessWidget {
  final ParentExam exam;
  const ExamTimetableScreen({super.key, required this.exam});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final next = exam.nextPaper;
    return Scaffold(
      appBar: AppBar(title: Text(exam.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
          children: [
            PremiumCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.exYourChildTimetable(gradeLabel(exam.gradeKey)), style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          '${dateRange(context, exam.firstDate, exam.lastDate)} · ${l10n.exSubjectCount(exam.papers.length)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  ExamPhaseBadge(phase: exam.phase),
                ],
              ),
            ),
            if (next != null && exam.phase != ExamPhase.past) ...[
              const SizedBox(height: AppSpacing.sm),
              _NextUp(paper: next),
            ],
            const SizedBox(height: AppSpacing.md),
            _Table(exam: exam),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.exTapForSyllabus, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _NextUp extends StatelessWidget {
  final ExamPaper paper;
  const _NextUp({required this.paper});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = paper.isToday;
    final color = today ? AppColors.warning : AppColors.primaryBlue;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
            child: Icon(today ? Icons.edit_note_rounded : Icons.hourglass_top_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.exNext(paper.subject, whenLabel(context, paper.date)),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(paperTime(context, paper), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  final ParentExam exam;
  const _Table({required this.exam});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final line = isDark ? AppColors.grey700 : AppColors.grey200;
    final headBg = isDark ? AppColors.royalBlue.withValues(alpha: 0.35) : AppColors.royalBlue;
    final loc = Localizations.localeOf(context).toString();
    final head = const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.4);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          color: isDark ? AppColors.surfaceDark : Colors.white,
        ),
        child: Column(
          children: [
            Container(
              color: headBg,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(width: 64, child: Text(l10n.exDate.toUpperCase(), style: head)),
                  Expanded(child: Text(l10n.exSubject.toUpperCase(), style: head)),
                  SizedBox(width: 92, child: Text(l10n.exTime.toUpperCase(), style: head, textAlign: TextAlign.right)),
                ],
              ),
            ),
            for (var i = 0; i < exam.papers.length; i++) ...[
              if (i > 0) Divider(height: 1, color: line),
              _row(context, exam.papers[i], loc, repeatDate: i > 0 && daysUntil(exam.papers[i - 1].date) == daysUntil(exam.papers[i].date)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, ExamPaper p, String loc, {required bool repeatDate}) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final done = p.phase == ExamPhase.past;
    final today = p.isToday;
    final muted = theme.textTheme.bodySmall?.color;
    return Material(
      color: today ? AppColors.warning.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: () => showPaperSheet(
          context,
          p,
          heading: '${exam.name} · ${gradeLabel(exam.gradeKey)}',
          showMarks: exam.mode.usesMarks,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: repeatDate
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat.d(loc).format(p.date),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1,
                              color: done ? muted : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormat.MMM(loc).format(p.date)} · ${DateFormat.E(loc).format(p.date)}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.subject,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: done ? muted : null,
                            ),
                          ),
                        ),
                        if (done) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle_rounded, size: 15, color: AppColors.success),
                        ],
                        if (today) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(l10n.exToday.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exam.mode.usesMarks
                          ? '${l10n.exOutOf(fmtMarks(p.maxMarks))} · ${l10n.exPassMark(fmtMarks(p.passMarks))}'
                          : l10n.exGraded,
                      style: theme.textTheme.labelSmall,
                    ),
                    if (p.syllabus.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        p.syllabus.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 92,
                child: Text(
                  '${timeLabel(context, p.startTime)}\n${timeLabel(context, p.endTime)}',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelMedium?.copyWith(height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
