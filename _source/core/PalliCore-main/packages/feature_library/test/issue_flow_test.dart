import 'dart:async';

import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:feature_library/src/lending/issue_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final _client = SupabaseClient('http://localhost', 'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false));

class _FakeTeachers extends TeacherRepository {
  _FakeTeachers() : super(_client);
  @override
  Future<List<Teacher>> getAll({bool includeInactive = false}) async => [
        Teacher(id: 't1', name: 'Tony Stark', contactNumber: '3000300030', qualification: '', address: '', salary: 0),
      ];
}

class _FakeLibrary extends LibraryRepository {
  _FakeLibrary() : super(_client);
  final issued = <Map<String, Object?>>[];

  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<List<LibraryBook>> books() async => const [
        LibraryBook(id: 'b1', title: 'Wings of Fire', totalCopies: 3, unassignedCopies: 1, shelvedCopies: 2),
        LibraryBook(id: 'b2', title: 'All Out', totalCopies: 1, issuedCopies: 1),
      ];
  @override
  Future<LibraryBook?> book(String id) async => (await books()).firstWhere((b) => b.id == id);
  @override
  Future<List<LibraryLoan>> openLoans({LibraryBorrowerKind? kind, String? bookId}) async => const [];
  @override
  Future<List<LibrarySlotBooks>> slotBooks({String? rackId, String? bookId, String? sectionId}) async => const [
        LibrarySlotBooks(
          slot: LibrarySlot(rackId: 'r', rackCode: 'A1', shelfNo: 2, partitionNo: 3),
          sectionId: 's',
          sectionCode: 'A',
          bookId: 'b1',
          title: 'Wings of Fire',
          author: '',
          copies: 2,
        ),
      ];
  @override
  Future<String> issue({
    required String bookId,
    required LibrarySlot? from,
    required LibraryBorrowerKind kind,
    String? studentId,
    String? staffPhone,
    required DateTime dueDate,
  }) async {
    issued.add({'book': bookId, 'from': from?.label, 'phone': staffPhone});
    return 'loan-1';
  }
}

void main() {
  testWidgets('staff issue: phone verifies the teacher, then a copy is issued from the chosen place', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final library = _FakeLibrary();
    await tester.pumpWidget(MultiRepositoryProvider(
      providers: [
        RepositoryProvider<LibraryRepository>.value(value: library),
        RepositoryProvider<TeacherRepository>.value(value: _FakeTeachers()),
      ],
      child: const MaterialApp(home: IssueFormScreen(kind: LibraryBorrowerKind.staff)),
    ));
    await tester.pumpAndSettle();

    // Unknown number: not verified, can't continue.
    await tester.enterText(find.byType(TextField).first, '9999999999');
    await tester.pump();
    expect(find.text('No current staff member has this number'), findsOneWidget);

    // The school's number for Tony, typed with a country code.
    await tester.enterText(find.byType(TextField).first, '+91 30003 00030');
    await tester.pump();
    expect(find.text('Tony Stark'), findsOneWidget);

    await tester.tap(find.text('Next: book info'));
    await tester.pumpAndSettle();

    // Only books with a copy in the library are offered.
    expect(find.text('Wings of Fire'), findsOneWidget);
    expect(find.text('All Out'), findsNothing);
    await tester.tap(find.text('Wings of Fire'));
    await tester.pumpAndSettle();

    expect(find.text('Unassigned books'), findsOneWidget);
    expect(find.text('A1 · Shelf 2 · P3'), findsOneWidget);
    await tester.tap(find.text('A1 · Shelf 2 · P3'));
    await tester.pump();
    await tester.tap(find.text('Issue book'));
    await tester.pumpAndSettle();

    expect(library.issued.single, {'book': 'b1', 'from': 'A1 · Shelf 2 · P3', 'phone': '+91 30003 00030'});
    expect(find.text('Book issued'), findsOneWidget);

    // "Issue another" keeps the form on the book page for the same borrower.
    await tester.tap(find.text('Issue another'));
    await tester.pumpAndSettle();
    expect(find.text('Tony Stark'), findsOneWidget);
    expect(find.text('Wings of Fire'), findsOneWidget);
  });
}
