import 'package:flutter/material.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/design_system/app_typography.dart';
import '../../../shared/widgets/premium_card.dart';
import '../../../core/navigation/app_routes.dart';
import '../homework_screen.dart';

class HomeworkSummaryCard extends StatelessWidget {
  const HomeworkSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: () => AppRoutes.push(context, const HomeworkScreen()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pending Homework', style: AppTypography.labelMedium),
              const Icon(Icons.assignment_outlined, size: 16),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Open homework', style: AppTypography.headingSmall),
        ],
      ),
    );
  }
}
