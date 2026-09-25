import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../library_widgets.dart';

/// Add a book (name, author, publisher, count) or edit one's details.
/// Returns the book id once saved.
Future<String?> showBookForm(BuildContext context, {LibraryBook? book}) {
  return Navigator.of(context)
      .push<String>(MaterialPageRoute(builder: (_) => _BookForm(book: book), fullscreenDialog: true));
}

class _BookForm extends StatefulWidget {
  final LibraryBook? book;
  const _BookForm({this.book});

  @override
  State<_BookForm> createState() => _BookFormState();
}

class _BookFormState extends State<_BookForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.book?.title ?? '');
  late final _author = TextEditingController(text: widget.book?.author ?? '');
  late final _publisher = TextEditingController(text: widget.book?.publisher ?? '');
  final _count = TextEditingController(text: '1');
  bool _saving = false;

  bool get _editing => widget.book != null;

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _publisher.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = context.read<LibraryRepository>();
    try {
      String id;
      if (_editing) {
        id = widget.book!.id;
        await repo.updateBook(
          id,
          title: _title.text.trim(),
          author: _author.text.trim(),
          publisher: _publisher.text.trim(),
        );
      } else {
        id = await repo.createBook(
          title: _title.text.trim(),
          author: _author.text.trim(),
          publisher: _publisher.text.trim(),
          count: int.parse(_count.text),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showLibraryError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit book' : 'Add book')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _field(_title, 'Book name', Icons.menu_book_rounded, required: true),
              _field(_author, 'Author', Icons.person_outline_rounded),
              _field(_publisher, 'Publisher', Icons.apartment_rounded),
              if (!_editing)
                _field(
                  _count,
                  'Book count',
                  Icons.library_books_outlined,
                  keyboard: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  helper: 'How many copies of this book the library has.',
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1) return 'At least 1 copy';
                    if (n > 1000) return 'At most 1000 at a time';
                    return null;
                  },
                ),
              if (!_editing)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 18),
                  child: Text(
                    'New copies start as Unassigned. Place them on a shelf from the book, '
                    'or from any partition in Section management.',
                    style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5),
                  ),
                ),
              const SizedBox(height: 8),
              SoftPrimaryButton(
                label: _saving ? 'Saving…' : (_editing ? 'Save changes' : 'Add to library'),
                icon: Icons.check_rounded,
                gold: true,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? helper,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        inputFormatters: formatters,
        textCapitalization: keyboard == null ? TextCapitalization.words : TextCapitalization.none,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), helperText: helper),
        validator:
            validator ??
            (required ? (v) => (v == null || v.trim().isEmpty) ? 'Enter the ${label.toLowerCase()}' : null : null),
      ),
    );
  }
}

/// Adds more copies of a book already in the library.
Future<void> addCopiesFlow(BuildContext context, LibraryBook book) async {
  final repo = context.read<LibraryRepository>();
  final c = TextEditingController(text: '1');
  final n = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add copies'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('"${book.title}" has ${book.totalCopies} copies. How many more arrived?'),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'New copies'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final v = int.tryParse(c.text) ?? 0;
            if (v >= 1 && v <= 1000) Navigator.pop(ctx, v);
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
  // Not disposed here: the dialog is still animating out and reads it.
  if (n == null || !context.mounted) return;
  await runLibraryAction(
    context,
    () => repo.addCopies(book.id, n),
    done: 'Added $n unassigned cop${n == 1 ? 'y' : 'ies'}',
  );
}
