import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../shared/widgets/activity_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../parent/parent_store.dart';

class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final items = ref.watch(studentActivitiesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.activities)),
      body: SafeArea(
        child: items.isEmpty
          ? AppEmptyState(
              icon: Icons.emoji_events_outlined,
              title: l10n.noActivitiesTitle,
              body: l10n.noActivitiesBody,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => ActivityCard(activity: items[i]),
            ),
      ),
    );
  }
}
