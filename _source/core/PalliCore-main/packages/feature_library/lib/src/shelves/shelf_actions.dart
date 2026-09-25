import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';

import '../library_widgets.dart';
import 'location_picker.dart';

/// Puts unassigned copies of a book into a partition the librarian picks.
Future<bool> assignToPartition(
  BuildContext context, {
  required String bookId,
  required String title,
  required int unassigned,
}) async {
  final repo = context.read<LibraryRepository>();
  if (unassigned <= 0) {
    showLibraryDone(context, 'Every copy of "$title" is already on a shelf or issued.');
    return false;
  }
  final to = await pickLibrarySlot(context, title: 'Place "$title"', highlightBookId: bookId);
  if (to == null || !context.mounted) return false;
  return placeInPartition(context, repo: repo, bookId: bookId, title: title, unassigned: unassigned, to: to);
}

/// The count step of placing, once the partition is known.
Future<bool> placeInPartition(
  BuildContext context, {
  required LibraryRepository repo,
  required String bookId,
  required String title,
  required int unassigned,
  required LibrarySlot to,
}) async {
  final n = await askCopyCount(
    context,
    title: 'How many copies?',
    message:
        '$unassigned unassigned cop${unassigned == 1 ? 'y' : 'ies'} of "$title". '
        'How many go into ${to.label}?',
    max: unassigned,
    initial: unassigned,
    action: 'Place',
  );
  if (n == null || !context.mounted) return false;
  return runLibraryAction(context, () => repo.place(bookId, to, count: n), done: 'Placed $n in ${to.label}');
}

/// Moves copies from one partition to any other — another partition on the
/// same shelf, another shelf, rack or section.
Future<bool> relocateCopies(
  BuildContext context, {
  required String bookId,
  required String title,
  required LibrarySlot from,
  required int here,
}) async {
  final repo = context.read<LibraryRepository>();
  final to = await pickLibrarySlot(context, title: 'Move "$title" to…', current: from, highlightBookId: bookId);
  if (to == null || !context.mounted) return false;
  final n = await askCopyCount(
    context,
    title: 'How many copies?',
    message:
        '${from.label} holds $here cop${here == 1 ? 'y' : 'ies'} of "$title". '
        'How many move to ${to.label}?',
    max: here,
    initial: here,
    action: 'Move',
  );
  if (n == null || !context.mounted) return false;
  return runLibraryAction(context, () => repo.move(bookId, from, to, count: n), done: 'Moved $n to ${to.label}');
}

/// Takes copies off a partition. They stay in the library, counted as
/// unassigned, until they are placed again.
Future<bool> removeFromPartition(
  BuildContext context, {
  required String bookId,
  required String title,
  required LibrarySlot from,
  required int here,
}) async {
  final repo = context.read<LibraryRepository>();
  final n = await askCopyCount(
    context,
    title: 'Remove from ${from.label}',
    message:
        'How many copies of "$title" come off this partition? '
        'They stay in the library as unassigned books.',
    max: here,
    initial: here,
    action: 'Remove',
  );
  if (n == null || !context.mounted) return false;
  if (here == 1) {
    final ok = await confirmYesNo(
      context,
      title: 'Remove from partition?',
      message: '"$title" will leave ${from.label} and wait in Unassigned until you place it again.',
      yes: 'Remove',
      no: 'Cancel',
    );
    if (!ok || !context.mounted) return false;
  }
  return runLibraryAction(context, () => repo.move(bookId, from, null, count: n), done: '$n moved to Unassigned');
}
