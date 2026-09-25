import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../library_widgets.dart';

class LoanTile extends StatelessWidget {
  final LibraryLoan loan;
  final VoidCallback? onTap;

  /// Borrower's name under the title (librarian lists) or not (a
  /// borrower's own list, where it is always them).
  final bool showBorrower;

  const LoanTile({super.key, required this.loan, this.onTap, this.showBorrower = true});

  @override
  Widget build(BuildContext context) {
    final who = [loan.borrowerName, loan.borrowerDetail].where((s) => s.isNotEmpty).join(' · ');
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: onTap,
      child: Row(
        children: [
          BookSpine(title: loan.bookTitle, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loan.bookTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (showBorrower && who.isNotEmpty)
                  Text(who, style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      loan.isOpen
                          ? 'Borrowed ${libraryDate.format(loan.issuedAt)}'
                          : 'Returned ${libraryDate.format(loan.returnedAt!)}',
                      style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 11.5),
                    ),
                    DueChip(loan: loan),
                    BorrowerStatusChip(loan: loan),
                  ],
                ),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
        ],
      ),
    );
  }
}

/// A loan's full details. [librarian] adds the collect-back and new-due-date
/// actions; a borrower only reads.
Future<void> showLoanDetails(BuildContext context, LibraryLoan loan, {bool librarian = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BookSpine(title: loan.bookTitle, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loan.bookTitle, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          DueChip(loan: loan),
                          BorrowerStatusChip(loan: loan),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DetailRow('Book name', loan.bookTitle),
            _DetailRow('Author', loan.bookAuthor.isEmpty ? '—' : loan.bookAuthor),
            _DetailRow('Publisher', loan.bookPublisher.isEmpty ? '—' : loan.bookPublisher),
            const Divider(height: 24),
            _DetailRow(loan.isStudent ? 'Student' : 'Staff', loan.borrowerName),
            if (loan.isStudent) ...[
              _DetailRow('Class', [loan.className, loan.section].where((s) => s.isNotEmpty).join(' ')),
              _DetailRow('Roll number', loan.rollNumber.isEmpty ? '—' : loan.rollNumber),
            ] else
              _DetailRow('Contact', loan.contactNumber),
            const Divider(height: 24),
            _DetailRow('Borrowed on', libraryDate.format(loan.issuedAt)),
            _DetailRow('Due date', libraryDate.format(loan.dueDate)),
            if (!loan.isOpen) _DetailRow('Returned on', libraryDate.format(loan.returnedAt!)),
            if (loan.isOpen && loan.needsAttention())
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DueChip.colorFor(loan.dueState()).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: DueChip.colorFor(loan.dueState())),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loan.dueState() == LoanDueState.overdue
                            ? 'Attention required — this book is past its due date.'
                            : 'Attention required — this book is due back soon.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            if (librarian && loan.isOpen) ...[
              const SizedBox(height: 20),
              SoftPrimaryButton(
                label: 'Get the book back',
                icon: Icons.assignment_return_rounded,
                gold: true,
                onPressed: () async {
                  final ok = await collectBack(sheetContext, loan);
                  if (ok && sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final ok = await extendDueDate(sheetContext, loan);
                  if (ok && sheetContext.mounted) Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.event_repeat_rounded),
                label: const Text('Change due date'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// "Are you sure the book was collected back?" — No does nothing at all;
/// Yes returns the copy to the unassigned pile.
Future<bool> collectBack(BuildContext context, LibraryLoan loan) async {
  final repo = context.read<LibraryRepository>();
  final ok = await confirmYesNo(
    context,
    title: 'Collect this book?',
    message: 'Are you sure "${loan.bookTitle}" was collected back from ${loan.borrowerName}?',
  );
  if (!ok || !context.mounted) return false;
  return runLibraryAction(
    context,
    () => repo.returnLoan(loan.id),
    done: '"${loan.bookTitle}" is back — it’s in Unassigned, ready to shelve',
  );
}

Future<bool> extendDueDate(BuildContext context, LibraryLoan loan) async {
  final repo = context.read<LibraryRepository>();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final picked = await showDatePicker(
    context: context,
    initialDate: loan.dueDate.isBefore(today) ? today.add(const Duration(days: 7)) : loan.dueDate,
    firstDate: today,
    lastDate: today.add(const Duration(days: 365)),
    helpText: 'New due date',
  );
  if (picked == null || !context.mounted) return false;
  return runLibraryAction(
    context,
    () => repo.extendDue(loan.id, picked),
    done: 'Due date moved to ${libraryDate.format(picked)}',
  );
}
