import 'package:flutter/material.dart';
import '../../core/design_system/app_spacing.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.md),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(body, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
