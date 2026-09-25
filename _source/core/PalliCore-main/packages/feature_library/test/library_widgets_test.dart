import 'dart:async';

import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:feature_library/feature_library.dart';
import 'package:feature_library/src/books/books_screen.dart';
import 'package:feature_library/src/shelves/rack_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves canned data; never touches the network.
class _FakeLibrary extends LibraryRepository {
  _FakeLibrary({this.bookList = const [], this.teacherLoans = const []})
      : super(SupabaseClient('http://localhost', 'test-key', authOptions: const AuthClientOptions(autoRefreshToken: false)));

  List<LibraryBook> bookList;
  List<LibraryLoan> teacherLoans;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  void fireChange() => _changes.add(null);

  @override
  Future<List<LibraryBook>> books() async => bookList;

  @override
  Future<List<LibraryLoan>> loansForTeacher(String teacherId) async => teacherLoans;

  @override
  Stream<void> watchTeacherLoans(String teacherId) => const Stream.empty();
}

Widget _host(LibraryRepository repo, Widget child) => RepositoryProvider<LibraryRepository>.value(
      value: repo,
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );

LibraryLoan _loan(String title, DateTime due, {DateTime? returned}) => LibraryLoan(
      id: title,
      borrowerKind: LibraryBorrowerKind.staff,
      teacherId: 't1',
      borrowerName: 'Tony',
      bookTitle: title,
      issuedAt: DateTime.now().subtract(const Duration(days: 3)),
      dueDate: due,
      returnedAt: returned,
    );

void main() {
  final today = DateUtils.dateOnly(DateTime.now());

  group('BorrowedBooksCard', () {
    testWidgets('draws nothing before the first borrow', (tester) async {
      await tester.pumpWidget(_host(_FakeLibrary(), const BorrowedBooksCard(teacherId: 't1')));
      await tester.pumpAndSettle();
      expect(find.text('Books borrowed'), findsNothing);
    });

    testWidgets('flags an overdue book as needing attention', (tester) async {
      final repo = _FakeLibrary(teacherLoans: [_loan('Wings of Fire', today.subtract(const Duration(days: 2)))]);
      await tester.pumpWidget(_host(repo, const BorrowedBooksCard(teacherId: 't1')));
      await tester.pumpAndSettle();
      expect(find.text('Books borrowed'), findsOneWidget);
      expect(find.textContaining('Wings of Fire'), findsOneWidget);
      expect(find.text('Attention required · overdue'), findsOneWidget);
    });

    testWidgets('stays once everything is returned', (tester) async {
      final repo = _FakeLibrary(teacherLoans: [
        _loan('Malgudi Days', today, returned: DateTime.now()),
      ]);
      await tester.pumpWidget(_host(repo, const BorrowedBooksCard(teacherId: 't1')));
      await tester.pumpAndSettle();
      expect(find.text('Books borrowed'), findsOneWidget);
      expect(find.text('All returned — nothing with you now'), findsOneWidget);
    });
  });

  testWidgets('BooksScreen lists books with their copy breakdown and refreshes on change', (tester) async {
    final repo = _FakeLibrary(bookList: const [
      LibraryBook(
        id: 'b1',
        title: 'Wings of Fire',
        author: 'Kalam',
        totalCopies: 10,
        unassignedCopies: 4,
        shelvedCopies: 4,
        issuedCopies: 2,
      ),
    ]);
    await tester.pumpWidget(RepositoryProvider<LibraryRepository>.value(
      value: repo,
      child: const MaterialApp(home: BooksScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Wings of Fire'), findsOneWidget);
    expect(find.text('10 total'), findsOneWidget);
    expect(find.text('4 unassigned'), findsOneWidget);
    expect(find.text('2 issued'), findsOneWidget);

    // Another screen changes the stock: this one follows without a pull.
    repo.bookList = const [
      LibraryBook(id: 'b1', title: 'Wings of Fire', totalCopies: 10, unassignedCopies: 3, shelvedCopies: 4, issuedCopies: 3),
    ];
    repo.fireChange();
    await tester.pumpAndSettle();
    expect(find.text('3 issued'), findsOneWidget);
  });

  testWidgets('RackGrid draws every partition with its book count', (tester) async {
    const rack = LibraryRack(id: 'r', sectionId: 's', position: 1, code: 'A1', shelfCount: 2, partitionsPerShelf: 3);
    const slot = LibrarySlot(rackId: 'r', rackCode: 'A1', shelfNo: 2, partitionNo: 3);
    LibrarySlot? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RackGrid(
          rack: rack,
          contents: groupBySlot(const [
            LibrarySlotBooks(
              slot: slot,
              sectionId: 's',
              sectionCode: 'A',
              bookId: 'b1',
              title: 'Wings of Fire',
              author: '',
              copies: 7,
            ),
          ]),
          onTap: (s) => tapped = s,
        ),
      ),
    ));
    expect(find.text('S1'), findsOneWidget);
    expect(find.text('S2'), findsOneWidget);
    expect(find.text('P3'), findsNWidgets(2));
    expect(find.text('7'), findsOneWidget);
    await tester.tap(find.text('7'));
    expect(tapped, slot);
  });
}
