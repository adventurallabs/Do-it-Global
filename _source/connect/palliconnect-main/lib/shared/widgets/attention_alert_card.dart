import 'package:flutter/material.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../models/attention.dart';
import 'premium_card.dart';

class AttentionAlertCard extends StatelessWidget {
  final AttentionItem item;
  final VoidCallback onTap;

  const AttentionAlertCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = switch (item.kind) {
      AttentionKind.homeworkOverdue => (Icons.assignment_late_outlined, AppColors.errorOnSoft, AppColors.errorSoft),
      AttentionKind.homeworkToday => (Icons.schedule_outlined, AppColors.warningOnSoft, AppColors.warningSoft),
      AttentionKind.fee => (Icons.account_balance_wallet_outlined, AppColors.warningOnSoft, AppColors.warningSoft),
      AttentionKind.announcement => (Icons.campaign_outlined, AppColors.infoOnSoft, AppColors.infoSoft),
      AttentionKind.attendance => (Icons.event_busy_outlined, AppColors.errorOnSoft, AppColors.errorSoft),
      AttentionKind.marks => (Icons.insights_outlined, AppColors.infoOnSoft, AppColors.infoSoft),
      AttentionKind.profile => (Icons.assignment_ind_outlined, AppColors.warningOnSoft, AppColors.warningSoft),
    };

    return PremiumCard(
      onTap: onTap,
      color: bg,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOnSoftCard,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7)),
        ],
      ),
    );
  }
}
