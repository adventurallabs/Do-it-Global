import 'package:flutter/material.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/design_system/app_typography.dart';
import '../../../shared/widgets/premium_card.dart';

class DiarySummaryCard extends StatelessWidget {
  const DiarySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Digital Diary', style: AppTypography.labelMedium),
              const Icon(Icons.book_outlined, size: 16),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Open the Diary tab for history', style: AppTypography.headingSmall),
        ],
      ),
    );
  }
}
