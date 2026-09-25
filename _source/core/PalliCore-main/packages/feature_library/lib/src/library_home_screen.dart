import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';

import 'books/books_screen.dart';
import 'lending/issue_screen.dart';
import 'lending/loan_widgets.dart';
import 'lending/return_screen.dart';
import 'library_widgets.dart';
import 'shelves/sections_screen.dart';

/// The librarian's home — "Digital Library". Signed in through the staff
/// login, but a separate app area from the teacher's.
class LibraryHomeScreen extends StatefulWidget {
  const LibraryHomeScreen({super.key});

  @override
  State<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _LibraryHomeScreenState extends State<LibraryHomeScreen> with LibraryLive {
  LibraryOverview? _overview;
  List<LibraryLoan> _attention = const [];
  Object? _error;

  @override
  Future<void> reload() async {
    try {
      final results = await Future.wait([library.overview(), library.openLoans()]);
      if (!mounted) return;
      setState(() {
        _overview = results[0] as LibraryOverview;
        // Overdue / due soon, and anything still out with someone who has
        // left — those are the books most likely never to come back.
        _attention = (results[1] as List<LibraryLoan>).where((l) => l.needsAttention() || l.borrowerGone).toList()
          ..sort((a, b) {
            if (a.borrowerGone != b.borrowerGone) return a.borrowerGone ? -1 : 1;
            return a.dueDate.compareTo(b.dueDate);
          });
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final login = context.watch<LoginBloc>().state;
    final name = login is LoginSuccess ? (login.user.name?.trim() ?? '') : '';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    final cards = [
      (
        title: 'Book management',
        subtitle: 'Add, find, assign and delete books',
        icon: Icons.menu_book_rounded,
        color: LibraryColors.books,
        screen: const BooksScreen() as Widget,
      ),
      (
        title: 'Section management',
        subtitle: 'Sections, racks, shelves, partitions',
        icon: Icons.shelves,
        color: LibraryColors.shelves,
        screen: const SectionsScreen() as Widget,
      ),
      (
        title: 'Issue a book',
        subtitle: 'To a student or a teacher',
        icon: Icons.outbox_rounded,
        color: LibraryColors.issue,
        screen: const IssueHomeScreen() as Widget,
      ),
      (
        title: 'Get back a book',
        subtitle: 'Collect from staff or students',
        icon: Icons.assignment_return_rounded,
        color: LibraryColors.collect,
        screen: const ReturnHomeScreen() as Widget,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: refreshLibrary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SoftPageHeader(
                  title: 'Digital Library',
                  actions: [
                    SoftIconButton(
                      icon: Icons.logout_rounded,
                      tooltip: 'Sign out',
                      elevated: false,
                      onTap: () async {
                        final bloc = context.read<LoginBloc>();
                        if (await confirmSignOut(context)) bloc.add(LogoutRequested());
                      },
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: NeoClockCard(subtitle: name.isEmpty ? greeting : '$greeting, $name', title: 'Librarian'),
              ),
              SliverToBoxAdapter(child: _stats()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final c = cards[i];
                    return AnimatedListItem(
                      index: i,
                      staggerLimit: cards.length,
                      delay: const Duration(milliseconds: 30),
                      child: PremiumCard(
                        title: c.title,
                        subtitle: c.subtitle,
                        icon: c.icon,
                        iconColor: c.color,
                        onTap: () => _push(c.screen),
                      ),
                    );
                  }, childCount: cards.length),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 148,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _attentionList()),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stats() {
    if (_error != null && _overview == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: SoftSurface(
          depth: SoftDepth.one,
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.error),
              const SizedBox(width: 12),
              Expanded(child: Text(libraryErrorMessage(_error!))),
              TextButton(onPressed: refreshLibrary, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final o = _overview;
    if (o == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: CountGrid(
        tiles: [
          CountTile(
            label: '${o.titles} titles · copies',
            value: o.copies,
            color: LibraryColors.books,
            icon: Icons.library_books_rounded,
            onTap: () => _push(const BooksScreen()),
          ),
          CountTile(
            label: 'On shelves',
            value: o.shelved,
            color: LibraryColors.shelved,
            icon: Icons.shelves,
            onTap: () => _push(const SectionsScreen()),
          ),
          CountTile(
            label: 'Unassigned',
            value: o.unassigned,
            color: LibraryColors.unassigned,
            icon: Icons.inventory_2_outlined,
            onTap: () => _push(const BooksScreen(startWithUnassigned: true)),
          ),
          CountTile(
            label: '${o.issuedStudents} students · ${o.issuedStaff} staff',
            value: o.issued,
            color: LibraryColors.issued,
            icon: Icons.outbox_rounded,
            onTap: () => _push(const ReturnHomeScreen()),
          ),
        ],
      ),
    );
  }

  Widget _attentionList() {
    if (_attention.isEmpty) return const SizedBox.shrink();
    final overdue = _attention.where((l) => l.dueState() == LoanDueState.overdue).length;
    final gone = _attention.where((l) => l.borrowerGone).length;
    final shown = _attention.take(5).toList();
    final parts = [if (overdue > 0) '$overdue overdue', if (gone > 0) '$gone with leavers'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            parts.isEmpty ? 'Due back soon' : 'Attention required · ${parts.join(' · ')}',
            trailing: TextButton(onPressed: () => _push(const ReturnHomeScreen()), child: const Text('See all')),
          ),
          for (final l in shown) LoanTile(loan: l, onTap: () => showLoanDetails(context, l, librarian: true)),
        ],
      ),
    );
  }
}
