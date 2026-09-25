import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../books/books_screen.dart';
import '../library_widgets.dart';
import 'rack_grid.dart';
import 'section_detail_screen.dart';
import 'shelf_actions.dart';

/// A rack drawn shelf by shelf. Tap a partition to see what it holds, put a
/// book in it, or move and remove books from it.
class RackScreen extends StatefulWidget {
  final String rackId;
  const RackScreen({super.key, required this.rackId});

  @override
  State<RackScreen> createState() => _RackScreenState();
}

class _RackScreenState extends State<RackScreen> with LibraryLive {
  LibraryRack? _rack;
  List<LibrarySlotBooks> _contents = const [];
  bool _loading = true;
  bool _gone = false;
  Object? _error;

  @override
  Future<void> reload() async {
    try {
      final results = await Future.wait([library.rack(widget.rackId), library.slotBooks(rackId: widget.rackId)]);
      if (!mounted) return;
      setState(() {
        _rack = results[0] as LibraryRack?;
        _gone = _rack == null;
        _contents = results[1] as List<LibrarySlotBooks>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _resize() async {
    final rack = _rack;
    if (rack == null) return;
    final size = await showRackSizeDialog(
      context,
      title: 'Resize rack ${rack.code}',
      shelves: rack.shelfCount,
      partitions: rack.partitionsPerShelf,
      action: 'Save',
    );
    if (size == null || !mounted) return;
    await runLibraryAction(
      context,
      () => library.resizeRack(rack.id, shelves: size.shelves, partitions: size.partitions),
      done: 'Rack ${rack.code} resized',
    );
  }

  Future<void> _delete() async {
    final rack = _rack;
    if (rack == null) return;
    final books = _contents.fold<int>(0, (a, b) => a + b.copies);
    final ok = await confirmTypedDelete(
      context,
      title: 'Delete rack ${rack.code}',
      message: books == 0
          ? 'The rack is empty.'
          : 'The $books book${books == 1 ? '' : 's'} on it stay in the library as Unassigned.',
    );
    if (!ok || !mounted) return;
    final repo = context.read<LibraryRepository>();
    try {
      await repo.deleteRack(rack.id);
      if (!mounted) return;
      showLibraryDone(context, 'Rack ${rack.code} deleted');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showLibraryError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rack = _rack;
    final total = _contents.fold<int>(0, (a, b) => a + b.copies);
    return Scaffold(
      appBar: AppBar(
        title: Text(rack == null ? 'Rack' : 'Rack ${rack.code}'),
        actions: [
          if (rack != null)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'resize' ? _resize() : _delete(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'resize',
                  child: ListTile(
                    leading: Icon(Icons.aspect_ratio_rounded),
                    title: Text('Change shelves / partitions'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    title: Text('Delete rack'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? LibraryLoadError(error: _error!, onRetry: refreshLibrary)
            : _gone
            ? const EmptyState(icon: Icons.view_week_rounded, title: 'This rack was deleted')
            : RefreshIndicator(
                color: AppColors.accent,
                onRefresh: refreshLibrary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Text(
                      '${rack!.shelfCount} shelves · ${rack.partitionsPerShelf} partitions each · '
                      '$total book${total == 1 ? '' : 's'}',
                      style: TextStyle(color: AppColors.onSurfaceMuted(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap a partition to place, move or remove books.',
                      style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12.5),
                    ),
                    const SizedBox(height: 16),
                    RackGrid(rack: rack, contents: groupBySlot(_contents), onTap: (slot) => _openPartition(slot)),
                  ],
                ),
              ),
      ),
    );
  }

  void _openPartition(LibrarySlot slot) {
    final here = _contents.where((c) => c.slot.sameAs(slot)).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => _PartitionSheet(slot: slot, books: here, hostContext: context),
    );
  }
}

class _PartitionSheet extends StatelessWidget {
  final LibrarySlot slot;
  final List<LibrarySlotBooks> books;

  /// The rack screen's context: the sheet closes before an action starts,
  /// so pickers and dialogs must hang off the screen, not the sheet.
  final BuildContext hostContext;

  const _PartitionSheet({required this.slot, required this.books, required this.hostContext});

  Future<void> _place(BuildContext sheet) async {
    final repo = hostContext.read<LibraryRepository>();
    Navigator.pop(sheet);
    final book = await BooksScreen.pick(
      hostContext,
      title: 'Choose a book for ${slot.label}',
      pickable: (b) => b.unassignedCopies > 0,
      unpickableHint: 'Only unassigned copies can be placed. Relocate a shelved copy from its partition instead.',
    );
    if (book == null || !hostContext.mounted) return;
    await placeInPartition(
      hostContext,
      repo: repo,
      bookId: book.id,
      title: book.title,
      unassigned: book.unassignedCopies,
      to: slot,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = books.fold<int>(0, (a, b) => a + b.copies);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(slot.label, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            Text(
              total == 0
                  ? 'Empty partition'
                  : '$total book${total == 1 ? '' : 's'} · ${books.length} title${books.length == 1 ? '' : 's'}',
              style: TextStyle(color: AppColors.onSurfaceMuted(context)),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final b in books)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          BookSpine(title: b.title, size: 38),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  '${b.copies} cop${b.copies == 1 ? 'y' : 'ies'}',
                                  style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Relocate',
                            icon: const Icon(Icons.open_with_rounded),
                            onPressed: () {
                              Navigator.pop(context);
                              relocateCopies(hostContext, bookId: b.bookId, title: b.title, from: slot, here: b.copies);
                            },
                          ),
                          IconButton(
                            tooltip: 'Remove from partition',
                            icon: const Icon(Icons.remove_circle_outline_rounded),
                            onPressed: () {
                              Navigator.pop(context);
                              removeFromPartition(
                                hostContext,
                                bookId: b.bookId,
                                title: b.title,
                                from: slot,
                                here: b.copies,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SoftPrimaryButton(
              label: total == 0 ? 'Place a book here' : 'Place another book here',
              icon: Icons.add_rounded,
              gold: true,
              onPressed: () => _place(context),
            ),
          ],
        ),
      ),
    );
  }
}
