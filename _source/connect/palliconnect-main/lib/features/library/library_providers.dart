import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_provider.dart';
import '../../core/data/parent_repository.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/localization/l10n_ext.dart';
import '../../shared/models/library_loan.dart';
import '../parent/parent_store.dart';

/// Every library loan of the current child. Re-read when the child changes
/// and whenever realtime reports a loan issued, returned or re-dated.
final libraryLoansProvider = FutureProvider<List<LibraryLoan>>((ref) async {
  final student = ref.watch(currentStudentProvider);
  ref.watch(libraryTickProvider);
  if (student == null) return const [];
  return ref.read(parentRepositoryProvider).libraryLoans(student.id);
});

Color libraryDueColor(LibraryDueState s) {
  switch (s) {
    case LibraryDueState.overdue:
      return AppColors.error;
    case LibraryDueState.dueToday:
    case LibraryDueState.dueSoon:
      return AppColors.warning;
    case LibraryDueState.onTime:
      return AppColors.success;
    case LibraryDueState.returned:
      return AppColors.grey500;
  }
}

String libraryDueLabel(BuildContext context, LibraryLoan loan) {
  final l10n = context.l10n;
  final d = loan.daysLeft();
  switch (loan.dueState()) {
    case LibraryDueState.returned:
      return l10n.libReturnedChip;
    case LibraryDueState.overdue:
      return l10n.libOverdueBy(-d);
    case LibraryDueState.dueToday:
      return l10n.libDueToday;
    case LibraryDueState.dueSoon:
      return d == 1 ? l10n.libDueTomorrow : l10n.libDueIn(d);
    case LibraryDueState.onTime:
      return l10n.libDueIn(d);
  }
}
