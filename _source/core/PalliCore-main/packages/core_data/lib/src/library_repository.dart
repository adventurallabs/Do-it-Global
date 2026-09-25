import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'remote_sync.dart';

/// The Digital Library. Unlike the other repositories there is no local
/// fallback: stock counts must come from the one place that enforces them,
/// so a failed read is shown as a failure, never as stale numbers.
///
/// Every write is a database function that runs as one transaction and
/// re-checks the stock itself (see migrations/20261005_library.sql). The app
/// never adds or subtracts a count.
class LibraryRepository {
  final SupabaseClient client;
  LibraryRepository(this.client);

  static const _pageSize = 1000;
  static const _loanColumns =
      'id, copy_id, book_id, borrower_kind, student_id, teacher_id, borrower_name, class_name, '
      'section, roll_number, contact_number, book_title, book_author, book_publisher, '
      'issued_at, due_date, returned_at, borrower_status';

  // ------------------------------------------------------------ changes ---

  StreamController<void>? _changes;
  RealtimeChannel? _channel;
  Timer? _debounce;

  /// Fires after any library change — this device's own writes at once, and
  /// other devices' through realtime. Every open library screen listens, so
  /// a book issued on one screen updates the counts on all of them.
  Stream<void> get changes {
    _changes ??= StreamController<void>.broadcast(
      onListen: _startRealtime,
      onCancel: _stopRealtime,
    );
    return _changes!.stream;
  }

  void _notify() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final c = _changes;
      if (c != null && !c.isClosed && c.hasListener) c.add(null);
    });
  }

  void _startRealtime() {
    if (_channel != null) return;
    try {
      var channel = client.channel('library-${DateTime.now().microsecondsSinceEpoch}');
      for (final table in const [
        'library_books',
        'library_copies',
        'library_loans',
        'library_racks',
        'library_sections',
      ]) {
        channel = channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (_) => _notify(),
        );
      }
      _channel = channel..subscribe();
    } catch (_) {
      _channel = null;
    }
  }

  void _stopRealtime() {
    final channel = _channel;
    _channel = null;
    if (channel != null) client.removeChannel(channel);
  }

  Future<T> _write<T>(Future<T> Function() op) async {
    final result = await op();
    _notify();
    return result;
  }

  /// PostgREST caps a response at 1000 rows; a school library can hold more
  /// titles than that, so lists are read a page at a time.
  Future<List<Map<String, dynamic>>> _all(
    PostgrestTransformBuilder<List<Map<String, dynamic>>> Function(int from, int to) page,
  ) async {
    final out = <Map<String, dynamic>>[];
    for (var from = 0;; from += _pageSize) {
      final rows = await page(from, from + _pageSize - 1);
      out.addAll(rows);
      if (rows.length < _pageSize) break;
    }
    return out;
  }

  // ------------------------------------------------------------- reads ----

  Future<LibraryOverview> overview() async {
    final res = await client.rpc('library_overview');
    return LibraryOverview.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<List<LibraryBook>> books() async {
    final rows = await _all((from, to) =>
        client.from('library_book_stock').select().order('title').order('id').range(from, to));
    return rows.map(LibraryBook.fromJson).toList();
  }

  Future<LibraryBook?> book(String id) async {
    final row = await client.from('library_book_stock').select().eq('id', id).maybeSingle();
    return row == null ? null : LibraryBook.fromJson(row);
  }

  Future<List<LibrarySection>> sections() async {
    final rows = await client.from('library_sections').select().order('code');
    return rows.map(LibrarySection.fromJson).toList();
  }

  Future<List<LibraryRack>> racks({String? sectionId}) async {
    final rows = sectionId == null
        ? await client.from('library_racks').select().order('code')
        : await client.from('library_racks').select().eq('section_id', sectionId).order('position');
    return rows.map(LibraryRack.fromJson).toList();
  }

  Future<LibraryRack?> rack(String id) async {
    final row = await client.from('library_racks').select().eq('id', id).maybeSingle();
    return row == null ? null : LibraryRack.fromJson(row);
  }

  /// What sits where. Filter by rack (to draw it), book (to find it) or
  /// section (to total it).
  Future<List<LibrarySlotBooks>> slotBooks({String? rackId, String? bookId, String? sectionId}) async {
    final rows = await _all((from, to) {
      var q = client.from('library_slot_books').select();
      if (rackId != null) q = q.eq('rack_id', rackId);
      if (bookId != null) q = q.eq('book_id', bookId);
      if (sectionId != null) q = q.eq('section_id', sectionId);
      return q
          .order('rack_code')
          .order('shelf_no')
          .order('partition_no')
          .order('title')
          .order('book_id')
          .range(from, to);
    });
    return rows.map(LibrarySlotBooks.fromJson).toList();
  }

  /// Books out right now, most overdue first.
  Future<List<LibraryLoan>> openLoans({LibraryBorrowerKind? kind, String? bookId}) async {
    final rows = await _all((from, to) {
      var q = client.from('library_loans').select(_loanColumns).isFilter('returned_at', null);
      if (kind != null) q = q.eq('borrower_kind', kind.name);
      if (bookId != null) q = q.eq('book_id', bookId);
      return q.order('due_date').order('issued_at').order('id').range(from, to);
    });
    return rows.map(LibraryLoan.fromJson).toList();
  }

  /// Every loan a staff member has ever had — RLS already limits a teacher
  /// to their own rows, the filter makes the intent explicit.
  Future<List<LibraryLoan>> loansForTeacher(String teacherId) async {
    final rows = await client
        .from('library_loans')
        .select(_loanColumns)
        .eq('borrower_kind', 'staff')
        .eq('teacher_id', teacherId)
        .order('issued_at', ascending: false);
    return rows.map(LibraryLoan.fromJson).toList();
  }

  /// Books still out with these people — asked before anyone is marked as
  /// leaving, so the school can collect them first.
  Future<List<LibraryLoan>> openLoansFor({List<String> studentIds = const [], String? teacherId}) async {
    if (studentIds.isEmpty && teacherId == null) return const [];
    var q = client.from('library_loans').select(_loanColumns).isFilter('returned_at', null);
    q = teacherId != null ? q.eq('teacher_id', teacherId) : q.inFilter('student_id', studentIds);
    final rows = await q.order('due_date');
    return rows.map(LibraryLoan.fromJson).toList();
  }

  Stream<void> watchTeacherLoans(String teacherId) {
    return client
        .from('library_loans')
        .stream(primaryKey: ['id'])
        .eq('teacher_id', teacherId)
        .map((_) {});
  }

  // ------------------------------------------------------------ books -----

  Future<String> createBook({
    required String title,
    required String author,
    required String publisher,
    required int count,
  }) =>
      _write(() async => '${await client.rpc('library_create_book', params: {
            'p_title': title,
            'p_author': author,
            'p_publisher': publisher,
            'p_count': count,
          })}');

  Future<void> updateBook(String id, {required String title, required String author, required String publisher}) =>
      _write(() => client.rpc('library_update_book', params: {
            'p_book_id': id,
            'p_title': title,
            'p_author': author,
            'p_publisher': publisher,
          }));

  Future<void> addCopies(String bookId, int count) =>
      _write(() => client.rpc('library_add_copies', params: {'p_book_id': bookId, 'p_count': count}));

  /// [counts] maps book id to how many copies to take out. With [dryRun]
  /// nothing changes — the result is the exact plan the real call would run.
  Future<List<LibraryRemoval>> removeCopies(Map<String, int> counts, {bool dryRun = false}) async {
    Future<List<LibraryRemoval>> run() async {
      final res = await client.rpc('library_remove_copies', params: {
        'p_items': [
          for (final e in counts.entries) {'book_id': e.key, 'count': e.value},
        ],
        'p_dry_run': dryRun,
      });
      return [for (final r in (res as List)) LibraryRemoval.fromJson(Map<String, dynamic>.from(r as Map))];
    }

    return dryRun ? run() : _write(run);
  }

  // ------------------------------------------------- sections and racks ---

  Future<String> createSection(String code, {String label = ''}) => _write(() async =>
      '${await client.rpc('library_create_section', params: {'p_code': code, 'p_label': label})}');

  Future<void> updateSectionLabel(String sectionId, String label) => _write(() =>
      client.rpc('library_update_section_label', params: {'p_section_id': sectionId, 'p_label': label}));

  /// Returns how many copies came off its shelves into the unassigned pile.
  Future<int> deleteSection(String sectionId) => _write(() async =>
      (await client.rpc('library_delete_section', params: {'p_section_id': sectionId}) as num).toInt());

  Future<String> createRack(String sectionId, {required int shelves, required int partitions}) =>
      _write(() async {
        final res = await client.rpc('library_create_rack', params: {
          'p_section_id': sectionId,
          'p_shelves': shelves,
          'p_partitions': partitions,
        });
        return '${(res as Map)['code']}';
      });

  Future<void> resizeRack(String rackId, {required int shelves, required int partitions}) =>
      _write(() => client.rpc('library_resize_rack', params: {
            'p_rack_id': rackId,
            'p_shelves': shelves,
            'p_partitions': partitions,
          }));

  Future<int> deleteRack(String rackId) => _write(() async =>
      (await client.rpc('library_delete_rack', params: {'p_rack_id': rackId}) as num).toInt());

  // ------------------------------------------------- placing and moving ---

  Future<void> place(String bookId, LibrarySlot to, {int count = 1}) =>
      _write(() => client.rpc('library_place', params: {
            'p_book_id': bookId,
            'p_rack_id': to.rackId,
            'p_shelf': to.shelfNo,
            'p_partition': to.partitionNo,
            'p_count': count,
          }));

  /// [to] null takes the copies off the shelves into the unassigned pile.
  Future<void> move(String bookId, LibrarySlot from, LibrarySlot? to, {int count = 1}) =>
      _write(() => client.rpc('library_move', params: {
            'p_book_id': bookId,
            'p_from_rack_id': from.rackId,
            'p_from_shelf': from.shelfNo,
            'p_from_partition': from.partitionNo,
            'p_to_rack_id': to?.rackId,
            'p_to_shelf': to?.shelfNo,
            'p_to_partition': to?.partitionNo,
            'p_count': count,
          }));

  // ------------------------------------------------------------ lending ---

  /// Issues one copy of [bookId], taken from [from] (null = the unassigned
  /// pile). The database verifies the borrower: a student by id, staff by
  /// the contact number the school holds for them.
  Future<String> issue({
    required String bookId,
    required LibrarySlot? from,
    required LibraryBorrowerKind kind,
    String? studentId,
    String? staffPhone,
    required DateTime dueDate,
  }) =>
      _write(() async => '${await client.rpc('library_issue', params: {
            'p_book_id': bookId,
            'p_from_rack_id': from?.rackId,
            'p_from_shelf': from?.shelfNo,
            'p_from_partition': from?.partitionNo,
            'p_borrower_kind': kind.name,
            'p_student_id': studentId,
            'p_staff_phone': staffPhone,
            'p_due_date': _isoDate(dueDate),
          })}');

  /// The copy goes to the unassigned pile, ready to be shelved again.
  Future<void> returnLoan(String loanId) =>
      _write(() => client.rpc('library_return', params: {'p_loan_id': loanId}));

  Future<void> extendDue(String loanId, DateTime dueDate) => _write(() =>
      client.rpc('library_extend_due', params: {'p_loan_id': loanId, 'p_due_date': _isoDate(dueDate)}));

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// The sentence to show for a failed library call. The database raises
/// plain-English messages for every rule it enforces; anything else is
/// almost always the network.
String libraryErrorMessage(Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case '42501':
        return 'Only the librarian can change the library.';
      // Two people acting on the same shelf or book at the same moment. The
      // database kept the stock right by refusing one; trying again works.
      case '40P01':
      case '40001':
        return 'Someone else changed this at the same moment. Please try again.';
      case '23505':
        return 'That already exists — refresh and check.';
      case '23503':
        return 'Something this depends on was just removed. Refresh and try again.';
    }
    final m = error.message.trim();
    if (m.isNotEmpty) return m;
  }
  return "Couldn't reach the library. Check your connection and try again.";
}

/// The leaver-dialog line for books still out, or null when there are none.
/// Best effort: a failed check must never stop an admin recording an exit.
Future<String?> libraryBooksStillOut(
  LibraryRepository repo, {
  List<String> studentIds = const [],
  String? teacherId,
}) async {
  try {
    final loans = await repo.openLoansFor(studentIds: studentIds, teacherId: teacherId).timeout(kRemoteTimeout);
    if (loans.isEmpty) return null;
    final titles = loans.map((l) => studentIds.length > 1 ? '${l.bookTitle} (${l.borrowerName})' : l.bookTitle);
    return '${loans.length} library book${loans.length == 1 ? ' is' : 's are'} still out: '
        '${titles.join(', ')}. Collect ${loans.length == 1 ? 'it' : 'them'} first — the librarian will '
        'see ${loans.length == 1 ? 'it' : 'them'} marked "Left school" until returned.';
  } catch (_) {
    return null;
  }
}
