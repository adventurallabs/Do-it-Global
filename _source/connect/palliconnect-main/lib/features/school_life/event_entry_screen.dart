import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_provider.dart';
import '../../core/data/parent_repository.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../shared/models/event_entry.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/premium_card.dart';
import 'school_life_providers.dart';

/// The contests in one event that this child may take part in.
///
/// Only categories whose head has opened this child's class ever reach here,
/// so there is nothing on this screen they are not allowed to enter.
class EventEntryScreen extends ConsumerWidget {
  final OpenEvent event;
  const EventEntryScreen({super.key, required this.event});

  static Future<void> open(BuildContext context, OpenEvent event) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventEntryScreen(event: event)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(openCategoriesProvider(event.id));
    return Scaffold(
      appBar: AppBar(title: Text(event.name, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: "Couldn't load this event",
            body: 'Check your connection and pull down to try again.',
          ),
          data: (categories) {
            if (categories.isEmpty) {
              return const AppEmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'Nothing open yet',
                body: 'When the school opens an item of this event to your '
                    'class, it will appear here.',
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(openCategoriesProvider(event.id).future),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                itemCount: categories.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                      child: Text(
                        event.description.trim().isEmpty
                            ? 'Choose what your child would like to take part in.'
                            : event.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }
                  return _CategoryCard(
                    eventId: event.id,
                    category: categories[index - 1],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryCard extends ConsumerStatefulWidget {
  final String eventId;
  final OpenEventCategory category;

  const _CategoryCard({required this.eventId, required this.category});

  @override
  ConsumerState<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends ConsumerState<_CategoryCard> {
  bool _busy = false;

  void _say(String message, {bool bad = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: bad ? Colors.red.shade700 : null,
      ));
  }

  Future<void> _enter() async {
    final student = ref.read(currentStudentProvider);
    if (student == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(parentRepositoryProvider).enterCategory(
            categoryId: widget.category.id,
            studentId: student.id,
            classroomId: student.classroomId,
          );
      ref.invalidate(openCategoriesProvider(widget.eventId));
      ref.invalidate(openEventsProvider);
      _say('${student.fullName} is entered for ${widget.category.name}.');
    } catch (_) {
      _say("Couldn't enter. Entries may have closed — pull down to refresh.", bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() async {
    final id = widget.category.participantId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw?'),
        content: Text('Your child will no longer be entered for ${widget.category.name}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay in')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(parentRepositoryProvider).withdrawFromCategory(id);
      ref.invalidate(openCategoriesProvider(widget.eventId));
      ref.invalidate(openEventsProvider);
      _say('Withdrawn from ${widget.category.name}.');
    } catch (_) {
      _say("Couldn't withdraw. The teacher may already have placed them.", bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final theme = Theme.of(context);
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  c.competitive ? Icons.emoji_events_outlined : Icons.groups_2_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(c.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                if (c.isEntered)
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                c.typeLabel,
                if (c.issuesCertificates) 'certificate' else 'no certificate',
              ].join('  ·  '),
              style: theme.textTheme.bodySmall,
            ),
            if (c.description.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(c.description, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.sm),
            _action(context, c),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, OpenEventCategory c) {
    final theme = Theme.of(context);
    if (_busy) {
      return const SizedBox(
        height: 46,
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (c.canEnter) {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: FilledButton.icon(
          onPressed: _enter,
          icon: const Icon(Icons.person_add_alt_rounded, size: 19),
          label: const Text('Add me as participant'),
        ),
      );
    }
    if (c.isEntered) {
      return Row(
        children: [
          Expanded(
            child: Text(
              c.inRoom
                  ? 'Entered — the teacher has placed you in a group.'
                  : 'Entered. Your teacher will confirm the details.',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.green.shade700, fontWeight: FontWeight.w600),
            ),
          ),
          if (c.canWithdraw)
            TextButton(onPressed: _withdraw, child: const Text('Withdraw')),
        ],
      );
    }
    return Text(
      'Entries for this have closed.',
      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.defaultAccent),
    );
  }
}
