import 'package:flutter/material.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';

class AppErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const AppErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Text(l10n.unableToRefresh, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.showingLastSynced, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
        ],
      ),
    );
  }
}
