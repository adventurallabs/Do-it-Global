import 'package:flutter/material.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/design_system/app_typography.dart';
import '../../../shared/widgets/premium_card.dart';
import '../../../core/navigation/app_routes.dart';
import '../../fees/fees_screen.dart';

class FeesSummaryCard extends StatelessWidget {
  const FeesSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: () => AppRoutes.push(context, const FeesScreen()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Fees', style: AppTypography.labelMedium),
              const Icon(Icons.account_balance_wallet_outlined, size: 16),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Open fee details', style: AppTypography.headingSmall),
        ],
      ),
    );
  }
}
