import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_admin_directory/feature_admin_directory.dart';
import 'package:go_router/go_router.dart';

/// End-of-year movement: who goes up, who stays, who leaves.
///
/// The old screen was a bare dropdown over a checkbox list with four buttons
/// underneath, and it never said where anyone was going or what an action
/// meant. Moving a child between years is irreversible bookkeeping, so this
/// one shows the destination before the tap and confirms with counts after.
class AcademicsScreen extends StatefulWidget {
  const AcademicsScreen({super.key});

  @override
  State<AcademicsScreen> createState() => _AcademicsScreenState();
}

/// What the admin is doing to the students they picked.
enum _Move {
  promote('Promote', 'Move up to the next class', Icons.arrow_upward_rounded),
  retain('Retain', 'Keep in the same class another year', Icons.restart_alt_rounded),
  graduate('Graduate', 'Finished their final year here', Icons.workspace_premium_rounded),
  transfer('Transfer out', 'Moved to another school', Icons.flight_takeoff_rounded),
  discontinue('Discontinue', 'Withdrawn mid-year', Icons.person_off_outlined);

  const _Move(this.label, this.blurb, this.icon);
  final String label;
  final String blurb;
  final IconData icon;

  /// Actions that end the child's time here and start the 30-day archive.
  bool get isExit => this != _Move.promote && this != _Move.retain;

  StudentLifecycle? get lifecycle => switch (this) {
        _Move.graduate => StudentLifecycle.graduated,
        _Move.transfer => StudentLifecycle.transferred,
        _Move.discontinue => StudentLifecycle.discontinued,
        _ => null,
      };

  Color get color => switch (this) {
        _Move.promote => AppColors.success,
        _Move.retain => AppColors.warning,
        _Move.graduate => AdminLook.gold,
        _Move.transfer => AppColors.accent,
        _Move.discontinue => AppColors.error,
      };
}

class _AcademicsScreenState extends State<AcademicsScreen> {
  List<AcademicYear> _years = [];
  List<Classroom> _classrooms = [];
  List<Student> _students = [];
  String? _sourceClassroomId;
  final Set<String> _selected = {};
  bool _loading = true;
  bool _hasError = false;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }
    try {
      final (years, classrooms, students) = await (
        context.read<AcademicYearRepository>().getAll(),
        context.read<ClassroomRepository>().getAll(),
        context.read<StudentRepository>().getAll(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _years = years;
        _classrooms = [...classrooms]
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        _students = students;
        _selected.removeWhere((id) => students.every((s) => s.id != id));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  Classroom? get _source =>
      _classrooms.where((c) => c.id == _sourceClassroomId).firstOrNull;

  /// Only children still on the roll can be moved — a leaver already sits in
  /// the archive with a retention clock running.
  List<Student> get _roster {
    if (_sourceClassroomId == null) return const [];
    final list = _students
        .where((s) => s.classroomId == _sourceClassroomId && !s.lifecycle.hasLeft)
        .toList()
      ..sort((a, b) {
        final byRoll = _rollOrder(a.rollNumber).compareTo(_rollOrder(b.rollNumber));
        return byRoll != 0 ? byRoll : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  static int _rollOrder(String roll) => int.tryParse(roll.trim()) ?? 1 << 30;

  List<Student> get _picked =>
      _roster.where((s) => _selected.contains(s.id)).toList();

  /// Where "Promote" would send this class, described in words before the tap.
  ({String label, List<Classroom> options, bool graduates})? get _promotion {
    final source = _source;
    if (source == null) return null;
    final next = GradeCatalog.nextKey(source.resolvedGradeKey);
    if (next == null) {
      return (label: 'Final class — promoting graduates them', options: const [], graduates: true);
    }
    final options = _classrooms.where((c) => c.resolvedGradeKey == next).toList();
    if (options.isEmpty) {
      return (
        label: 'No ${GradeCatalog.label(next)} exists yet — create it first',
        options: const [],
        graduates: false
      );
    }
    return (
      label: 'Moves to ${options.map((c) => c.displayName).join(' or ')}',
      options: options,
      graduates: false
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic year'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _hasError
                ? EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load academic data",
                    subtitle: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: _load,
                  )
                : _body(),
      ),
      bottomNavigationBar: _selected.isEmpty ? null : _actionBar(),
    );
  }

  Widget _body() {
    final roster = _roster;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 12, 16, _selected.isEmpty ? 28 : 12),
        children: [
          _yearsCard(),
          const SizedBox(height: 20),
          Text('Move students',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16, color: AdminLook.inkOf(context))),
          const SizedBox(height: 4),
          Text(
            'Pick a class, tick the students, then choose what happens to them.',
            style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
          ),
          const SizedBox(height: 14),
          _classPicker(),
          if (_sourceClassroomId != null) ...[
            const SizedBox(height: 14),
            _destinationNote(),
            const SizedBox(height: 14),
            if (roster.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'Nobody on this roll',
                  subtitle: 'Add students to ${_source?.displayName ?? 'this class'} first.',
                ),
              )
            else ...[
              _selectionHeader(roster),
              SoftSurface(
                depth: SoftDepth.one,
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < roster.length; i++) ...[
                      if (i > 0)
                        Divider(
                            height: 1,
                            indent: 56,
                            color: AppColors.onSurfaceHint(context).withValues(alpha: 0.14)),
                      _studentRow(roster[i]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _yearsCard() {
    if (_years.isEmpty) return const SizedBox.shrink();
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Years',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15, color: AdminLook.inkOf(context))),
          const SizedBox(height: 10),
          for (final year in _years)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    year.isCurrent ? Icons.play_circle_fill_rounded : Icons.history_rounded,
                    size: 18,
                    color: year.isCurrent ? AppColors.success : AppColors.onSurfaceHint(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(year.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${_shortDate(year.startDate)} – ${_shortDate(year.endDate)}',
                          style:
                              TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: year.isCurrent ? 'Current' : 'Previous',
                    color: year.isCurrent ? AppColors.success : AppColors.onSurfaceHint(context),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _classPicker() {
    if (_classrooms.isEmpty) {
      return Text('No classrooms yet.',
          style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13));
    }
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _classrooms.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final room = _classrooms[index];
          final count = _students
              .where((s) => s.classroomId == room.id && !s.lifecycle.hasLeft)
              .length;
          final selected = _sourceClassroomId == room.id;
          return ChoiceChip(
            label: Text('${room.displayName}  ·  $count'),
            selected: selected,
            onSelected: (_) => setState(() {
              _sourceClassroomId = selected ? null : room.id;
              _selected.clear();
            }),
          );
        },
      ),
    );
  }

  /// The single most useful thing the old screen never said: where "Promote"
  /// actually sends this class.
  Widget _destinationNote() {
    final promotion = _promotion;
    if (promotion == null) return const SizedBox.shrink();
    final blocked = promotion.options.isEmpty && !promotion.graduates;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: (blocked ? AppColors.error : AppColors.accent).withValues(alpha: 0.09),
        border: Border.all(
            color: (blocked ? AppColors.error : AppColors.accent).withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(blocked ? Icons.error_outline_rounded : Icons.arrow_upward_rounded,
              size: 18, color: blocked ? AppColors.error : AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              promotion.label,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: blocked ? AppColors.error : AppColors.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionHeader(List<Student> roster) {
    final allPicked = _selected.length == roster.length && roster.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _selected.isEmpty
                  ? '${roster.length} ${roster.length == 1 ? 'student' : 'students'}'
                  : '${_selected.length} of ${roster.length} selected',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AdminLook.inkOf(context)),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              if (allPicked) {
                _selected.clear();
              } else {
                _selected
                  ..clear()
                  ..addAll(roster.map((s) => s.id));
              }
            }),
            child: Text(allPicked ? 'Clear' : 'Select all'),
          ),
        ],
      ),
    );
  }

  Widget _studentRow(Student student) {
    final selected = _selected.contains(student.id);
    return CheckboxListTile(
      value: selected,
      activeColor: AppColors.accent,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      title: Text(student.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
      subtitle: Text(
        [
          if (student.rollNumber.isNotEmpty) 'Roll ${student.rollNumber}',
          if (student.admissionNo.isNotEmpty) 'Reg ${student.admissionNo}',
          if (student.lifecycle != StudentLifecycle.enrolled) student.lifecycle.label,
        ].join(' · '),
        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceHint(context)),
      ),
      onChanged: _working
          ? null
          : (val) => setState(() {
                if (val == true) {
                  _selected.add(student.id);
                } else {
                  _selected.remove(student.id);
                }
              }),
    );
  }

  /// The actions sit in a bar that only appears once somebody is selected —
  /// four always-visible buttons invited a mis-tap on an irreversible move.
  Widget _actionBar() {
    final count = _selected.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AdminLook.canvasOf(context),
        border: Border(
            top: BorderSide(color: AppColors.onSurfaceHint(context).withValues(alpha: 0.2))),
      ),
      child: SafeArea(
        top: false,
        child: _working
            ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$count ${count == 1 ? 'student' : 'students'} selected — what happens to them?',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceMuted(context)),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _Move.values.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final move = _Move.values[index];
                        return _MoveButton(move: move, onTap: () => _run(move));
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _run(_Move move) async {
    final picked = _picked;
    if (picked.isEmpty) return;
    switch (move) {
      case _Move.promote:
        await _promote(picked);
      case _Move.retain:
        await _retain(picked);
      case _Move.graduate:
      case _Move.transfer:
      case _Move.discontinue:
        await _exit(picked, move);
    }
  }

  Future<void> _promote(List<Student> picked) async {
    final source = _source;
    final promotion = _promotion;
    if (source == null || promotion == null) return;

    if (promotion.graduates) {
      await _exit(picked, _Move.graduate);
      return;
    }
    if (promotion.options.isEmpty) {
      _toast('Create ${GradeCatalog.label(GradeCatalog.nextKey(source.resolvedGradeKey) ?? '')} '
          'before promoting this class.');
      return;
    }

    var destination = promotion.options.first;
    if (promotion.options.length > 1) {
      final chosen = await showDialog<Classroom>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Promote into which section?'),
          children: [
            for (final option in promotion.options)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(option.displayName, style: const TextStyle(fontSize: 15)),
                ),
              ),
          ],
        ),
      );
      if (chosen == null) return;
      destination = chosen;
    }
    if (!mounted) return;

    final ok = await _confirm(
      title: 'Promote ${picked.length} to ${destination.displayName}?',
      body: 'They move off ${source.displayName} and onto ${destination.displayName}. '
          'Their marks, attendance and progress stay with them.',
      actionLabel: 'Promote',
      color: AppColors.success,
      names: picked,
    );
    if (ok != true) return;

    await _write(
      picked,
      (student) => student.copyWith(
        classroomId: destination.id,
        lifecycle: StudentLifecycle.enrolled,
      ),
      done: '${picked.length} moved to ${destination.displayName}.',
    );
  }

  Future<void> _retain(List<Student> picked) async {
    final source = _source;
    final ok = await _confirm(
      title: 'Retain ${picked.length} in ${source?.displayName ?? 'this class'}?',
      body: 'They stay in the same class for another year. Nothing else changes.',
      actionLabel: 'Retain',
      color: AppColors.warning,
      names: picked,
    );
    if (ok != true) return;
    await _write(
      picked,
      (student) => student.copyWith(lifecycle: StudentLifecycle.retained),
      done: '${picked.length} retained.',
    );
  }

  /// Graduating, transferring and discontinuing all end the child's time
  /// here, so they all go through the same explainer and the same archive.
  Future<void> _exit(List<Student> picked, _Move move) async {
    final lifecycle = move.lifecycle!;
    // One explainer for the batch — repeating it per child would train the
    // admin to tap through it.
    final booksOut = await libraryBooksStillOut(
      context.read<LibraryRepository>(),
      studentIds: [for (final s in picked) s.id],
    );
    if (!mounted) return;
    var note = '';
    final confirmed = await ExitExplainer.confirm(
      context,
      subjectName: picked.length == 1
          ? picked.single.name
          : '${picked.length} students from ${_source?.displayName ?? 'this class'}',
      isStaff: false,
      reason: lifecycle.exitReason!,
      onNote: (value) => note = value,
      extraConsequences: [?booksOut],
    );
    if (!confirmed || !mounted) return;

    final repo = context.read<StudentRepository>();
    setState(() => _working = true);
    try {
      for (final student in picked) {
        await repo.recordExit(student, lifecycle: lifecycle, note: note);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      _toast("Couldn't finish — check your connection and try again.");
      await _load();
      return;
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _selected.clear();
    });
    _toast('${picked.length} moved to '
        '${move == _Move.graduate ? 'Graduated' : 'Discontinued'}. '
        'Download their records within 30 days.');
    await _load();
  }

  Future<void> _write(
    List<Student> picked,
    Student Function(Student) transform, {
    required String done,
  }) async {
    final repo = context.read<StudentRepository>();
    setState(() => _working = true);
    try {
      await Future.wait(picked.map((s) => repo.upsert(transform(s))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      _toast("Couldn't finish — check your connection and try again.");
      await _load();
      return;
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _selected.clear();
    });
    _toast(done);
    await _load();
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String actionLabel,
    required Color color,
    required List<Student> names,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body, style: const TextStyle(fontSize: 13.5, height: 1.4)),
            const SizedBox(height: 12),
            Text(
              names.take(6).map((s) => s.name).join(', ') +
                  (names.length > 6 ? ' and ${names.length - 6} more' : ''),
              style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceMuted(ctx)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }
}

class _MoveButton extends StatelessWidget {
  final _Move move;
  final VoidCallback onTap;

  const _MoveButton({required this.move, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: move.blurb,
      child: Material(
        color: move.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(move.icon, size: 17, color: move.color),
                const SizedBox(width: 7),
                Text(
                  move.label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: move.color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _shortDate(DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
