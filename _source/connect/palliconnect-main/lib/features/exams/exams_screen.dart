import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/navigation/app_routes.dart';
import '../../shared/models/exams.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/premium_card.dart';
import 'exam_providers.dart';
import 'exam_timetable_screen.dart';
import 'exam_widgets.dart';

/// Every published exam timetable for the child, split into upcoming,
/// ongoing and completed.
class ExamsScreen extends ConsumerStatefulWidget {
  /// Opens straight into this exam's timetable once loaded (notification tap).
  final String? openExamId;
  const ExamsScreen({super.key, this.openExamId});

  @override
  ConsumerState<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends ConsumerState<ExamsScreen> {
  int? _tab;
  bool _opened = false;

  void _maybeOpen(List<ParentExam> exams) {
    if (_opened || widget.openExamId == null) return;
    _opened = true;
    final match = exams.where((e) => e.examId == widget.openExamId).firstOrNull;
    if (match == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppRoutes.push(context, ExamTimetableScreen(exam: match));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(parentExamsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exExams)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(parentExamsProvider.future),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [AppErrorState(onRetry: () => ref.invalidate(parentExamsProvider))],
            ),
            data: (exams) {
              _maybeOpen(exams);
              final counts = [for (final p in ExamPhase.values) exams.where((e) => e.phase == p).length];
              final tab = _tab ?? (counts[1] > 0 ? 1 : 0);
              final shown = exams.where((e) => e.phase == ExamPhase.values[tab]).toList();
              if (tab != 2) {
                shown.sort((a, b) => (a.firstDate ?? DateTime(2100)).compareTo(b.firstDate ?? DateTime(2100)));
              }
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
                children: [
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      for (var i = 0; i < 3; i++)
                        ButtonSegment(
                          value: i,
                          label: Text(
                            '${phaseLabel(context, ExamPhase.values[i])}${counts[i] > 0 ? ' ${counts[i]}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    selected: {tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (shown.isEmpty)
                    AppEmptyState(
                      icon: Icons.event_note_outlined,
                      title: l10n.exNoExamsTitle,
                      body: l10n.exNoExamsBody,
                    )
                  else
                    for (final e in shown) ...[
                      _ExamCard(exam: e, onTap: () => AppRoutes.push(context, ExamTimetableScreen(exam: e))),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final ParentExam exam;
  final VoidCallback onTap;
  const _ExamCard({required this.exam, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final next = exam.nextPaper;
    final done = exam.papers.where((p) => p.phase == ExamPhase.past).length;
    return PremiumCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(exam.name, style: theme.textTheme.titleMedium)),
              ExamPhaseBadge(phase: exam.phase),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${dateRange(context, exam.firstDate, exam.lastDate)} · ${l10n.exSubjectCount(exam.papers.length)}',
            style: theme.textTheme.bodySmall,
          ),
          if (next != null && exam.phase != ExamPhase.past) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 18, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.exNext(next.subject, '${whenLabel(context, next.date)} · ${timeLabel(context, next.startTime)}'),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (exam.phase == ExamPhase.ongoing) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: exam.papers.isEmpty ? 0 : done / exam.papers.length,
                minHeight: 5,
                color: AppColors.warning,
                backgroundColor: AppColors.warning.withValues(alpha: 0.14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
