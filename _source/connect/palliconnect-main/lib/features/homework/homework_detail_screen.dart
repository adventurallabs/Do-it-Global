import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../shared/models/homework.dart';
import '../../shared/widgets/premium_card.dart';
import '../parent/parent_store.dart';

class HomeworkDetailScreen extends ConsumerWidget {
  final HomeworkItem item;

  const HomeworkDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    
    // Watch the item from the store to get the latest status
    final storeItem = ref.watch(studentHomeworkProvider).firstWhere((h) => h.id == item.id, orElse: () => item);

    final statusColor = switch (storeItem.status) {
      HomeworkStatus.pending => AppColors.warning,
      HomeworkStatus.underReview => AppColors.info,
      HomeworkStatus.completed => AppColors.success,
    };

    final statusLabel = switch (storeItem.status) {
      HomeworkStatus.pending => l10n.filterPending,
      HomeworkStatus.underReview => l10n.underReview,
      HomeworkStatus.completed => l10n.completed,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(storeItem.subject),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.md),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            storeItem.title,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _DateBadge(label: l10n.assignedOn, date: storeItem.assignedOn, locale: locale),
              const SizedBox(width: AppSpacing.md),
              _DateBadge(label: l10n.dueOn, date: storeItem.dueDate, locale: locale, isDue: true),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          
          Text(l10n.instructions, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: AppSpacing.sm),
          PremiumCard(
            child: Text(
              storeItem.instructions,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
          ),
          
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text('${l10n.classTeacher}: ', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              Text(storeItem.teacherName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          
          if (storeItem.hasAttachment) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.attachment, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              // There's no real file behind this yet — no storage/URL is
              // ever recorded, `hasAttachment` is just a flag. Say so
              // honestly instead of showing a fake filename and doing
              // nothing on tap.
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("This attachment isn't available for download yet.")),
              ),
              child: PremiumCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, color: AppColors.primaryBlue),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Attachment')),
                    Icon(Icons.info_outline_rounded, size: 20, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 40),
          
          if (storeItem.status == HomeworkStatus.pending)
            ElevatedButton(
              onPressed: () {
                ref.read(parentStoreProvider.notifier).toggleHomework(storeItem.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.submittedForReview)),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(l10n.markAsCompleted),
            )
          else if (storeItem.status == HomeworkStatus.underReview)
            OutlinedButton(
              onPressed: () => ref.read(parentStoreProvider.notifier).toggleHomework(storeItem.id),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(l10n.cancelSubmission),
            ),
            
          if (storeItem.status == HomeworkStatus.underReview) ...[
             const SizedBox(height: 12),
             Text(
               'Submitted — your teacher will confirm it soon.',
               textAlign: TextAlign.center,
               style: theme.textTheme.bodySmall,
             ),
          ],
        ],
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  final String label;
  final DateTime date;
  final String locale;
  final bool isDue;

  const _DateBadge({
    required this.label,
    required this.date,
    required this.locale,
    this.isDue = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.5, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          DateFormat.yMMMMd(locale).format(date),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDue ? AppColors.error : null,
          ),
        ),
      ],
    );
  }
}
