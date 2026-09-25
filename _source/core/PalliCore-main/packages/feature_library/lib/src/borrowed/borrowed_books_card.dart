import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../library_widgets.dart';
import 'borrowed_books_screen.dart';

/// "Books borrowed" on a staff member's home. Draws nothing until they have
/// borrowed their first library book; from then on it stays, showing what
/// they hold now and flagging anything due soon or overdue.
class BorrowedBooksCard extends StatefulWidget {
  final String teacherId;

  /// Changes whenever the dashboard reloads, so the card re-reads with it.
  final Object? refreshToken;

  const BorrowedBooksCard({super.key, required this.teacherId, this.refreshToken});

  @override
  State<BorrowedBooksCard> createState() => _BorrowedBooksCardState();
}

class _BorrowedBooksCardState extends State<BorrowedBooksCard> {
  List<LibraryLoan> _loans = const [];
  bool _loaded = false;
  StreamSubscription<void>? _sub;

  /// Realtime can start several loads at once; only the newest may paint.
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _load();
  }

  @override
  void didUpdateWidget(BorrowedBooksCard old) {
    super.didUpdateWidget(old);
    // A second sign-in on the same phone can reuse this State.
    if (old.teacherId != widget.teacherId) {
      _loans = const [];
      _loaded = false;
      _subscribe();
      _load();
    } else if (old.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  void _subscribe() {
    _sub?.cancel();
    if (widget.teacherId.isEmpty) return;
    _sub = context
        .read<LibraryRepository>()
        .watchTeacherLoans(widget.teacherId)
        .listen((_) => _load(), onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    if (widget.teacherId.isEmpty) return;
    final id = widget.teacherId;
    try {
      final loans = await context.read<LibraryRepository>().loansForTeacher(id);
      if (mounted && id == widget.teacherId && seq == _loadSeq) {
        setState(() {
          _loans = loans;
          _loaded = true;
        });
      }
    } catch (_) {
      // Leave whatever was shown; a failed read must not hide the card of
      // someone who is holding books.
      if (mounted && seq == _loadSeq) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _loans.isEmpty) return const SizedBox.shrink();
    final open = _loans.where((l) => l.isOpen).toList();
    final attention = open.where((l) => l.needsAttention()).toList();
    final overdue = attention.any((l) => l.dueState() == LoanDueState.overdue);
    final alert = overdue ? AppColors.error : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftSurface(
        depth: SoftDepth.one,
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        onTap: () => BorrowedBooksScreen.open(context, teacherId: widget.teacherId),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LibraryColors.books.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.local_library_rounded, color: LibraryColors.books, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Books borrowed', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    open.isEmpty
                        ? 'All returned — nothing with you now'
                        : '${open.length} with you · ${open.map((l) => l.bookTitle).join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, height: 1.3, color: AppColors.onSurfaceMuted(context)),
                  ),
                  if (attention.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 15, color: alert),
                        const SizedBox(width: 4),
                        Text(
                          overdue ? 'Attention required · overdue' : 'Attention required · due soon',
                          style: TextStyle(color: alert, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
          ],
        ),
      ),
    );
  }
}
