import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/parent_repository.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/event_notice.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/premium_card.dart';
import 'event_results_section.dart';
import 'open_events_section.dart';
import 'school_life_providers.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventNoticesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Events & notices')),
      body: SafeArea(
        child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const AppEmptyState(
          icon: Icons.event_outlined,
          title: 'Nothing to show',
          body: 'Event notices from the school will appear here.',
        ),
        data: (notices) {
          final hasResults =
              (ref.watch(childEventResultsProvider).valueOrNull ?? const []).isNotEmpty;
          final hasOpen = (ref.watch(openEventsProvider).valueOrNull ?? const [])
              .any((e) => e.isUpcoming);
          if (notices.isEmpty && !hasResults && !hasOpen) {
            return const AppEmptyState(
              icon: Icons.event_available_outlined,
              title: 'No event notices',
              body: 'You are all caught up.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(eventNoticesProvider);
              ref.invalidate(childEventResultsProvider);
              ref.invalidate(openEventsProvider);
              await ref.read(eventNoticesProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, 108),
              itemCount: notices.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                // What they can act on comes first — entering an event that
                // has not happened yet, then how their child did in one that
                // has, then the notices that announced them.
                if (index == 0) {
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [OpenEventsSection(), EventResultsSection()],
                  );
                }
                final i = index - 1;
                final n = notices[i];
                return PremiumCard(
                  onTap: () => _open(context, ref, n),
                  // Icon in its own leading column so the title, the date and
                  // the fee chip all start on the same left edge — before,
                  // only the title was indented past the icon and everything
                  // under it hung out to the left.
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.event_outlined,
                            size: 18, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat.yMMMMEEEEd().format(n.eventDate),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (n.requiresFee) ...[
                              const SizedBox(height: 6),
                              _feeChip(context, n),
                            ],
                          ],
                        ),
                      ),
                      if (!n.isSeen) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 7),
                          decoration: const BoxDecoration(
                              color: AppColors.primaryBlue, shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _feeChip(BuildContext context, EventNotice n) {
    final overdue = n.lastPayDate != null && n.lastPayDate!.isBefore(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (overdue ? AppColors.heart : AppColors.primaryBlue).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        n.lastPayDate == null
            ? 'Fee ${formatInr(n.feeAmount.round())}'
            : 'Fee ${formatInr(n.feeAmount.round())} · by ${DateFormat.MMMd().format(n.lastPayDate!)}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: overdue ? AppColors.heart : AppColors.primaryBlue,
        ),
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref, EventNotice n) {
    if (!n.isSeen) {
      ref.read(parentRepositoryProvider).markNoticeSeen(n.id).catchError((_) {});
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(DateFormat.yMMMMEEEEd().format(n.eventDate),
                style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: AppSpacing.xl),
            Text(n.description.isNotEmpty ? n.description : n.body,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
            if (n.requiresFee) ...[
              const SizedBox(height: AppSpacing.lg),
              _feeChip(context, n),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'This fee is added to your fee account. Pay it from the Fees screen.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
