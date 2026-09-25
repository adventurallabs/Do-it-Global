import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../library_widgets.dart';

/// "Issue a book": student or staff.
class IssueHomeScreen extends StatelessWidget {
  const IssueHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Issue a book')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _KindCard(
              icon: Icons.school_rounded,
              color: LibraryColors.issue,
              title: 'Issue book for student',
              subtitle: 'Class, section and roll number are checked against the school roll.',
              onTap: () => IssueFormScreen.open(context, LibraryBorrowerKind.student),
            ),
            const SizedBox(height: 12),
            _KindCard(
              icon: Icons.badge_rounded,
              color: LibraryColors.collect,
              title: 'Issue book for teacher',
              subtitle: 'The contact number is matched to the staff member it belongs to.',
              onTap: () => IssueFormScreen.open(context, LibraryBorrowerKind.staff),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _KindCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.two,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
        ],
      ),
    );
  }
}

/// Two pages: Borrower info, then Book info.
class IssueFormScreen extends StatefulWidget {
  final LibraryBorrowerKind kind;
  const IssueFormScreen({super.key, required this.kind});

  static Future<void> open(BuildContext context, LibraryBorrowerKind kind) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => IssueFormScreen(kind: kind)));

  @override
  State<IssueFormScreen> createState() => _IssueFormScreenState();
}

/// Where the copy being issued comes from: the unassigned pile (slot null)
/// or one partition.
class _Source {
  final LibrarySlot? slot;
  final int copies;
  const _Source(this.slot, this.copies);
  String get label => slot == null ? 'Unassigned books' : slot!.label;
}

class _IssueFormScreenState extends State<IssueFormScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _busy = false;

  bool get _student => widget.kind == LibraryBorrowerKind.student;

  // ---- borrower ----
  List<Classroom> _classrooms = const [];
  String? _grade;
  Classroom? _classroom;
  List<Student> _roster = const [];
  bool _rosterLoading = false;
  final _roll = TextEditingController();
  Student? _studentMatch;

  /// More than one child in the section shares the roll typed — never
  /// guess between them.
  bool _rollAmbiguous = false;

  List<Teacher> _staff = const [];
  final _phone = TextEditingController();
  Teacher? _staffMatch;

  List<LibraryLoan> _openLoans = const [];
  bool _setupLoading = true;
  Object? _setupError;

  final DateTime _issuedOn = DateUtils.dateOnly(DateTime.now());
  late DateTime _due = _issuedOn.add(const Duration(days: 14));

  // ---- book ----
  List<LibraryBook> _books = const [];
  String _query = '';
  LibraryBook? _book;
  List<_Source> _sources = const [];
  _Source? _source;
  bool _sourcesLoading = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _pages.dispose();
    _roll.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Loads the stock and the people to verify against. [silent] refreshes
  /// in place (after an issue) instead of swapping the form for a spinner,
  /// which would also throw the page view back to page 1.
  Future<void> _setup({bool silent = false}) async {
    // The first load comes from initState, already showing the spinner —
    // setState there would assert. Only a retry needs to switch back to it.
    if (!silent && !_setupLoading) {
      setState(() {
        _setupLoading = true;
        _setupError = null;
      });
    }
    final library = context.read<LibraryRepository>();
    try {
      final results = await Future.wait([
        library.books(),
        library.openLoans(kind: widget.kind),
        if (_student) context.read<ClassroomRepository>().getAll() else context.read<TeacherRepository>().getAll(),
      ]);
      if (!mounted) return;
      setState(() {
        _books = results[0] as List<LibraryBook>;
        _openLoans = results[1] as List<LibraryLoan>;
        if (_student) {
          _classrooms = results[2] as List<Classroom>;
        } else {
          _staff = (results[2] as List<Teacher>).where((t) => t.isActive && !t.hasLeft).toList();
        }
        _setupLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent) {
        showLibraryError(context, e);
      } else {
        setState(() {
          _setupLoading = false;
          _setupError = e;
        });
      }
    }
  }

  // ------------------------------------------------------------- student --

  List<String> get _grades {
    final keys = _classrooms.map((c) => c.resolvedGradeKey).toSet().toList();
    int rank(String k) {
      final i = GradeCatalog.orderedKeys.indexOf(k);
      return i < 0 ? 999 : i;
    }

    keys.sort((a, b) => rank(a) != rank(b) ? rank(a).compareTo(rank(b)) : a.compareTo(b));
    return keys;
  }

  List<Classroom> get _sectionsOfGrade {
    final list = _classrooms.where((c) => c.resolvedGradeKey == _grade).toList()
      ..sort((a, b) => a.resolvedSection.compareTo(b.resolvedSection));
    return list;
  }

  Future<void> _pickClassroom(Classroom? c) async {
    setState(() {
      _classroom = c;
      _roster = const [];
      _studentMatch = null;
      _rollAmbiguous = false;
      _rosterLoading = c != null;
    });
    if (c == null) return;
    try {
      final roster = await context.read<StudentRepository>().getByClassroom(c.id, strict: true);
      if (!mounted || _classroom?.id != c.id) return;
      setState(() {
        _roster = roster;
        _rosterLoading = false;
      });
      _matchRoll();
    } catch (e) {
      if (!mounted) return;
      setState(() => _rosterLoading = false);
      showLibraryError(context, e);
    }
  }

  static bool _sameRoll(String a, String b) {
    final x = a.trim().toLowerCase();
    final y = b.trim().toLowerCase();
    if (x == y) return true;
    final nx = int.tryParse(x);
    final ny = int.tryParse(y);
    return nx != null && nx == ny;
  }

  void _matchRoll() {
    final roll = _roll.text.trim();
    final matches = roll.isEmpty ? const <Student>[] : _roster.where((s) => _sameRoll(s.rollNumber, roll)).toList();
    setState(() {
      _studentMatch = matches.length == 1 ? matches.first : null;
      _rollAmbiguous = matches.length > 1;
    });
  }

  Future<void> _chooseFromRoster() async {
    if (_roster.isEmpty) return;
    final sorted = [..._roster]..sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
    final picked = await showModalBottomSheet<Student>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final s in sorted)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(s.rollNumber.isEmpty ? '—' : s.rollNumber, style: const TextStyle(fontSize: 12)),
                  ),
                  title: Text(s.name),
                  onTap: () => Navigator.pop(ctx, s),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    _roll.text = picked.rollNumber;
    setState(() {
      _studentMatch = picked;
      _rollAmbiguous = false;
    });
  }

  // --------------------------------------------------------------- staff --

  void _matchPhone() {
    final phone = normalizeLoginPhone(_phone.text);
    Teacher? match;
    if (phone.length >= 10) {
      for (final t in _staff) {
        if (normalizeLoginPhone(t.contactNumber) == phone) {
          match = t;
          break;
        }
      }
    }
    setState(() => _staffMatch = match);
  }

  // -------------------------------------------------------------- shared --

  bool get _borrowerReady => _student ? _studentMatch != null : _staffMatch != null;

  List<LibraryLoan> get _alreadyHolding {
    if (_student) {
      final id = _studentMatch?.id;
      return id == null ? const [] : _openLoans.where((l) => l.studentId == id).toList();
    }
    final id = _staffMatch?.id;
    return id == null ? const [] : _openLoans.where((l) => l.teacherId == id).toList();
  }

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: _issuedOn,
      lastDate: _issuedOn.add(const Duration(days: 365)),
      helpText: 'Due date',
    );
    if (picked != null) setState(() => _due = picked);
  }

  void _goTo(int page) {
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
    _pages.animateToPage(page, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Future<void> _chooseBook(LibraryBook b) async {
    setState(() {
      _book = b;
      _sources = const [];
      _source = null;
      _sourcesLoading = true;
    });
    try {
      final library = context.read<LibraryRepository>();
      final results = await Future.wait([library.book(b.id), library.slotBooks(bookId: b.id)]);
      if (!mounted || _book?.id != b.id) return;
      final fresh = results[0] as LibraryBook?;
      final slots = results[1] as List<LibrarySlotBooks>;
      final sources = <_Source>[
        if ((fresh?.unassignedCopies ?? 0) > 0) _Source(null, fresh!.unassignedCopies),
        for (final s in slots) _Source(s.slot, s.copies),
      ];
      setState(() {
        if (fresh != null) _book = fresh;
        _sources = sources;
        _source = sources.isEmpty ? null : sources.first;
        _sourcesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sourcesLoading = false);
      showLibraryError(context, e);
    }
  }

  Future<void> _issue() async {
    final book = _book;
    final source = _source;
    if (book == null || source == null || !_borrowerReady) return;
    setState(() => _busy = true);
    final library = context.read<LibraryRepository>();
    try {
      await library.issue(
        bookId: book.id,
        from: source.slot,
        kind: widget.kind,
        studentId: _studentMatch?.id,
        staffPhone: _student ? null : _phone.text,
        dueDate: _due,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      final who = _student ? _studentMatch!.name : _staffMatch!.name;
      final again = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
          title: const Text('Book issued'),
          content: Text(
            '"${book.title}" is issued to $who, due back on ${libraryDate.format(_due)}.'
            '${source.slot == null ? '' : '\n\nTaken from ${source.slot!.label}.'}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Issue another')),
            FilledButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Done')),
          ],
        ),
      );
      if (!mounted) return;
      if (again == true) {
        // Same borrower, next book: refresh stock and go back to page 2.
        setState(() {
          _book = null;
          _sources = const [];
          _source = null;
        });
        await _setup(silent: true);
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showLibraryError(context, e);
      // The stock may have moved under us — show the current picture.
      if (_book != null) _chooseBook(_book!);
    }
  }

  // ---------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(0);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_student ? 'Issue to a student' : 'Issue to a teacher')),
        body: SafeArea(
          child: _setupLoading
              ? const Center(child: CircularProgressIndicator())
              : _setupError != null
              ? LibraryLoadError(error: _setupError!, onRetry: _setup)
              : Column(
                  children: [
                    _Steps(page: _page),
                    Expanded(
                      child: PageView(
                        controller: _pages,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [_borrowerPage(), _bookPage()],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _borrowerPage() {
    final holding = _alreadyHolding;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (_student) ...[
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _grade,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: [for (final g in _grades) DropdownMenuItem(value: g, child: Text(GradeCatalog.label(g)))],
                  onChanged: (g) {
                    setState(() => _grade = g);
                    final sections = _sectionsOfGrade;
                    _pickClassroom(sections.length == 1 ? sections.first : null);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_grade),
                  initialValue: _classroom?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Section'),
                  items: [
                    for (final c in _sectionsOfGrade)
                      DropdownMenuItem(value: c.id, child: Text(c.resolvedSection.isEmpty ? '—' : c.resolvedSection)),
                  ],
                  onChanged: _grade == null
                      ? null
                      : (id) => _pickClassroom(_sectionsOfGrade.firstWhere((c) => c.id == id)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _roll,
            enabled: _classroom != null && !_rosterLoading,
            onChanged: (_) => _matchRoll(),
            decoration: InputDecoration(
              labelText: 'Roll number',
              prefixIcon: const Icon(Icons.tag_rounded),
              suffixIcon: _rosterLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      tooltip: 'Choose from the class list',
                      icon: const Icon(Icons.list_alt_rounded),
                      onPressed: _roster.isEmpty ? null : _chooseFromRoster,
                    ),
            ),
          ),
          const SizedBox(height: 14),
          _VerifiedName(
            label: 'Name of the borrower',
            name: _studentMatch?.name,
            detail: _studentMatch == null ? null : '${_classroom!.displayName} · Roll ${_studentMatch!.rollNumber}',
            hint: _classroom == null
                ? 'Choose the class and section first'
                : _roll.text.trim().isEmpty
                ? 'Enter the roll number'
                : _rollAmbiguous
                ? 'Several students have roll ${_roll.text.trim()} — choose from the class list'
                : 'No student with roll ${_roll.text.trim()} in ${_classroom!.displayName}',
          ),
        ] else ...[
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
            onChanged: (_) => _matchPhone(),
            decoration: const InputDecoration(
              labelText: 'Contact number',
              helperText: 'The number the teacher gave the school.',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 14),
          _VerifiedName(
            label: 'Name of the borrower',
            name: _staffMatch?.name,
            detail: _staffMatch?.roleLabel,
            hint: normalizeLoginPhone(_phone.text).length < 10
                ? 'Enter the 10-digit number to verify'
                : 'No current staff member has this number',
          ),
        ],
        if (holding.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Already has ${holding.length} book${holding.length == 1 ? '' : 's'}: '
              '${holding.map((l) => l.bookTitle).join(', ')}',
              style: TextStyle(
                color: holding.any((l) => l.dueState() == LoanDueState.overdue) ? AppColors.error : AppColors.warning,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Issued date', prefixIcon: Icon(Icons.today_rounded)),
                child: Text(libraryDate.format(_issuedOn)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _pickDue,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Due date', prefixIcon: Icon(Icons.event_rounded)),
                  child: Text(libraryDate.format(_due)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final days in const [7, 14, 21, 30])
              ChoiceChip(
                label: Text('$days days'),
                selected: _due == _issuedOn.add(Duration(days: days)),
                onSelected: (_) => setState(() => _due = _issuedOn.add(Duration(days: days))),
              ),
          ],
        ),
        const SizedBox(height: 24),
        SoftPrimaryButton(
          label: 'Next: book info',
          icon: Icons.arrow_forward_rounded,
          gold: true,
          onPressed: _borrowerReady ? () => _goTo(1) : null,
        ),
      ],
    );
  }

  Widget _bookPage() {
    final q = _query.trim().toLowerCase();
    final available = _books
        .where((b) => b.inLibrary > 0)
        .where((b) => q.isEmpty || b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q))
        .toList();
    final book = _book;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _BorrowerSummary(
          name: _student ? (_studentMatch?.name ?? '') : (_staffMatch?.name ?? ''),
          detail: _student
              ? '${_classroom?.displayName ?? ''} · Roll ${_studentMatch?.rollNumber ?? ''}'
              : normalizeLoginPhone(_phone.text),
          due: _due,
          onEdit: () => _goTo(0),
        ),
        const SizedBox(height: 14),
        if (book == null) ...[
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search book name or author',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          if (available.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _books.isEmpty
                    ? 'No books in the library yet.'
                    : 'No available copy matches. Issued books appear once returned.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceMuted(context)),
              ),
            )
          else
            for (final b in available)
              SoftSurface(
                depth: SoftDepth.one,
                borderRadius: BorderRadius.circular(16),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                onTap: () => _chooseBook(b),
                child: Row(
                  children: [
                    BookSpine(title: b.title, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (b.author.isNotEmpty)
                            Text(b.author, style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Text(
                      '${b.inLibrary} available',
                      style: const TextStyle(color: LibraryColors.shelved, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
        ] else ...[
          SoftSurface(
            depth: SoftDepth.two,
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                BookSpine(title: book.title, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(
                        [book.author, book.publisher].where((s) => s.isNotEmpty).join(' · '),
                        style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _book = null;
                    _source = null;
                    _sources = const [];
                  }),
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          SectionLabel('Take the copy from'),
          if (_sourcesLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_sources.isEmpty)
            Text(
              'No copy of this book is in the library right now.',
              style: TextStyle(color: AppColors.onSurfaceMuted(context)),
            )
          else
            RadioGroup<_Source>(
              groupValue: _source,
              onChanged: (s) => setState(() => _source = s),
              child: Column(
                children: [
                  for (final s in _sources)
                    RadioListTile<_Source>(
                      value: s,
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${s.copies} cop${s.copies == 1 ? 'y' : 'ies'} here'),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          SoftPrimaryButton(
            label: _busy ? 'Issuing…' : 'Issue book',
            icon: Icons.outbox_rounded,
            gold: true,
            onPressed: _busy || _source == null ? null : _issue,
          ),
        ],
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  final int page;
  const _Steps({required this.page});

  @override
  Widget build(BuildContext context) {
    Widget step(int i, String label) {
      final active = page == i;
      final done = page > i;
      final color = active || done ? AppColors.accent : AppColors.onSurfaceHint(context);
      return Expanded(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              height: 4,
              decoration: BoxDecoration(
                color: color.withValues(alpha: active || done ? 1 : 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${i + 1}. $label',
              style: TextStyle(fontSize: 12.5, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: color),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(children: [step(0, 'Borrower info'), const SizedBox(width: 10), step(1, 'Book info')]),
    );
  }
}

class _VerifiedName extends StatelessWidget {
  final String label;
  final String? name;
  final String? detail;
  final String hint;

  const _VerifiedName({required this.label, required this.name, required this.detail, required this.hint});

  @override
  Widget build(BuildContext context) {
    final ok = name != null;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          ok ? Icons.verified_rounded : Icons.person_search_rounded,
          color: ok ? AppColors.success : AppColors.onSurfaceHint(context),
        ),
      ),
      child: ok
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                if (detail != null && detail!.isNotEmpty)
                  Text(detail!, style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5)),
              ],
            )
          : Text(hint, style: TextStyle(color: AppColors.onSurfaceHint(context))),
    );
  }
}

class _BorrowerSummary extends StatelessWidget {
  final String name;
  final String detail;
  final DateTime due;
  final VoidCallback onEdit;

  const _BorrowerSummary({required this.name, required this.detail, required this.due, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  '$detail · due ${libraryDate.format(due)}',
                  style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12.5),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Edit')),
        ],
      ),
    );
  }
}
