import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/navigation/app_routes.dart';
import '../../shared/models/library_loan.dart';
import '../../shared/widgets/premium_card.dart';
import 'borrowed_books_screen.dart';
import 'library_providers.dart';

/// "Books borrowed" on Today. Not there at all until the child borrows their
/// first library book; from then on it stays — listing what they have now,
/// and asking for attention when one is due soon or overdue.
class BorrowedBooksCard extends ConsumerWidget {
  const BorrowedBooksCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loans = ref.watch(libraryLoansProvider).valueOrNull ?? const <LibraryLoan>[];
    if (loans.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final name = ref.watch(currentStudentProvider)?.firstName ?? '';
    final open = loans.where((l) => l.isOpen).toList();
    final attention = open.where((l) => l.needsAttention()).toList();
    final overdue = attention.any((l) => l.dueState() == LibraryDueState.overdue);
    final alert = overdue ? AppColors.error : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Semantics(
        button: true,
        label: l10n.libBooksBorrowed,
        child: PremiumCard(
          onTap: () => AppRoutes.push(context, const BorrowedBooksScreen()),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.royalBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.local_library_rounded, color: AppColors.royalBlue),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.libBooksBorrowed, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      open.isEmpty
                          ? l10n.libAllReturned
                          : '${l10n.libHoldingNow(open.length, name)} · ${open.map((l) => l.bookTitle).join(', ')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (attention.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: alert),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              overdue ? l10n.libAttentionOverdue : l10n.libAttentionDueSoon,
                              style: theme.textTheme.labelMedium?.copyWith(color: alert, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
