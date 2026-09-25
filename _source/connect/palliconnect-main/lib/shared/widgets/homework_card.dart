import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../models/homework.dart';
import 'premium_card.dart';

class HomeworkCard extends StatelessWidget {
  final HomeworkItem item;
  final VoidCallback onToggle;
  final VoidCallback? onOpen;

  const HomeworkCard({
    super.key,
    required this.item,
    required this.onToggle,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final urgency = item.urgencyOn(DateTime.now());
    
    final assignedStr = DateFormat.MMMd(locale).format(item.assignedOn);
    final dueStr = DateFormat.MMMd(locale).format(item.dueDate);

    final statusColor = switch (item.status) {
      HomeworkStatus.pending => urgency == HomeworkUrgency.overdue ? AppColors.error : AppColors.warning,
      HomeworkStatus.underReview => AppColors.info,
      HomeworkStatus.completed => AppColors.success,
    };

    final statusLabel = switch (item.status) {
      HomeworkStatus.pending => urgency == HomeworkUrgency.overdue ? l10n.overdue : l10n.filterPending,
      HomeworkStatus.underReview => l10n.underReview,
      HomeworkStatus.completed => l10n.completed,
    };

    return PremiumCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.subject,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(item.title, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${l10n.assignedOn}: $assignedStr · ${l10n.dueOn}: $dueStr',
            style: theme.textTheme.bodySmall,
          ),
          if (item.teacherName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.teacherName,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
          if (item.hasAttachment) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.attach_file, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(l10n.attachment, style: theme.textTheme.labelMedium),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          
          if (item.status != HomeworkStatus.completed)
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onToggle();
              },
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: item.status == HomeworkStatus.underReview
                      ? AppColors.infoSoft
                      : theme.colorScheme.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.status == HomeworkStatus.underReview ? AppColors.info : Colors.transparent,
                        border: Border.all(
                          color: item.status == HomeworkStatus.underReview
                              ? AppColors.info
                              : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: item.status == HomeworkStatus.underReview
                          ? const Icon(Icons.access_time_rounded, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      item.status == HomeworkStatus.underReview ? l10n.submittedForReview : l10n.markAsCompleted,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: item.status == HomeworkStatus.underReview ? AppColors.infoOnSoft : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
