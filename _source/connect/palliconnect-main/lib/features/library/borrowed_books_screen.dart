import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../../shared/models/library_loan.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/section_header.dart';
import '../parent/parent_store.dart';
import 'library_providers.dart';

/// The child's library books: borrowed now (most urgent first), then
/// returned. Read-only — books are issued and returned at the library.
class BorrowedBooksScreen extends ConsumerStatefulWidget {
  const BorrowedBooksScreen({super.key, this.highlightLoanId});

  /// Opened from a notification: show this loan's details straight away.
  final String? highlightLoanId;

  @override
  ConsumerState<BorrowedBooksScreen> createState() => _BorrowedBooksScreenState();
}

class _BorrowedBooksScreenState extends ConsumerState<BorrowedBooksScreen> {
  bool _highlightShown = false;

  Future<void> _refresh() async {
    ref.read(libraryTickProvider.notifier).state++;
    await ref.read(libraryLoansProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(libraryLoansProvider);
    final loans = async.valueOrNull;

    final target = widget.highlightLoanId;
    if (!_highlightShown && target != null && loans != null) {
      _highlightShown = true;
      final match = loans.where((l) => l.id == target);
      if (match.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showLibraryLoanDetails(context, match.first);
        });
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.libBooksBorrowed)),
      body: SafeArea(
        child: loans == null
            ? async.hasError
                ? _Message(text: l10n.libLoadError, onRetry: _refresh)
                : const Center(child: CircularProgressIndicator())
            : RefreshIndicator(onRefresh: _refresh, child: _List(loans: loans)),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.loans});
  final List<LibraryLoan> loans;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final open = loans.where((l) => l.isOpen).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final returned = loans.where((l) => !l.isOpen).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
      children: [
        SectionHeader(title: l10n.libBorrowedNow),
        if (open.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(l10n.libNoneNow, style: theme.textTheme.bodyMedium),
          )
        else
          for (final l in open) _LoanCard(loan: l),
        if (returned.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SectionHeader(title: l10n.libReturnedSection),
          for (final l in returned) _LoanCard(loan: l),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(l10n.libReturnAtDesk, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan});
  final LibraryLoan loan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        onTap: () => showLibraryLoanDetails(context, loan),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: AppColors.royalBlue),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loan.bookTitle, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    loan.isOpen
                        ? '${l10n.libBorrowedOn}: ${date.format(loan.issuedAt)}'
                        : '${l10n.libReturnedOn}: ${date.format(loan.returnedAt!)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  _DueChip(loan: loan),
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

class _DueChip extends StatelessWidget {
  const _DueChip({required this.loan});
  final LibraryLoan loan;

  @override
  Widget build(BuildContext context) {
    final state = loan.dueState();
    final color = libraryDueColor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == LibraryDueState.overdue || state == LibraryDueState.dueToday) ...[
            Icon(Icons.priority_high_rounded, size: 13, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            libraryDueLabel(context, loan),
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.onRetry});
  final String text;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(text, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

/// Book name, author, publisher, borrowed date, due date — and, while it is
/// still out and due soon or overdue, why it needs attention.
Future<void> showLibraryLoanDetails(BuildContext context, LibraryLoan loan) {
  final l10n = context.l10n;
  final theme = Theme.of(context);
  final date = DateFormat.yMMMd(Localizations.localeOf(context).toString());
  Widget row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 130, child: Text(label, style: theme.textTheme.bodySmall)),
            Expanded(child: Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
          ],
        ),
      );
  final state = loan.dueState();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(loan.bookTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: _DueChip(loan: loan)),
            const SizedBox(height: AppSpacing.md),
            row(l10n.libBookName, loan.bookTitle),
            row(l10n.libAuthor, loan.bookAuthor.isEmpty ? '—' : loan.bookAuthor),
            row(l10n.libPublisher, loan.bookPublisher.isEmpty ? '—' : loan.bookPublisher),
            row(l10n.libBorrowedOn, date.format(loan.issuedAt)),
            row(l10n.libDueDate, date.format(loan.dueDate)),
            if (loan.returnedAt != null) row(l10n.libReturnedOn, date.format(loan.returnedAt!)),
            if (loan.needsAttention())
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: libraryDueColor(state).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: libraryDueColor(state)),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        state == LibraryDueState.overdue ? l10n.libOverdueNote : l10n.libDueSoonNote,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
