import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_spacing.dart';
import '../../shared/models/event_entry.dart';
import '../../shared/widgets/premium_card.dart';
import 'event_entry_screen.dart';
import 'school_life_providers.dart';

/// Events the child's class has been opened to, at the top of Events.
///
/// This draws nothing until a head opens a class, so most of the year the
/// screen looks exactly as it did before.
class OpenEventsSection extends ConsumerWidget {
  const OpenEventsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(openEventsProvider).valueOrNull ?? const [];
    final upcoming = events.where((e) => e.isUpcoming).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
          child: Text(
            'Take part',
            style:
                Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final e in upcoming)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _OpenEventCard(event: e),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _OpenEventCard extends StatelessWidget {
  final OpenEvent event;
  const _OpenEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entered = event.enteredCount;
    return PremiumCard(
      onTap: () => EventEntryScreen.open(context, event),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.celebration_outlined, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('d MMM').format(event.eventDate)}  ·  '
                    '${event.categoryCount} item${event.categoryCount == 1 ? '' : 's'} open',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (entered > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Entered in $entered',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green.shade700, fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
