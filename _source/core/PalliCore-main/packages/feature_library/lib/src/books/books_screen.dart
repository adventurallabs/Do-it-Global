import 'package:flutter/material.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../library_widgets.dart';
import 'book_detail_screen.dart';
import 'book_form.dart';
import 'delete_flow.dart';

enum _Filter { all, unassigned, shelved, issued }

/// Book management: every title with its copy breakdown, search, add, and
/// multi-select delete. With [pickFor] set it becomes a picker that returns
/// the tapped book instead of opening it.
class BooksScreen extends StatefulWidget {
  /// Title of the picker, e.g. 'Choose a book to place'. Null = manage.
  final String? pickFor;

  /// In pick mode, which books can be chosen, and why the others can't.
  final bool Function(LibraryBook)? pickable;
  final String? unpickableHint;

  /// Opens filtered to books with copies waiting to be shelved.
  final bool startWithUnassigned;

  const BooksScreen({super.key, this.pickFor, this.pickable, this.unpickableHint, this.startWithUnassigned = false});

  /// Opens the list as a picker.
  static Future<LibraryBook?> pick(
    BuildContext context, {
    required String title,
    required bool Function(LibraryBook) pickable,
    required String unpickableHint,
  }) {
    return Navigator.of(context).push<LibraryBook>(
      MaterialPageRoute(
        builder: (_) => BooksScreen(pickFor: title, pickable: pickable, unpickableHint: unpickableHint),
      ),
    );
  }

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> with LibraryLive {
  List<LibraryBook> _books = const [];
  bool _loading = true;
  Object? _error;
  String _query = '';
  late _Filter _filter = widget.startWithUnassigned ? _Filter.unassigned : _Filter.all;
  final Set<String> _selected = {};
  bool _selectMode = false;

  bool get _picking => widget.pickFor != null;
  bool get _selecting => _selectMode || _selected.isNotEmpty;

  void _endSelection() => setState(() {
    _selected.clear();
    _selectMode = false;
  });

  @override
  Future<void> reload() async {
    try {
      final books = await library.books();
      if (!mounted) return;
      setState(() {
        _books = books;
        // A book deleted elsewhere can't stay selected.
        _selected.retainWhere((id) => books.any((b) => b.id == id));
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

  List<LibraryBook> get _visible {
    final q = _query.trim().toLowerCase();
    return _books.where((b) {
      final matches =
          q.isEmpty ||
          b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q) ||
          b.publisher.toLowerCase().contains(q);
      if (!matches) return false;
      switch (_filter) {
        case _Filter.all:
          return true;
        case _Filter.unassigned:
          return b.unassignedCopies > 0;
        case _Filter.shelved:
          return b.shelvedCopies > 0;
        case _Filter.issued:
          return b.issuedCopies > 0;
      }
    }).toList();
  }

  void _toggle(LibraryBook b) => setState(() {
    if (!_selected.remove(b.id)) _selected.add(b.id);
  });

  Future<void> _open(LibraryBook b) async {
    if (_selecting) return _toggle(b);
    if (_picking) {
      if (widget.pickable?.call(b) ?? true) {
        Navigator.pop(context, b);
      } else {
        showLibraryDone(context, widget.unpickableHint ?? 'That book can’t be chosen here.');
      }
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: b.id)));
  }

  Future<void> _add() async {
    final id = await showBookForm(context);
    if (id != null && mounted) {
      showLibraryDone(context, 'Book added to the library');
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: id)));
    }
  }

  Future<void> _deleteSelected() async {
    final books = _books.where((b) => _selected.contains(b.id)).toList();
    final done = await deleteCopiesFlow(context, books);
    if (done && mounted) _endSelection();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endSelection();
      },
      child: Scaffold(
        appBar: _selecting
            ? AppBar(
                leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _endSelection),
                title: Text('${_selected.length} selected'),
                actions: [
                  IconButton(
                    tooltip: 'Select all shown',
                    icon: const Icon(Icons.select_all_rounded),
                    onPressed: () => setState(() => _selected.addAll(visible.map((b) => b.id))),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    onPressed: _selected.isEmpty ? null : _deleteSelected,
                  ),
                ],
              )
            : AppBar(
                title: Text(widget.pickFor ?? 'Book management'),
                actions: [
                  if (!_picking && _books.isNotEmpty)
                    IconButton(
                      tooltip: 'Select books to delete',
                      icon: const Icon(Icons.checklist_rounded),
                      onPressed: () => setState(() => _selectMode = true),
                    ),
                ],
              ),
        floatingActionButton: _picking || _selecting
            ? null
            : FloatingActionButton.extended(
                shape: const StadiumBorder(),
                onPressed: _add,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add book'),
              ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? LibraryLoadError(error: _error!, onRetry: refreshLibrary)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          hintText: 'Search by name, author or publisher',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    if (!_picking) _filters(),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.accent,
                        onRefresh: refreshLibrary,
                        child: visible.isEmpty
                            ? ListView(
                                children: [
                                  SizedBox(
                                    height: 360,
                                    child: EmptyState(
                                      icon: Icons.menu_book_rounded,
                                      title: _books.isEmpty ? 'No books yet' : 'No matching books',
                                      subtitle: _books.isEmpty
                                          ? 'Add the first book with its name, author, publisher and count.'
                                          : 'Try another search or filter.',
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
                                itemCount: visible.length,
                                itemBuilder: (context, i) => _tile(visible[i]),
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _filters() {
    int count(_Filter f) => _books.where((b) {
      switch (f) {
        case _Filter.all:
          return true;
        case _Filter.unassigned:
          return b.unassignedCopies > 0;
        case _Filter.shelved:
          return b.shelvedCopies > 0;
        case _Filter.issued:
          return b.issuedCopies > 0;
      }
    }).length;
    const labels = {
      _Filter.all: 'All',
      _Filter.unassigned: 'Unassigned',
      _Filter.shelved: 'On shelves',
      _Filter.issued: 'Issued',
    };
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final f in _Filter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${labels[f]} · ${count(f)}'),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(LibraryBook b) {
    final selected = _selected.contains(b.id);
    final enabled = !_picking || (widget.pickable?.call(b) ?? true);
    final byline = [b.author, b.publisher].where((s) => s.isNotEmpty).join(' · ');
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: SoftSurface(
        depth: SoftDepth.one,
        borderRadius: BorderRadius.circular(18),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        onTap: () => _open(b),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPress: _picking ? null : () => _toggle(b),
          child: Row(
            children: [
              if (_selecting)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Checkbox(value: selected, onChanged: (_) => _toggle(b)),
                ),
              BookSpine(title: b.title),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    if (byline.isNotEmpty)
                      Text(
                        byline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _pill('${b.totalCopies} total', AppColors.onSurfaceMuted(context)),
                        if (b.shelvedCopies > 0) _pill('${b.shelvedCopies} on shelves', LibraryColors.shelved),
                        if (b.unassignedCopies > 0) _pill('${b.unassignedCopies} unassigned', LibraryColors.unassigned),
                        if (b.issuedCopies > 0) _pill('${b.issuedCopies} issued', LibraryColors.issued),
                      ],
                    ),
                  ],
                ),
              ),
              if (!_selecting) Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
    ),
  );
}
