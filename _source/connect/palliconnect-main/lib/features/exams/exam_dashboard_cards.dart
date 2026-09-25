import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/features/feature_registry.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/navigation/app_routes.dart';
import '../../shared/widgets/premium_card.dart';
import 'exam_providers.dart';
import 'exam_widgets.dart';
import 'exams_screen.dart';
import 'results_screen.dart';

/// The Exams and Results doors on Today and Progress. Each says what's
/// waiting before it's opened: the paper on now or next, and the latest
/// result that's out.
class ExamDashboardCards extends ConsumerWidget {
  const ExamDashboardCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureRegistryProvider).isEnabled('marks')) return const SizedBox.shrink();
    final l10n = context.l10n;
    final s = ref.watch(examSummaryProvider);
    // Until the first load lands, don't claim "nothing scheduled".
    final exams = ref.watch(parentExamsProvider);
    final pending = !exams.hasValue && !exams.hasError;

    String examLine;
    var live = false;
    if (pending) {
      examLine = '…';
    } else if (s.ongoing != null) {
      live = true;
      final next = s.ongoing!.nextPaper;
      examLine = next == null
          ? l10n.exOnNow(s.ongoing!.name)
          : l10n.exNext(next.subject, whenLabel(context, next.date));
    } else if (s.upcoming != null) {
      examLine = l10n.exStartsIn(s.upcoming!.name, whenLabel(context, s.upcoming!.firstDate!));
    } else {
      examLine = l10n.exNothingScheduled;
    }

    final latest = s.latest;
    final resultLine = pending
        ? '…'
        : latest == null
        ? l10n.exNoResultsTitle
        : latest.isComplete
            ? l10n.exLatestResult(latest.exam.name)
            : l10n.exResultsOut(latest.releasedCount, latest.rows.length);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Door(
            icon: Icons.event_note_rounded,
            color: AppColors.primaryBlue,
            title: l10n.exExams,
            subtitle: examLine,
            live: live,
            onTap: () => AppRoutes.push(context, const ExamsScreen()),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _Door(
            icon: Icons.workspace_premium_rounded,
            color: AppColors.leafGreen,
            title: l10n.exResults,
            subtitle: resultLine,
            trailing: latest?.percent == null ? null : '${latest!.percent!.round()}%',
            onTap: () => AppRoutes.push(context, const ResultsScreen()),
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
  final String? trailing;
  final bool live;
  final VoidCallback onTap;

  const _Door({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.live = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: PremiumCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 21),
                    ),
                    if (live)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                if (trailing != null)
                  Text(trailing!, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
