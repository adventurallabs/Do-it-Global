import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../library_widgets.dart';

/// Deletes copies of one or more books.
///
/// 1. Choose how many copies of each (issued copies can't be deleted — they
///    are out with someone).
/// 2. The database plans it without changing anything (a dry run), so what
///    the librarian confirms is exactly what will happen.
/// 3. One book: type DELETE. Several: "Are you sure?", then type DELETE.
/// 4. It runs as one transaction and reports which partitions to empty.
///
/// Returns true once something was deleted.
Future<bool> deleteCopiesFlow(BuildContext context, List<LibraryBook> books) async {
  final repo = context.read<LibraryRepository>();
  final deletable = books.where((b) => b.inLibrary > 0).toList();
  if (deletable.isEmpty) {
    showLibraryDone(context, 'Every copy is issued right now — collect them back before deleting.');
    return false;
  }
  final counts = await Navigator.of(context)
      .push<Map<String, int>>(MaterialPageRoute(builder: (_) => _ChooseCounts(books: books), fullscreenDialog: true));
  if (counts == null || counts.isEmpty || !context.mounted) return false;
  // Two-step confirmation whenever more than one book is really affected.
  final bulk = counts.length > 1;

  List<LibraryRemoval> plan;
  try {
    plan = await repo.removeCopies(counts, dryRun: true);
  } catch (e) {
    if (context.mounted) showLibraryError(context, e);
    return false;
  }
  if (!context.mounted) return false;

  final summary = plan.map(_planLine).join('\n\n');
  final totalCopies = plan.fold<int>(0, (s, p) => s + p.removed);

  if (bulk) {
    final sure = await confirmYesNo(
      context,
      title: 'Are you sure?',
      message:
          'You are deleting $totalCopies cop${totalCopies == 1 ? 'y' : 'ies'} '
          'across ${plan.length} books:\n\n$summary',
      yes: 'Yes, continue',
      no: 'No',
      destructive: true,
    );
    if (!sure || !context.mounted) return false;
  }

  final typed = await confirmTypedDelete(
    context,
    title: bulk ? 'Delete ${plan.length} books' : 'Delete copies',
    message: bulk ? 'This removes $totalCopies copies from the library for good.' : summary,
  );
  if (!typed || !context.mounted) return false;

  try {
    final done = await repo.removeCopies(counts);
    if (context.mounted) await _showPullList(context, done);
    return true;
  } catch (e) {
    if (context.mounted) showLibraryError(context, e);
    return false;
  }
}

String _planLine(LibraryRemoval p) {
  final parts = <String>[
    if (p.fromUnassigned > 0) '${p.fromUnassigned} unassigned',
    for (final s in p.fromPartitions) '${s.copies} from ${s.rackCode} · Shelf ${s.shelfNo} · P${s.partitionNo}',
  ];
  final tail = p.bookRemoved ? 'No copies left — the book leaves the library.' : '${p.copiesLeft} left.';
  return '"${p.title}": ${p.removed} cop${p.removed == 1 ? 'y' : 'ies'} (${parts.join(', ')}). $tail';
}

Future<void> _showPullList(BuildContext context, List<LibraryRemoval> done) {
  final pulls = [
    for (final p in done)
      for (final s in p.fromPartitions)
        '${s.rackCode} · Shelf ${s.shelfNo} · P${s.partitionNo} — ${s.copies} × ${p.title}',
  ];
  final removedBooks = done.where((p) => p.bookRemoved).length;
  final total = done.fold<int>(0, (s, p) => s + p.removed);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
      title: Text('Deleted $total cop${total == 1 ? 'y' : 'ies'}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (removedBooks > 0)
              Text(
                '$removedBooks book${removedBooks == 1 ? '' : 's'} had no copies left and '
                '${removedBooks == 1 ? 'was' : 'were'} removed from the library.',
              ),
            if (pulls.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Take these off the shelves:', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final line in pulls) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $line')),
            ],
          ],
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
    ),
  );
}

class _ChooseCounts extends StatefulWidget {
  final List<LibraryBook> books;
  const _ChooseCounts({required this.books});

  @override
  State<_ChooseCounts> createState() => _ChooseCountsState();
}

class _ChooseCountsState extends State<_ChooseCounts> {
  late final Map<String, int> _counts = {
    for (final b in widget.books)
      // Start at one copy: deleting everything must be a choice, not the default.
      if (b.inLibrary > 0) b.id: 1,
  };

  @override
  Widget build(BuildContext context) {
    final total = _counts.values.fold<int>(0, (s, n) => s + n);
    return Scaffold(
      appBar: AppBar(title: Text(widget.books.length == 1 ? 'Delete copies' : 'Delete ${widget.books.length} books')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Text(
                    'Choose how many copies of each book to delete. Unassigned copies go first, '
                    'then shelved ones. Issued copies stay until they are collected back.',
                    style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  for (final b in widget.books) _row(b),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SoftPrimaryButton(
                label: total == 0 ? 'Nothing to delete' : 'Review deleting $total cop${total == 1 ? 'y' : 'ies'}',
                icon: Icons.delete_outline_rounded,
                onPressed: total == 0 ? null : () => Navigator.pop(context, Map<String, int>.from(_counts)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(LibraryBook b) {
    final n = _counts[b.id];
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BookSpine(title: b.title, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(
                      '${b.totalCopies} copies · ${b.inLibrary} in library'
                      '${b.issuedCopies > 0 ? ' · ${b.issuedCopies} issued' : ''}',
                      style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (n == null)
            Text(
              'All copies are issued — nothing can be deleted until they come back.',
              style: TextStyle(color: AppColors.warning, fontSize: 12.5, fontWeight: FontWeight.w600),
            )
          else ...[
            CopyStepper(value: n, max: b.inLibrary, onChanged: (v) => setState(() => _counts[b.id] = v)),
            Align(
              child: TextButton(
                onPressed: n == b.inLibrary ? null : () => setState(() => _counts[b.id] = b.inLibrary),
                child: Text('All ${b.inLibrary} in the library'),
              ),
            ),
            Align(
              child: Text(
                n == b.totalCopies ? 'Every copy — the book leaves the library' : '${b.totalCopies - n} will remain',
                style: TextStyle(
                  fontSize: 12,
                  color: n == b.totalCopies ? AppColors.error : AppColors.onSurfaceMuted(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
