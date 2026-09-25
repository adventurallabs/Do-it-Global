import 'package:flutter/material.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../features/progress/widgets/progress_widgets.dart';
import '../models/activity.dart';
import 'premium_card.dart';

class ActivityCard extends StatelessWidget {
  final SchoolActivity activity;

  const ActivityCard({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final a = activity;
    final result = a.result ?? '';
    final achievement = a.achievement ?? '';
    final remarks = a.teacherRemarks ?? '';
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: AppColors.brandSweep(opacity: 0.16),
                ),
                child: Icon(activityIcon(a.category), color: AppColors.primaryBlue),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      [if (a.category.isNotEmpty) a.category, shortDate(context, a.date)].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (result.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.leafGreen.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    result,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (achievement.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('${l10n.achievement}: $achievement', style: theme.textTheme.bodyMedium),
          ],
          if (remarks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.teacherRemarks, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Text(remarks, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
          if ((a.documentLabel ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              a.documentLabel!,
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}
