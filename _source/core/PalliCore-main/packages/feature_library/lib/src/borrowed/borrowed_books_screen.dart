import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../lending/loan_widgets.dart';
import '../library_widgets.dart';

/// A staff member's own library books: what they hold now, then what they
/// have returned. Read-only — returns happen at the library desk.
class BorrowedBooksScreen extends StatefulWidget {
  final String teacherId;
  const BorrowedBooksScreen({super.key, required this.teacherId});

  static Future<void> open(BuildContext context, {required String teacherId}) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => BorrowedBooksScreen(teacherId: teacherId)));

  @override
  State<BorrowedBooksScreen> createState() => _BorrowedBooksScreenState();
}

class _BorrowedBooksScreenState extends State<BorrowedBooksScreen> {
  List<LibraryLoan> _loans = const [];
  bool _loading = true;
  Object? _error;
  StreamSubscription<void>? _sub;

  /// Realtime can start several loads at once; only the newest may paint.
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _sub = context
        .read<LibraryRepository>()
        .watchTeacherLoans(widget.teacherId)
        .listen((_) => _load(), onError: (_) {});
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    try {
      final loans = await context.read<LibraryRepository>().loansForTeacher(widget.teacherId);
      if (mounted && seq == _loadSeq) {
        setState(() {
          _loans = loans;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && seq == _loadSeq) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = _loans.where((l) => l.isOpen).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final returned = _loans.where((l) => !l.isOpen).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Books borrowed')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? LibraryLoadError(error: _error!, onRetry: _load)
            : RefreshIndicator(
                color: AppColors.accent,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    SectionLabel('With you now'),
                    if (open.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                        child: Text(
                          'You have returned every library book.',
                          style: TextStyle(color: AppColors.onSurfaceHint(context)),
                        ),
                      )
                    else
                      for (final l in open)
                        LoanTile(loan: l, showBorrower: false, onTap: () => showLoanDetails(context, l)),
                    if (returned.isNotEmpty) ...[
                      SectionLabel('Returned'),
                      for (final l in returned)
                        LoanTile(loan: l, showBorrower: false, onTap: () => showLoanDetails(context, l)),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
