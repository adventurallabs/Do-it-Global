import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import '../progress/progress_widgets.dart';
import 'marks_format.dart';

/// One test, shown the way a result sheet is read: a row per student, a
/// marks column, a percentage column.
///
/// The same screen records a new test and corrects an old one. Splitting them
/// would mean a teacher who mistypes a score has nowhere to go — which is
/// exactly what was missing before.
class MarksSheetScreen extends StatefulWidget {
  final String teacherId;
  final Classroom classroom;
  final TeachingScope scope;

  /// Null to record a new test; otherwise the sheet being corrected.
  final MarkSheet? sheet;

  /// Formal exams that cover this classroom — picking one is what makes the
  /// parent app file these marks under a report card rather than a loose test.
  final List<Exam> exams;
  final String? initialSubject;

  const MarksSheetScreen({
    super.key,
    required this.teacherId,
    required this.classroom,
    required this.scope,
    this.sheet,
    this.exams = const [],
    this.initialSubject,
  });

  /// Returns true when marks were written, so the caller can refresh.
  static Future<bool> open(
    BuildContext context, {
    required String teacherId,
    required Classroom classroom,
    required TeachingScope scope,
    MarkSheet? sheet,
    List<Exam> exams = const [],
    String? initialSubject,
  }) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MarksSheetScreen(
          teacherId: teacherId,
          classroom: classroom,
          scope: scope,
          sheet: sheet,
          exams: exams,
          initialSubject: initialSubject,
        ),
      ),
    );
    return saved == true;
  }

  @override
  State<MarksSheetScreen> createState() => _MarksSheetScreenState();
}

class _MarksSheetScreenState extends State<MarksSheetScreen> {
  static const _testPresets = ['Unit test', 'Class test', 'Quiz', 'Mid-term', 'Term exam'];
  static const _outOfPresets = [10, 25, 50, 100];

  String? _subject;
  String _examId = '';
  final _testNameC = TextEditingController();
  final _outOfC = TextEditingController(text: '100');
  final Map<String, TextEditingController> _scoreC = {};
  final Map<String, FocusNode> _focus = {};

  /// What each student scored when the screen opened — the baseline that says
  /// which rows were touched, which were added and which were cleared.
  final Map<String, Mark> _original = {};

  List<Student> _students = [];
  bool _loading = true;
  bool _error = false;
  bool _saving = false;
  bool _savedSomething = false;

  bool get _isEditing => widget.sheet != null;

  /// Keeps ids stable between the first save and every later correction.
  late final DateTime _sheetDate = widget.sheet?.date ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final sheet = widget.sheet;
    if (sheet != null) {
      _subject = sheet.subject;
      _examId = sheet.examId;
      _testNameC.text = sheet.testType;
      _outOfC.text = fmtNum(sheet.totalMarks);
      for (final mark in sheet.marks) {
        _original[mark.studentId] = mark;
      }
    } else {
      _subject = widget.initialSubject ??
          (widget.scope.subjects.length == 1 ? widget.scope.subjects.first : null);
    }
    _load();
  }

  @override
  void dispose() {
    _testNameC.dispose();
    _outOfC.dispose();
    for (final c in _scoreC.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      // This class's own roster — never the shared bloc list, which can hold
      // a different section's students.
      final list = await context.read<StudentRepository>().getByClassroom(widget.classroom.id);
      if (!mounted) return;
      setState(() {
        _students = sortedRoster(list);
        for (final s in _students) {
          _scoreC.putIfAbsent(
            s.id,
            () => TextEditingController(
              text: _original[s.id] == null ? '' : fmtNum(_original[s.id]!.score),
            ),
          );
          _focus.putIfAbsent(s.id, () => FocusNode());
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  double? get _outOf {
    final v = double.tryParse(_outOfC.text.trim());
    return v == null || v <= 0 ? null : v;
  }

  /// null = empty (skipped), NaN = out of range.
  double? _scoreOf(String studentId) {
    final t = _scoreC[studentId]?.text.trim() ?? '';
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    final max = _outOf;
    if (v == null || v < 0 || (max != null && v > max)) return double.nan;
    return v;
  }

  bool _isEdited(String studentId) {
    final before = _original[studentId];
    final now = _scoreOf(studentId);
    if (now != null && now.isNaN) return false;
    if (before == null) return now != null;
    if (now == null) return true;
    return now != before.score || before.totalMarks != (_outOf ?? before.totalMarks);
  }

  int get _entered => _students.where((s) {
        final v = _scoreOf(s.id);
        return v != null && !v.isNaN;
      }).length;

  int get _changed => _students.where((s) => _isEdited(s.id)).length;

  bool get _hasInvalid => _students.any((s) => _scoreOf(s.id)?.isNaN ?? false);

  bool get _dirty => _changed > 0;

  String? get _blocker {
    if (_subject == null) return 'Pick a subject';
    if (!widget.scope.canEnterMarksFor(_subject!)) return "You don't teach $_subject here";
    if (_testNameC.text.trim().isEmpty) return 'Name the test';
    if (_outOf == null) return 'Set the maximum marks';
    if (_hasInvalid) return 'Fix the marks in red';
    if (!_isEditing && _entered == 0) return 'Enter at least one mark';
    if (_isEditing && !_dirty) return 'No changes to save';
    return null;
  }

  /// Derived from the student, subject, test and day rather than the clock, so
  /// re-entering a test to correct a typo overwrites the earlier scores. A
  /// timestamped id made every save a fresh row, leaving parents looking at
  /// two different marks for the same test.
  String _markId(String studentId) {
    String slug(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    return '${studentId}_${slug(_subject!)}_${slug(_testNameC.text.trim())}_'
        '${MarkSheet.dayKey(_sheetDate)}';
  }

  Future<void> _save() async {
    if (_blocker != null || _saving) return;
    setState(() => _saving = true);
    final test = _testNameC.text.trim();
    final writes = <Mark>[];
    final removals = <String>[];
    for (final s in _students) {
      final value = _scoreOf(s.id);
      final before = _original[s.id];
      if (value == null || value.isNaN) {
        // Cleared a score that was saved before: the parent must stop seeing
        // it, so the row goes rather than lingering at its old value.
        if (before != null) removals.add(before.id);
        continue;
      }
      if (before != null && before.score == value && before.totalMarks == _outOf!) continue;
      writes.add(Mark(
        id: before?.id ?? _markId(s.id),
        studentId: s.id,
        subject: _subject!,
        score: value,
        totalMarks: _outOf!,
        testType: test,
        date: _sheetDate,
        updatedBy: widget.teacherId,
        examId: _examId,
        // The class the test was sat in. Without it a class test belonged to
        // nobody, so the board could only find it through the current
        // roster — and every mark for a child who had since left the class
        // silently dropped off the sheet.
        classroomId: widget.classroom.id,
      ));
    }

    final repo = context.read<MarkRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (writes.isNotEmpty) await repo.saveMarks(writes);
      if (removals.isNotEmpty) await repo.deleteMarks(removals);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't save — check the internet connection and try again. Your entries are kept."),
      ));
      return;
    }
    if (!mounted) return;
    _savedSomething = true;
    messenger.showSnackBar(SnackBar(content: Text(_savedMessage(writes.length, removals.length))));
    Navigator.pop(context, true);
  }

  String _savedMessage(int written, int removed) {
    if (removed > 0 && written > 0) {
      return 'Updated $written and removed $removed — parents see the corrected sheet now.';
    }
    if (removed > 0) return 'Removed $removed ${removed == 1 ? 'mark' : 'marks'}.';
    return _isEditing
        ? 'Updated $written ${written == 1 ? 'mark' : 'marks'} — parents see the correction now.'
        : 'Saved $written ${written == 1 ? 'mark' : 'marks'} — parents can see them now.';
  }

  Future<void> _confirmDeleteSheet() async {
    final sheet = widget.sheet;
    if (sheet == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${sheet.testType}?'),
        content: Text(
          'This removes all ${sheet.entered} ${sheet.subject} marks for this test. '
          'Parents will stop seeing it. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete test'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final repo = context.read<MarkRepository>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await repo.deleteMarks(sheet.marks.map((m) => m.id).toList());
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't delete — check your connection and try again."),
      ));
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('Deleted ${sheet.testType}')));
    Navigator.pop(context, true);
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isEditing ? 'Discard corrections?' : 'Discard marks?'),
        content: Text(_isEditing
            ? "The changes you've made haven't been saved."
            : "The marks you've typed haven't been saved."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.pop(context, _savedSomething);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing ? '${widget.sheet!.subject} · ${widget.sheet!.testType}' : 'Record marks',
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (_isEditing && !_saving)
              IconButton(
                tooltip: 'Delete this test',
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                onPressed: _confirmDeleteSheet,
              ),
          ],
        ),
        body: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    if (!widget.scope.canEnterMarks) {
      return EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No subject assigned',
        subtitle: widget.scope.marksBlockedReason(_subject ?? '') ??
            "You'll see subjects once the admin places you on this class's timetable.",
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load students",
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_students.isEmpty) {
      return const EmptyState(icon: Icons.groups_outlined, title: 'No students in this class yet');
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              _isEditing ? _sheetHeader() : _setupCard(),
              const SizedBox(height: 16),
              ProgressSectionTitle(
                'Result sheet',
                trailing: '$_entered of ${_students.length} entered',
              ),
              _table(),
              if (_entered > 0) ...[
                const SizedBox(height: 12),
                _summary(),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                child: Text(
                  _isEditing
                      ? 'Change any mark and save. Clearing a box removes that student from this test.'
                      : 'Leave a box empty to skip that student (absent, not yet assessed).',
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceHint(context)),
                ),
              ),
            ],
          ),
        ),
        _saveBar(),
      ],
    );
  }

  Widget _saveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AdminLook.canvasOf(context),
        border: Border(top: BorderSide(color: AppColors.onSurfaceHint(context).withValues(alpha: 0.2))),
      ),
      child: _saving
          ? const SizedBox(height: 52, child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)))
          : SoftPrimaryButton(
              label: _blocker ??
                  (_isEditing
                      ? 'Save $_changed ${_changed == 1 ? 'change' : 'changes'}'
                      : 'Save $_entered ${_entered == 1 ? 'mark' : 'marks'}'),
              icon: _blocker == null ? Icons.check_rounded : null,
              onPressed: _blocker == null ? _save : null,
            ),
    );
  }

  /// Read-only identity of the test being corrected — the teacher changes
  /// scores here, not what the test was.
  Widget _sheetHeader() {
    final sheet = widget.sheet!;
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(sheet.isExam ? Icons.workspace_premium_rounded : Icons.assignment_turned_in_outlined,
                  size: 18, color: sheet.isExam ? AdminLook.gold : AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(sheet.testType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${sheet.subject} · ${widget.classroom.displayName} · ${friendlyDate(sheet.date)} · '
            'out of ${fmtNum(sheet.totalMarks)}',
            style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceMuted(context)),
          ),
          if (sheet.hasMixedTotals) ...[
            const SizedBox(height: 8),
            Text(
              'Some rows were saved out of a different maximum. Saving now puts '
              'every student in this test out of ${fmtNum(_outOf ?? sheet.totalMarks)}.',
              style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.warning),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Out of', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.onSurfaceMuted(context))),
              ),
              SizedBox(
                width: 84,
                child: TextField(
                  controller: _outOfC,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(isDense: true, hintText: 'Max'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.onSurfaceMuted(context))),
      );

  Widget _setupCard() {
    final subjects = widget.scope.subjects;
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(subjects.length == 1 ? 'Subject (the one you teach here)' : 'Subject'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in subjects)
                SelectPill(
                  label: s,
                  selected: _subject == s,
                  onTap: () => setState(() => _subject = s),
                ),
            ],
          ),
          if (widget.exams.isNotEmpty) ...[
            const SizedBox(height: 16),
            _label('Exam'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final exam in widget.exams)
                  SelectPill(
                    label: exam.name,
                    icon: Icons.workspace_premium_rounded,
                    color: AdminLook.gold,
                    selected: _examId == exam.id,
                    onTap: () => setState(() {
                      if (_examId == exam.id) {
                        _examId = '';
                        return;
                      }
                      _examId = exam.id;
                      _testNameC.text = exam.name;
                      if (exam.totalMarks > 0) _outOfC.text = fmtNum(exam.totalMarks);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _examId.isEmpty
                  ? 'Tie this to an exam and parents see it inside that report card.'
                  : 'These marks will appear under this exam in the parent app.',
              style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceHint(context)),
            ),
          ],
          const SizedBox(height: 16),
          _label('Test'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _testPresets)
                SelectPill(
                  label: t,
                  selected: _examId.isEmpty && _testNameC.text.trim() == t,
                  onTap: () => setState(() {
                    _testNameC.text = t;
                    _examId = '';
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _testNameC,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Test name',
              hintText: 'e.g. Unit test 2 — Fractions',
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          _label('Out of'),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in _outOfPresets)
                      SelectPill(
                        label: '$m',
                        selected: _outOf == m.toDouble(),
                        onTap: () => setState(() => _outOfC.text = '$m'),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 76,
                child: TextField(
                  controller: _outOfC,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(isDense: true, hintText: 'Max'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _table() {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(20),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _tableHead(),
          for (var i = 0; i < _students.length; i++) ...[
            Divider(height: 1, color: AppColors.onSurfaceHint(context).withValues(alpha: 0.14)),
            _row(i),
          ],
        ],
      ),
    );
  }

  Widget _tableHead() {
    final style = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
      color: AppColors.onSurfaceMuted(context),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        children: [
          SizedBox(width: 34, child: Text('ROLL', style: style)),
          const SizedBox(width: 8),
          Expanded(child: Text('STUDENT', style: style)),
          SizedBox(width: 84, child: Text('MARKS', textAlign: TextAlign.center, style: style)),
          SizedBox(width: 46, child: Text('%', textAlign: TextAlign.end, style: style)),
        ],
      ),
    );
  }

  Widget _row(int i) {
    final s = _students[i];
    final last = i == _students.length - 1;
    final value = _scoreOf(s.id);
    final invalid = value?.isNaN ?? false;
    final percent = value != null && !value.isNaN && (_outOf ?? 0) > 0 ? (value / _outOf!) * 100 : null;
    final edited = _isEdited(s.id);

    return Container(
      color: edited ? AppColors.accent.withValues(alpha: 0.05) : null,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              s.rollNumber.isEmpty ? '—' : s.rollNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceMuted(context)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                  ),
                ),
                if (edited) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 84,
            child: TextField(
              controller: _scoreC[s.id],
              focusNode: _focus[s.id],
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              textInputAction: last ? TextInputAction.done : TextInputAction.next,
              onSubmitted: (_) {
                if (!last) _focus[_students[i + 1].id]?.requestFocus();
              },
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: '—',
                errorText: invalid ? 'Max ${fmtNum(_outOf ?? 0)}' : null,
                errorMaxLines: 1,
              ),
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              percent == null ? '—' : '${percent.round()}',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: percent == null ? AppColors.onSurfaceHint(context) : gradeColor(percent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    final scores = [
      for (final s in _students)
        if (_scoreOf(s.id) case final v? when !v.isNaN) v,
    ];
    if (scores.isEmpty || (_outOf ?? 0) <= 0) return const SizedBox.shrink();
    final max = _outOf!;
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    final high = scores.reduce((a, b) => a > b ? a : b);
    final low = scores.reduce((a, b) => a < b ? a : b);
    return SoftSurface(
      depth: SoftDepth.none,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          _stat('Average', '${fmtNum(avg)} / ${fmtNum(max)}', gradeColor(avg / max * 100)),
          _stat('Highest', fmtNum(high), AppColors.success),
          _stat('Lowest', fmtNum(low), gradeColor(low / max * 100)),
          _stat('Entered', '${scores.length}/${_students.length}', AppColors.onSurfaceMuted(context)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: AppColors.onSurfaceHint(context))),
        ],
      ),
    );
  }
}
