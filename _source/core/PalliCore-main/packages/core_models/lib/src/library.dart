// The Digital Library. Every count here is derived by the database from one
// row per physical copy (see supabase/migrations/20261005_library.sql), so
// the app only ever displays numbers — it never adds them up itself.

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
String _str(Object? v) => v == null ? '' : '$v';
DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// A title and how its copies are spread right now.
class LibraryBook {
  final String id;
  final String title;
  final String author;
  final String publisher;
  final int totalCopies;
  final int unassignedCopies;
  final int shelvedCopies;
  final int issuedCopies;
  final int issuedToStudents;
  final int issuedToStaff;
  final DateTime? createdAt;

  const LibraryBook({
    required this.id,
    required this.title,
    this.author = '',
    this.publisher = '',
    this.totalCopies = 0,
    this.unassignedCopies = 0,
    this.shelvedCopies = 0,
    this.issuedCopies = 0,
    this.issuedToStudents = 0,
    this.issuedToStaff = 0,
    this.createdAt,
  });

  /// Copies physically in the library — the ones that can be issued, moved
  /// or deleted.
  int get inLibrary => unassignedCopies + shelvedCopies;

  factory LibraryBook.fromJson(Map<String, dynamic> j) => LibraryBook(
        id: _str(j['id']),
        title: _str(j['title']),
        author: _str(j['author']),
        publisher: _str(j['publisher']),
        totalCopies: _int(j['total_copies']),
        unassignedCopies: _int(j['unassigned_copies']),
        shelvedCopies: _int(j['shelved_copies']),
        issuedCopies: _int(j['issued_copies']),
        issuedToStudents: _int(j['issued_to_students']),
        issuedToStaff: _int(j['issued_to_staff']),
        createdAt: _date(j['created_at']),
      );
}

class LibrarySection {
  final String id;

  /// Letters only ('A', 'REF'); every rack in it is named code + number.
  final String code;
  final String label;

  const LibrarySection({required this.id, required this.code, this.label = ''});

  String get displayName => label.isEmpty ? 'Section $code' : 'Section $code · $label';

  factory LibrarySection.fromJson(Map<String, dynamic> j) =>
      LibrarySection(id: _str(j['id']), code: _str(j['code']), label: _str(j['label']));
}

class LibraryRack {
  final String id;
  final String sectionId;
  final int position;
  final String code;
  final int shelfCount;
  final int partitionsPerShelf;

  const LibraryRack({
    required this.id,
    required this.sectionId,
    required this.position,
    required this.code,
    required this.shelfCount,
    required this.partitionsPerShelf,
  });

  int get partitionCount => shelfCount * partitionsPerShelf;

  factory LibraryRack.fromJson(Map<String, dynamic> j) => LibraryRack(
        id: _str(j['id']),
        sectionId: _str(j['section_id']),
        position: _int(j['position']),
        code: _str(j['code']),
        shelfCount: _int(j['shelf_count']),
        partitionsPerShelf: _int(j['partitions_per_shelf']),
      );
}

/// One partition: rack + shelf + partition, numbered from 1.
class LibrarySlot {
  final String rackId;
  final String rackCode;
  final int shelfNo;
  final int partitionNo;

  const LibrarySlot({
    required this.rackId,
    required this.rackCode,
    required this.shelfNo,
    required this.partitionNo,
  });

  String get label => '$rackCode · Shelf $shelfNo · P$partitionNo';

  bool sameAs(LibrarySlot o) =>
      o.rackId == rackId && o.shelfNo == shelfNo && o.partitionNo == partitionNo;

  @override
  bool operator ==(Object other) => other is LibrarySlot && sameAs(other);

  @override
  int get hashCode => Object.hash(rackId, shelfNo, partitionNo);
}

/// How many copies of one title sit in one partition.
class LibrarySlotBooks {
  final LibrarySlot slot;
  final String sectionId;
  final String sectionCode;
  final String bookId;
  final String title;
  final String author;
  final int copies;

  const LibrarySlotBooks({
    required this.slot,
    required this.sectionId,
    required this.sectionCode,
    required this.bookId,
    required this.title,
    required this.author,
    required this.copies,
  });

  factory LibrarySlotBooks.fromJson(Map<String, dynamic> j) => LibrarySlotBooks(
        slot: LibrarySlot(
          rackId: _str(j['rack_id']),
          rackCode: _str(j['rack_code']),
          shelfNo: _int(j['shelf_no']),
          partitionNo: _int(j['partition_no']),
        ),
        sectionId: _str(j['section_id']),
        sectionCode: _str(j['section_code']),
        bookId: _str(j['book_id']),
        title: _str(j['title']),
        author: _str(j['author']),
        copies: _int(j['copies']),
      );
}

enum LibraryBorrowerKind { student, staff }

/// Whether the person holding a book is still with the school. Kept current
/// by the database from the student/staff record.
enum LibraryBorrowerStatus { active, inactive, left }

/// Where a loan stands against its due date.
enum LoanDueState { returned, onTime, dueSoon, dueToday, overdue }

/// Days before the due date that a loan starts asking for attention.
const int kLibraryDueSoonDays = 2;

class LibraryLoan {
  final String id;
  final String? copyId;
  final String? bookId;
  final LibraryBorrowerKind borrowerKind;
  final String? studentId;
  final String? teacherId;
  final String borrowerName;
  final String className;
  final String section;
  final String rollNumber;
  final String contactNumber;
  final String bookTitle;
  final String bookAuthor;
  final String bookPublisher;
  final DateTime issuedAt;

  /// A calendar date — no time of day.
  final DateTime dueDate;
  final DateTime? returnedAt;
  final LibraryBorrowerStatus borrowerStatus;

  const LibraryLoan({
    required this.id,
    this.copyId,
    this.bookId,
    required this.borrowerKind,
    this.studentId,
    this.teacherId,
    required this.borrowerName,
    this.className = '',
    this.section = '',
    this.rollNumber = '',
    this.contactNumber = '',
    required this.bookTitle,
    this.bookAuthor = '',
    this.bookPublisher = '',
    required this.issuedAt,
    required this.dueDate,
    this.returnedAt,
    this.borrowerStatus = LibraryBorrowerStatus.active,
  });

  bool get isOpen => returnedAt == null;

  /// The borrower left the school, was deactivated, or their record was
  /// erased — while the book is still out. The librarian must chase it.
  bool get borrowerGone => isOpen && borrowerStatus != LibraryBorrowerStatus.active;

  String get borrowerStatusLabel => switch (borrowerStatus) {
        LibraryBorrowerStatus.active => '',
        LibraryBorrowerStatus.inactive => 'Account deactivated',
        LibraryBorrowerStatus.left => 'Left school',
      };
  bool get isStudent => borrowerKind == LibraryBorrowerKind.student;

  /// "LKG A · Roll 01" for a student, the phone number for staff.
  String get borrowerDetail {
    if (!isStudent) return contactNumber;
    final cls = [className, section].where((s) => s.isNotEmpty).join(' ');
    return [if (cls.isNotEmpty) cls, if (rollNumber.isNotEmpty) 'Roll $rollNumber'].join(' · ');
  }

  /// Whole days until due; negative once overdue.
  int daysLeft([DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  LoanDueState dueState([DateTime? now]) {
    if (!isOpen) return LoanDueState.returned;
    final d = daysLeft(now);
    if (d < 0) return LoanDueState.overdue;
    if (d == 0) return LoanDueState.dueToday;
    if (d <= kLibraryDueSoonDays) return LoanDueState.dueSoon;
    return LoanDueState.onTime;
  }

  /// Due soon, due today or overdue, and still not back.
  bool needsAttention([DateTime? now]) {
    final s = dueState(now);
    return s == LoanDueState.dueSoon || s == LoanDueState.dueToday || s == LoanDueState.overdue;
  }

  String dueLabel([DateTime? now]) {
    final d = daysLeft(now);
    switch (dueState(now)) {
      case LoanDueState.returned:
        return 'Returned';
      case LoanDueState.overdue:
        return 'Overdue by ${-d} day${d == -1 ? '' : 's'}';
      case LoanDueState.dueToday:
        return 'Due today';
      case LoanDueState.dueSoon:
        return d == 1 ? 'Due tomorrow' : 'Due in $d days';
      case LoanDueState.onTime:
        return 'Due in $d days';
    }
  }

  factory LibraryLoan.fromJson(Map<String, dynamic> j) {
    final due = DateTime.tryParse(_str(j['due_date'])) ?? DateTime.now();
    return LibraryLoan(
      id: _str(j['id']),
      copyId: j['copy_id'] as String?,
      bookId: j['book_id'] as String?,
      borrowerKind: j['borrower_kind'] == 'staff' ? LibraryBorrowerKind.staff : LibraryBorrowerKind.student,
      studentId: j['student_id'] as String?,
      teacherId: j['teacher_id'] as String?,
      borrowerName: _str(j['borrower_name']),
      className: _str(j['class_name']),
      section: _str(j['section']),
      rollNumber: _str(j['roll_number']),
      contactNumber: _str(j['contact_number']),
      bookTitle: _str(j['book_title']),
      bookAuthor: _str(j['book_author']),
      bookPublisher: _str(j['book_publisher']),
      issuedAt: _date(j['issued_at']) ?? DateTime.now(),
      dueDate: DateTime(due.year, due.month, due.day),
      returnedAt: _date(j['returned_at']),
      borrowerStatus: switch (j['borrower_status']) {
        'inactive' => LibraryBorrowerStatus.inactive,
        'left' => LibraryBorrowerStatus.left,
        _ => LibraryBorrowerStatus.active,
      },
    );
  }
}

/// Library-wide numbers for the librarian's dashboard.
class LibraryOverview {
  final int titles;
  final int copies;
  final int unassigned;
  final int shelved;
  final int issued;
  final int issuedStudents;
  final int issuedStaff;
  final int overdue;
  final int dueSoon;
  final int sections;
  final int racks;

  const LibraryOverview({
    this.titles = 0,
    this.copies = 0,
    this.unassigned = 0,
    this.shelved = 0,
    this.issued = 0,
    this.issuedStudents = 0,
    this.issuedStaff = 0,
    this.overdue = 0,
    this.dueSoon = 0,
    this.sections = 0,
    this.racks = 0,
  });

  factory LibraryOverview.fromJson(Map<String, dynamic> j) => LibraryOverview(
        titles: _int(j['titles']),
        copies: _int(j['copies']),
        unassigned: _int(j['unassigned']),
        shelved: _int(j['shelved']),
        issued: _int(j['issued']),
        issuedStudents: _int(j['issued_students']),
        issuedStaff: _int(j['issued_staff']),
        overdue: _int(j['overdue']),
        dueSoon: _int(j['due_soon']),
        sections: _int(j['sections']),
        racks: _int(j['racks']),
      );
}

/// One line of a copy deletion — what the database will take (dry run) or
/// took. Unassigned copies go first, then shelved ones in rack order.
class LibraryRemoval {
  final String bookId;
  final String title;
  final int removed;
  final int fromUnassigned;

  /// Partitions the shelved copies come out of, so the librarian knows
  /// which physical books to pull.
  final List<({String rackCode, int shelfNo, int partitionNo, int copies})> fromPartitions;
  final int copiesLeft;
  final bool bookRemoved;

  const LibraryRemoval({
    required this.bookId,
    required this.title,
    required this.removed,
    required this.fromUnassigned,
    required this.fromPartitions,
    required this.copiesLeft,
    required this.bookRemoved,
  });

  factory LibraryRemoval.fromJson(Map<String, dynamic> j) => LibraryRemoval(
        bookId: _str(j['book_id']),
        title: _str(j['title']),
        removed: _int(j['removed']),
        fromUnassigned: _int(j['from_unassigned']),
        fromPartitions: [
          for (final p in (j['from_partitions'] as List? ?? const []))
            (
              rackCode: _str((p as Map)['rack_code']),
              shelfNo: _int(p['shelf_no']),
              partitionNo: _int(p['partition_no']),
              copies: _int(p['copies']),
            ),
        ],
        copiesLeft: _int(j['copies_left']),
        bookRemoved: j['book_removed'] == true,
      );
}
