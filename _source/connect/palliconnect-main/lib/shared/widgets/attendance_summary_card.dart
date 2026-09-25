import 'package:flutter/material.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../models/attendance.dart';
import 'premium_card.dart';

class AttendanceSummaryCard extends StatelessWidget {
  final AttendanceSummary summary;
  final VoidCallback? onTap;

  const AttendanceSummaryCard({
    super.key,
    required this.summary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return PremiumCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.attendance, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Stat(label: l10n.presentCount, value: '${summary.present}', color: AppColors.success),
              _Stat(label: l10n.absentCount, value: '${summary.absent}', color: AppColors.error),
              _Stat(label: l10n.leaveCount, value: '${summary.leave}', color: AppColors.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.attendancePercent(summary.percent), style: theme.textTheme.titleLarge),
          if (summary.needsAttention) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.attendanceWarning,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
