import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../shared/widgets/empty_state.dart';
import '../parent/parent_store.dart';
import 'widgets/progress_widgets.dart';

/// Every star the child has earned, newest first, with who gave it and why.
class StarsScreen extends ConsumerWidget {
  const StarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(studentStarsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.stars)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            StarsHeroCard(summary: summary),
            const SizedBox(height: AppSpacing.lg),
            if (summary.awards.isEmpty)
              AppEmptyState(
                icon: Icons.star_outline_rounded,
                title: l10n.noStarsTitle,
                body: l10n.noStarsBody,
              )
            else
              for (final a in summary.awards) ...[
                StarAwardTile(award: a),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }
}
