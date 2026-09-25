import 'package:flutter/material.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../library_widgets.dart';
import 'loan_widgets.dart';

/// "Get back a book": from staff, or from a student.
class ReturnHomeScreen extends StatefulWidget {
  const ReturnHomeScreen({super.key});

  @override
  State<ReturnHomeScreen> createState() => _ReturnHomeScreenState();
}

class _ReturnHomeScreenState extends State<ReturnHomeScreen> with LibraryLive {
  List<LibraryLoan> _open = const [];
  bool _loading = true;
  Object? _error;

  @override
  Future<void> reload() async {
    try {
      final open = await library.openLoans();
      if (mounted) {
        setState(() {
          _open = open;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget card(LibraryBorrowerKind kind) {
      final loans = _open.where((l) => l.borrowerKind == kind).toList();
      final late = loans.where((l) => l.dueState() == LoanDueState.overdue).length;
      final gone = loans.where((l) => l.borrowerGone).length;
      final people = loans.map(_personKey).toSet().length;
      final staff = kind == LibraryBorrowerKind.staff;
      return SoftSurface(
        depth: SoftDepth.two,
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BorrowersScreen(kind: kind))),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (staff ? LibraryColors.collect : LibraryColors.issue).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                staff ? Icons.badge_rounded : Icons.school_rounded,
                color: staff ? LibraryColors.collect : LibraryColors.issue,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff ? 'Get from staff' : 'Get from student',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    loans.isEmpty
                        ? 'No books out'
                        : '${loans.length} book${loans.length == 1 ? '' : 's'} with $people ${staff ? 'staff' : 'student${people == 1 ? '' : 's'}'}',
                    style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5),
                  ),
                  if (late > 0)
                    Text(
                      '$late overdue',
                      style: const TextStyle(color: AppColors.error, fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  if (gone > 0)
                    Text(
                      '$gone with someone who has left',
                      style: const TextStyle(color: AppColors.error, fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Get back a book')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? LibraryLoadError(error: _error!, onRetry: refreshLibrary)
            : RefreshIndicator(
                color: AppColors.accent,
                onRefresh: refreshLibrary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    card(LibraryBorrowerKind.staff),
                    const SizedBox(height: 12),
                    card(LibraryBorrowerKind.student),
                    const SizedBox(height: 16),
                    Text(
                      'A collected book goes to Unassigned, ready for you to place on any partition.',
                      style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// One person, however their name is spelt — by record id when there is
/// one, else by what the loan recorded.
String _personKey(LibraryLoan l) =>
    l.isStudent ? (l.studentId ?? 's:${l.borrowerName}|${l.rollNumber}') : (l.teacherId ?? 't:${l.contactNumber}');

/// Everyone of one kind holding a library book, searchable.
class BorrowersScreen extends StatefulWidget {
  final LibraryBorrowerKind kind;
  const BorrowersScreen({super.key, required this.kind});

  @override
  State<BorrowersScreen> createState() => _BorrowersScreenState();
}

class _BorrowersScreenState extends State<BorrowersScreen> with LibraryLive {
  List<LibraryLoan> _loans = const [];
  bool _loading = true;
  Object? _error;
  String _query = '';

  bool get _staff => widget.kind == LibraryBorrowerKind.staff;

  @override
  Future<void> reload() async {
    try {
      final loans = await library.openLoans(kind: widget.kind);
      if (mounted) {
        setState(() {
          _loans = loans;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<LibraryLoan>>{};
    for (final l in _loans) {
      groups.putIfAbsent(_personKey(l), () => []).add(l);
    }
    final q = _query.trim().toLowerCase();
    final qDigits = normalizeLoginPhone(_query);
    final people =
        groups.entries.where((e) {
          if (q.isEmpty) return true;
          final l = e.value.first;
          if (l.borrowerName.toLowerCase().contains(q)) return true;
          if (_staff) return qDigits.isNotEmpty && normalizeLoginPhone(l.contactNumber).contains(qDigits);
          return l.borrowerDetail.toLowerCase().contains(q);
        }).toList()..sort((a, b) {
          // Whoever owes the most urgent book comes first.
          int worst(List<LibraryLoan> ls) => ls.map((l) => l.daysLeft()).reduce((x, y) => x < y ? x : y);
          final c = worst(a.value).compareTo(worst(b.value));
          return c != 0 ? c : a.value.first.borrowerName.compareTo(b.value.first.borrowerName);
        });

    return Scaffold(
      appBar: AppBar(title: Text(_staff ? 'Get from staff' : 'Get from student')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? LibraryLoadError(error: _error!, onRetry: refreshLibrary)
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        hintText: _staff ? 'Search name or phone number' : 'Search name, class or roll number',
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.accent,
                      onRefresh: refreshLibrary,
                      child: people.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: 340,
                                  child: EmptyState(
                                    icon: Icons.assignment_turned_in_outlined,
                                    title: _loans.isEmpty ? 'Every book is back' : 'Nobody matches',
                                    subtitle: _loans.isEmpty
                                        ? 'No ${_staff ? 'staff member' : 'student'} has a library book right now.'
                                        : 'Try another name${_staff ? ' or number' : ''}.',
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: people.length,
                              itemBuilder: (context, i) => _personTile(people[i].key, people[i].value),
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _personTile(String key, List<LibraryLoan> loans) {
    final first = loans.first;
    final attention = loans.where((l) => l.needsAttention()).toList();
    final overdue = loans.any((l) => l.dueState() == LoanDueState.overdue);
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BorrowerLoansScreen(kind: widget.kind, personKey: key, name: first.borrowerName),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: (_staff ? LibraryColors.collect : LibraryColors.issue).withValues(alpha: 0.15),
            child: Text(
              first.borrowerName.trim().isEmpty ? '?' : first.borrowerName.trim()[0].toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _staff ? LibraryColors.collect : LibraryColors.issue,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(first.borrowerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(first.borrowerDetail, style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5)),
                if (first.borrowerGone) ...[const SizedBox(height: 3), BorrowerStatusChip(loan: first)],
                const SizedBox(height: 3),
                Text(
                  '${loans.length} book${loans.length == 1 ? '' : 's'}'
                  '${attention.isEmpty ? '' : ' · ${overdue ? 'overdue' : 'due soon'}'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: overdue
                        ? AppColors.error
                        : attention.isNotEmpty
                        ? AppColors.warning
                        : AppColors.onSurfaceHint(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
        ],
      ),
    );
  }
}

/// One borrower's books, each with its details and a "Get the book back".
class BorrowerLoansScreen extends StatefulWidget {
  final LibraryBorrowerKind kind;
  final String personKey;
  final String name;

  const BorrowerLoansScreen({super.key, required this.kind, required this.personKey, required this.name});

  @override
  State<BorrowerLoansScreen> createState() => _BorrowerLoansScreenState();
}

class _BorrowerLoansScreenState extends State<BorrowerLoansScreen> with LibraryLive {
  List<LibraryLoan> _loans = const [];
  bool _loading = true;
  Object? _error;

  @override
  Future<void> reload() async {
    try {
      final loans = await library.openLoans(kind: widget.kind);
      if (mounted) {
        setState(() {
          _loans = loans.where((l) => _personKey(l) == widget.personKey).toList();
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = _loans.isEmpty ? null : _loans.first;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? LibraryLoadError(error: _error!, onRetry: refreshLibrary)
            : _loans.isEmpty
            ? EmptyState(
                icon: Icons.assignment_turned_in_rounded,
                title: 'All books collected',
                subtitle: '${widget.name} has no library books now.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (first != null && first.borrowerDetail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                      child: Text(first.borrowerDetail, style: TextStyle(color: AppColors.onSurfaceMuted(context))),
                    ),
                  for (final l in _loans) _loanCard(l),
                ],
              ),
      ),
    );
  }

  Widget _loanCard(LibraryLoan l) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(20),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BookSpine(title: l.bookTitle, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.bookTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        DueChip(loan: l),
                        BorrowerStatusChip(loan: l),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _dateCell('Borrowed date', l.issuedAt)),
              Expanded(child: _dateCell('Due date', l.dueDate)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showLoanDetails(context, l, librarian: true),
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('Book details'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => collectBack(context, l),
                  icon: const Icon(Icons.assignment_return_rounded, size: 18),
                  label: const Text('Get book back'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateCell(String label, DateTime d) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12)),
      Text(libraryDate.format(d), style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}
