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
import 'exam_widgets.dart';
import 'result_statement_screen.dart';

/// Every exam the child has sat (or is sitting), with how many subjects'
/// marks are out. Tap one for the full statement of marks.
class ResultsScreen extends ConsumerStatefulWidget {
  /// Opens straight into this exam's statement once loaded (notification tap).
  final String? openExamId;
  const ResultsScreen({super.key, this.openExamId});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool _opened = false;

  void _maybeOpen(List<ExamResultSheet> sheets) {
    if (_opened || widget.openExamId == null) return;
    _opened = true;
    if (!sheets.any((s) => s.exam.examId == widget.openExamId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppRoutes.push(context, ResultStatementScreen(examId: widget.openExamId!));
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(parentExamsProvider);
    ref.invalidate(parentExamMarksProvider);
    await ref.read(parentExamsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(parentExamResultsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exResults)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [AppErrorState(onRetry: _refresh)],
            ),
            data: (sheets) {
              _maybeOpen(sheets);
              if (sheets.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    AppEmptyState(
                      icon: Icons.fact_check_outlined,
                      title: l10n.exNoResultsTitle,
                      body: l10n.exNoResultsBody,
                    ),
                  ],
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
                itemCount: sheets.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) => _ResultCard(
                  sheet: sheets[i],
                  onTap: () => AppRoutes.push(context, ResultStatementScreen(examId: sheets[i].exam.examId)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ExamResultSheet sheet;
  final VoidCallback onTap;
  const _ResultCard({required this.sheet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final passed = sheet.passed;
    final complete = sheet.isComplete;
    final color = !complete
        ? AppColors.primaryBlue
        : passed == true
            ? AppColors.success
            : AppColors.error;
    return PremiumCard(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: sheet.rows.isEmpty ? 0 : sheet.releasedCount / sheet.rows.length,
                  strokeWidth: 5,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.14),
                ),
                Text(
                  complete && sheet.percent != null ? '${sheet.percent!.round()}%' : '${sheet.releasedCount}/${sheet.rows.length}',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sheet.exam.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  sheet.releasedCount == 0
                      ? l10n.exResultsNotOut
                      : complete
                          ? l10n.exAllResultsOut
                          : l10n.exResultsOut(sheet.releasedCount, sheet.rows.length),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(dateRange(context, sheet.exam.firstDate, sheet.exam.lastDate), style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          if (complete)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
              child: Text(
                passed == true ? l10n.exResultPass : l10n.exResultFail,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
              ),
            ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
