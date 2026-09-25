import 'package:flutter/material.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../lending/loan_widgets.dart';
import '../library_widgets.dart';
import '../shelves/shelf_actions.dart';
import 'book_form.dart';
import 'delete_flow.dart';

/// One book: its details, where every copy is, and who has it.
class BookDetailScreen extends StatefulWidget {
  final String bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> with LibraryLive {
  LibraryBook? _book;
  List<LibrarySlotBooks> _slots = const [];
  List<LibraryLoan> _loans = const [];
  bool _loading = true;
  bool _gone = false;
  Object? _error;

  @override
  Future<void> reload() async {
    try {
      final results = await Future.wait([
        library.book(widget.bookId),
        library.slotBooks(bookId: widget.bookId),
        library.openLoans(bookId: widget.bookId),
      ]);
      if (!mounted) return;
      setState(() {
        _book = results[0] as LibraryBook?;
        _gone = _book == null;
        _slots = results[1] as List<LibrarySlotBooks>;
        _loans = results[2] as List<LibraryLoan>;
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

  Future<void> _delete() async {
    final book = _book;
    if (book == null) return;
    final done = await deleteCopiesFlow(context, [book]);
    if (!done || !mounted) return;
    // If that was the last copy the book is gone — nothing left to show.
    final still = await library.book(book.id);
    if (still == null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book details'),
        actions: [
          if (book != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'edit':
                    await showBookForm(context, book: book);
                  case 'add':
                    await addCopiesFlow(context, book);
                  case 'delete':
                    await _delete();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit details')),
                ),
                PopupMenuItem(
                  value: 'add',
                  child: ListTile(leading: Icon(Icons.add_rounded), title: Text('Add copies')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    title: Text('Delete copies'),
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
            ? const EmptyState(
                icon: Icons.menu_book_rounded,
                title: 'This book is no longer in the library',
                subtitle: 'All of its copies were deleted.',
              )
            : RefreshIndicator(color: AppColors.accent, onRefresh: refreshLibrary, child: _body(book!)),
      ),
    );
  }

  Widget _body(LibraryBook b) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        SoftSurface(
          depth: SoftDepth.two,
          borderRadius: BorderRadius.circular(22),
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookSpine(title: b.title, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: 6),
                    _meta(Icons.person_outline_rounded, b.author.isEmpty ? 'Author not set' : b.author),
                    _meta(Icons.apartment_rounded, b.publisher.isEmpty ? 'Publisher not set' : b.publisher),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CountGrid(
          tiles: [
            CountTile(
              label: 'Total copies',
              value: b.totalCopies,
              color: LibraryColors.books,
              icon: Icons.library_books_rounded,
            ),
            CountTile(label: 'On shelves', value: b.shelvedCopies, color: LibraryColors.shelved, icon: Icons.shelves),
            CountTile(
              label: 'Unassigned',
              value: b.unassignedCopies,
              color: LibraryColors.unassigned,
              icon: Icons.inventory_2_outlined,
            ),
            CountTile(label: 'Issued', value: b.issuedCopies, color: LibraryColors.issued, icon: Icons.outbox_rounded),
            CountTile(
              label: 'With students',
              value: b.issuedToStudents,
              color: LibraryColors.issue,
              icon: Icons.school_outlined,
            ),
            CountTile(
              label: 'With staff',
              value: b.issuedToStaff,
              color: LibraryColors.collect,
              icon: Icons.badge_outlined,
            ),
          ],
        ),
        SectionLabel('Unassigned'),
        SoftSurface(
          depth: SoftDepth.one,
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: LibraryColors.unassigned),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  b.unassignedCopies == 0
                      ? 'Every copy in the library is on a shelf.'
                      : '${b.unassignedCopies} cop${b.unassignedCopies == 1 ? 'y is' : 'ies are'} not on any shelf yet.',
                ),
              ),
              if (b.unassignedCopies > 0)
                FilledButton.tonal(
                  onPressed: () =>
                      assignToPartition(context, bookId: b.id, title: b.title, unassigned: b.unassignedCopies),
                  child: const Text('Assign'),
                ),
            ],
          ),
        ),
        SectionLabel('On shelves'),
        if (_slots.isEmpty) _hint('No copies are on a shelf.') else for (final s in _slots) _slotTile(b, s),
        SectionLabel('Borrowed now'),
        if (_loans.isEmpty)
          _hint('Nobody has this book right now.')
        else
          for (final l in _loans) LoanTile(loan: l, onTap: () => showLoanDetails(context, l, librarian: true)),
      ],
    );
  }

  Widget _meta(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      children: [
        Icon(icon, size: 15, color: AppColors.onSurfaceHint(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13)),
        ),
      ],
    ),
  );

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
    child: Text(text, style: TextStyle(color: AppColors.onSurfaceHint(context))),
  );

  Widget _slotTile(LibraryBook b, LibrarySlotBooks s) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          const Icon(Icons.shelves, color: LibraryColors.shelved),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Section ${s.sectionCode} · ${s.slot.label}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '${s.copies} cop${s.copies == 1 ? 'y' : 'ies'}',
                  style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'move') {
                relocateCopies(context, bookId: b.id, title: b.title, from: s.slot, here: s.copies);
              } else {
                removeFromPartition(context, bookId: b.id, title: b.title, from: s.slot, here: s.copies);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'move',
                child: ListTile(leading: Icon(Icons.open_with_rounded), title: Text('Relocate')),
              ),
              PopupMenuItem(
                value: 'remove',
                child: ListTile(
                  leading: Icon(Icons.remove_circle_outline_rounded),
                  title: Text('Remove from partition'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
