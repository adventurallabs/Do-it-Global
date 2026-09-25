import 'package:flutter/material.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/utils/formatters.dart';
import '../models/fees.dart';
import 'premium_card.dart';

class FeeSummaryCard extends StatelessWidget {
  final FeeAccount account;
  final VoidCallback onTap;

  const FeeSummaryCard({
    super.key,
    required this.account,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!account.hasDue) return const SizedBox.shrink();
    final days = account.nextDueDate!
        .difference(dateOnly(DateTime.now()))
        .inDays;

    return PremiumCard(
      onTap: onTap,
      color: AppColors.warningSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.warningOnSoft.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.warningOnSoft,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.feeDue,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnSoftCard,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.remainingAmount(formatInr(account.remaining)),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textOnSoftCard,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            days <= 0 ? l10n.dueToday : l10n.dueInDays(days),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.warningOnSoft,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.viewDetails,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.warningOnSoft,
            ),
          ),
        ],
      ),
    );
  }
}
