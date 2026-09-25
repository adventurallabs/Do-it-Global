import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../shared/widgets/premium_card.dart';
import '../parent/parent_store.dart';

class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({super.key, required this.subject});

  final String subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final results = ref.watch(studentMarksProvider).where((m) => m.subject == subject).toList();
    final avg = results.isEmpty
        ? null
        : (results.fold<double>(0, (s, r) => s + (r.scored / r.maxMarks) * 100) / results.length).round();

    return Scaffold(
      appBar: AppBar(title: Text(subject)),
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          PremiumCard(
            child: Column(
              children: [
                ...results.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(child: Text(r.examName, style: theme.textTheme.bodyLarge)),
                        Text('${r.scored}', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                ),
                if (avg != null) ...[
                  const Divider(),
                  Row(
                    children: [
                      Expanded(child: Text(l10n.averageLabel, style: theme.textTheme.titleMedium)),
                      Text(l10n.percentValue(avg), style: theme.textTheme.headlineSmall),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}
