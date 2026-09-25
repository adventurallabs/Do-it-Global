import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import '../progress/progress_widgets.dart' show sortedRoster;

/// One section's results for one exam paper.
///
/// What each row asks for follows the exam: a mark, a grade, or both. Grades
/// are only ever picked from the exam's scale — never typed — and a
/// grades-only exam has no marks box at all.
///
/// Save keeps a draft the teacher can come back to — part-filled is fine.
/// Submit needs every student complete (or AB), then locks the sheet and
/// releases it to parents and the admin. The database enforces all of it.
class ExamMarksEntryScreen extends StatefulWidget {
  final String teacherId;
  final Exam exam;
  final ExamPaper paper;
  final Classroom classroom;

  const ExamMarksEntryScreen({
    super.key,
    required this.teacherId,
    required this.exam,
    required this.paper,
    required this.classroom,
  });

  /// Returns true when anything was saved or submitted.
  static Future<bool?> open(
    BuildContext context, {
    required String teacherId,
    required Exam exam,
    required ExamPaper paper,
    required Classroom classroom,
  }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ExamMarksEntryScreen(teacherId: teacherId, exam: exam, paper: paper, classroom: classroom),
      ),
    );
  }

  @override
  State<ExamMarksEntryScreen> createState() => _ExamMarksEntryScreenState();
}

class _ExamMarksEntryScreenState extends State<ExamMarksEntryScreen> {
  List<Student> _students = const [];
  final Map<String, TextEditingController> _c = {};
  final Map<String, FocusNode> _focus = {};
  final Map<String, GlobalKey> _rowKeys = {};
  final Map<String, String?> _grade = {};

  /// Absent, for a grades-only exam (no marks box to type AB into).
  final Set<String> _absent = {};

  /// Grades the app filled in from the mark — they follow the mark until the
  /// teacher picks one by hand.
  final Set<String> _autoGrade = {};
  final _scroll = ScrollController();

  // Rough sizes, only used to jump near a row the lazy list hasn't built.
  static const double _headerExtent = 230;
  static const double _rowExtent = 64;
  final Map<String, Mark> _saved = {};
  ExamMarkSheet? _sheet;
  bool _loading = true;
  bool _error = false;
  bool _busy = false;
  bool _wrote = false;
  bool _showMissing = false;

  ExamPaper get _paper => widget.paper;

  // Two inputs per row on a phone: everything gets narrower so the name keeps
  // its room.
  bool get _both => _mode == ExamResultMode.marksAndGrades;
  double get _rollW => _both ? 34 : 44;
  double get _markW => _both ? 60 : 76;
  double get _gradeW => _both ? 64 : 88;
  double get _abW => _both ? 40 : 46;
  /// Re-read on open: the list screens cache for a few seconds, and the
  /// result type must be the exam's current one, not a stale copy.
  late Exam _exam = widget.exam;
  ExamResultMode get _mode => _exam.resultMode;
  List<GradeBand> get _scale => _exam.gradeScale;
  bool get _locked => _sheet?.isSubmitted == true;
  bool get _suggests => _mode == ExamResultMode.marksAndGrades && GradeScale.isBanded(_scale);

  String get _noun => switch (_mode) {
        ExamResultMode.marks => 'marks',
        ExamResultMode.grades => 'grades',
        ExamResultMode.marksAndGrades => 'results',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _scroll.dispose();
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
      final repo = context.read<ExamRepository>();
      final (students, marks, sheet, exam) = await (
        context.read<StudentRepository>().getByClassroom(widget.classroom.id, strict: true),
        repo.paperMarks(_paper.id, widget.classroom.id),
        repo.sheet(_paper.id, widget.classroom.id),
        repo.getById(widget.exam.id),
      ).wait;
      if (!mounted) return;
      if (exam != null) _exam = exam;
      _saved
        ..clear()
        ..addAll({for (final m in marks) m.studentId: m});
      final roster = sortedRoster(students);
      _grade.clear();
      _absent.clear();
      _autoGrade.clear();
      for (final s in roster) {
        final m = _saved[s.id];
        (_c[s.id] ??= TextEditingController()).text = ResultInput.markTextOf(m, _mode);
        _focus[s.id] ??= FocusNode();
        _rowKeys[s.id] ??= GlobalKey();
        _grade[s.id] = m?.isAbsent == true ? null : m?.grade;
        if (m?.isAbsent == true && !_mode.usesMarks) _absent.add(s.id);
      }
      setState(() {
        _students = roster;
        _sheet = sheet;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  ResultInput _input(String studentId) => ResultInput.read(
        mode: _mode,
        markText: _c[studentId]?.text ?? '',
        grade: _grade[studentId],
        absentFlag: _absent.contains(studentId),
        max: _paper.maxMarks,
        scale: _scale,
      );

  int get _filled => _students.where((s) => _input(s.id).isComplete(_mode)).length;
  int get _invalid => _students.where((s) => _input(s.id).error != null).length;

  /// Compared by value, so "85.0" over a saved 85 isn't an unsaved change.
  bool get _dirty => _students.any((s) => !_input(s.id).matches(_saved[s.id], _mode));

  String? _suggestionFor(String studentId) {
    if (!_suggests) return null;
    final e = MarkEntry.parse(_c[studentId]?.text ?? '', _paper.maxMarks);
    if (e.score == null) return null;
    return GradeScale.gradeFor(_scale, e.score! / _paper.maxMarks * 100);
  }

  void _markChanged(String studentId) {
    if (_suggests && (_grade[studentId] == null || _autoGrade.contains(studentId))) {
      final g = _suggestionFor(studentId);
      _grade[studentId] = g;
      if (g == null) {
        _autoGrade.remove(studentId);
      } else {
        _autoGrade.add(studentId);
      }
    }
    setState(() {});
  }

  void _toggleAbsent(Student s) {
    final absentNow = _input(s.id).absent;
    setState(() {
      if (_mode.usesMarks) {
        _c[s.id]!.text = absentNow ? '' : 'AB';
      } else if (absentNow) {
        _absent.remove(s.id);
      } else {
        _absent.add(s.id);
      }
      if (!absentNow) {
        _grade[s.id] = null;
        _autoGrade.remove(s.id);
      }
    });
    HapticFeedback.selectionClick();
  }

  /// Opens the grade sheet for a student. In a grades-only exam, picking a
  /// grade moves straight on to the next student still without one — a
  /// class of forty is forty taps, not forty open-and-close round trips.
  Future<void> _pickGrade(int index) async {
    final s = _students[index];
    final input = _input(s.id);
    final choice = await showGradePicker(
      context,
      bands: _scale,
      title: s.name,
      subtitle: 'Roll ${s.rollNumber.isEmpty ? '—' : s.rollNumber} · ${_paper.subject}'
          '${_mode.usesMarks && input.score != null ? ' · ${fmtMark(input.score!)}/${fmtMark(_paper.maxMarks)}' : ''}',
      current: _grade[s.id],
      currentAbsent: input.absent,
      suggested: _suggestionFor(s.id),
    );
    if (choice == null || !mounted) return;
    setState(() {
      _autoGrade.remove(s.id);
      if (choice.absent) {
        _grade[s.id] = null;
        if (_mode.usesMarks) {
          _c[s.id]!.text = 'AB';
        } else {
          _absent.add(s.id);
        }
      } else if (choice.isCleared) {
        _grade[s.id] = null;
        _absent.remove(s.id);
      } else {
        _absent.remove(s.id);
        if (_mode.usesMarks && MarkEntry.parse(_c[s.id]!.text, _paper.maxMarks).absent) _c[s.id]!.text = '';
        _grade[s.id] = choice.grade;
      }
    });
    if (_mode == ExamResultMode.grades && !choice.isCleared) {
      final next = _students.indexWhere((x) => !_input(x.id).isComplete(_mode), index + 1);
      if (next > index) {
        _scrollToIndex(next, focus: false);
        await Future<void>.delayed(const Duration(milliseconds: 180));
        if (mounted) _pickGrade(next);
      }
    }
  }

  /// Writes what's on screen. Returns false (and says why) on failure.
  Future<bool> _persist() async {
    final marks = <Mark>[];
    final cleared = <String>[];
    for (final s in _students) {
      final i = _input(s.id);
      final before = _saved[s.id];
      if (i.isEmpty) {
        if (before != null) cleared.add(before.id);
        continue;
      }
      // A half-filled marks & grades row is kept on screen, not saved.
      if (!i.isComplete(_mode)) continue;
      if (i.matches(before, _mode)) continue;
      marks.add(Mark(
        id: before?.id ?? ExamRepository.markId(_paper.id, s.id),
        studentId: s.id,
        subject: _paper.subject,
        score: i.score ?? 0,
        totalMarks: _mode.usesMarks ? _paper.maxMarks : 0,
        testType: widget.exam.name,
        date: _paper.examDate,
        updatedBy: widget.teacherId,
        examId: widget.exam.id,
        paperId: _paper.id,
        classroomId: widget.classroom.id,
        isAbsent: i.absent,
        grade: i.grade,
      ));
    }
    try {
      await context.read<ExamRepository>().saveDraft(
            paper: _paper,
            classroomId: widget.classroom.id,
            teacherId: widget.teacherId,
            marks: marks,
            clearedIds: cleared,
            enteredCount: _filled,
          );
      for (final m in marks) {
        _saved[m.studentId] = m;
      }
      _saved.removeWhere((_, m) => cleared.contains(m.id));
      _wrote = true;
      return true;
    } catch (e) {
      if (mounted) _fail(ExamRepository.describeError(e));
      return false;
    }
  }

  void _fail(String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final bad = _students.where((s) {
      final i = _input(s.id);
      // A marks & grades row missing its other half is still worth saving
      // later — only a malformed value blocks a draft.
      return i.error != null && !(i.error == 'Pick a grade' || i.error == 'Enter the mark');
    }).length;
    if (bad > 0) {
      _fail('$bad ${bad == 1 ? 'entry needs' : 'entries need'} fixing — see the rows in red.');
      _scrollToFirst((s) => _input(s.id).error != null);
      return;
    }
    setState(() => _busy = true);
    final ok = await _persist();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      HapticFeedback.lightImpact();
      final half = _students.where((s) => _input(s.id).error != null).length;
      showSavedToast(
        context,
        title: '${_noun[0].toUpperCase()}${_noun.substring(1)} saved',
        subtitle: half > 0
            ? '$_filled of ${_students.length} complete. $half row${half == 1 ? ' needs' : 's need'} both a mark and a grade before it is saved.'
            : '$_filled of ${_students.length} entered. You can keep editing until you submit.',
      );
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final missing = _students.where((s) => !_input(s.id).isComplete(_mode)).toList();
    if (missing.isNotEmpty) {
      setState(() => _showMissing = true);
      final what = switch (_mode) {
        ExamResultMode.marks => 'no mark',
        ExamResultMode.grades => 'no grade',
        ExamResultMode.marksAndGrades => 'a missing mark or grade',
      };
      _fail(_invalid > 0 && _mode == ExamResultMode.marks
          ? '$_invalid mark${_invalid == 1 ? ' needs' : 's need'} fixing before you can submit.'
          : '${missing.length} student${missing.length == 1 ? ' has' : 's have'} $what. Tap AB for anyone absent.');
      _scrollToFirst((s) => !_input(s.id).isComplete(_mode));
      return;
    }
    final inputs = [for (final s in _students) _input(s.id)];
    final absent = inputs.where((i) => i.absent).length;
    final failed = inputs.where((i) {
      if (i.absent) return false;
      if (_mode == ExamResultMode.grades) return i.grade != null && !GradeScale.isPass(_scale, i.grade!);
      return (i.score ?? 0) < _paper.passMarks;
    }).length;
    final ok = await confirmExamAction(
      context,
      title: 'Submit ${_paper.subject} $_noun?',
      message: 'Once submitted you can\'t change these $_noun. Parents and the admin will see them straight away. '
          'Only the admin can make a correction after this.',
      confirmLabel: 'Submit & lock',
      icon: Icons.lock_outline_rounded,
      color: AppColors.warning,
      bullets: [
        '${_students.length} students · ${widget.classroom.displayName}',
        if (absent > 0) '$absent marked absent (AB)',
        if (failed > 0)
          _mode == ExamResultMode.grades
              ? '$failed with a failing grade'
              : '$failed below the pass mark of ${fmtMark(_paper.passMarks)}',
      ],
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final saved = await _persist();
    if (!saved || !mounted) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      await context.read<ExamRepository>().submit(_paper.id, widget.classroom.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final sheet = await context.read<ExamRepository>().sheet(_paper.id, widget.classroom.id);
      if (!mounted) return;
      setState(() {
        _sheet = sheet;
        _busy = false;
      });
      showSavedToast(
        context,
        title: '${_noun[0].toUpperCase()}${_noun.substring(1)} submitted',
        subtitle: 'Shared with parents and the admin.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _fail(ExamRepository.describeError(e));
    }
  }

  void _scrollToFirst(bool Function(Student) test) {
    final index = _students.indexWhere(test);
    if (index >= 0) _scrollToIndex(index, focus: _mode.usesMarks);
  }

  void _scrollToIndex(int index, {required bool focus}) {
    final s = _students[index];
    final ctx = _rowKeys[s.id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.3);
    } else if (_scroll.hasClients) {
      // The row is off-screen and not built yet (the list is lazy): jump
      // near it, then let ensureVisible settle it exactly once it exists.
      final target = (_headerExtent + index * _rowExtent - 120).clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.jumpTo(target);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final built = _rowKeys[s.id]?.currentContext;
        if (built != null && mounted) {
          Scrollable.ensureVisible(built, duration: const Duration(milliseconds: 250), alignment: 0.3);
        }
      });
    }
    if (focus) {
      Future<void>.delayed(const Duration(milliseconds: 340), () {
        if (mounted) _focus[s.id]?.requestFocus();
      });
    }
  }

  Future<bool> _confirmLeave() async {
    if (_locked || !_dirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Save before leaving?'),
        content: Text('You have $_noun that aren\'t saved yet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, 'discard'), child: const Text('Discard')),
          TextButton(onPressed: () => Navigator.pop(d, 'stay'), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(d, 'save'), child: const Text('Save')),
        ],
      ),
    );
    if (choice == 'discard') return true;
    if (choice == 'save') {
      if (_students.any((s) {
        final e = _input(s.id).error;
        return e != null && e != 'Pick a grade' && e != 'Enter the mark';
      })) {
        if (mounted) _fail('Fix the rows in red first.');
        return false;
      }
      return _persist();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Always handled here so the caller learns whether anything was written.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) navigator.pop(_wrote);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () async {
            final navigator = Navigator.of(context);
            if (await _confirmLeave()) navigator.pop(_wrote);
          }),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_paper.subject} · ${widget.classroom.displayName}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Text('${widget.exam.name} · ${_mode.label}',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.onSurfaceMuted(context))),
            ],
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error
                  ? EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: "Couldn't load the class",
                      subtitle: 'Check your connection and try again.',
                      actionLabel: 'Retry',
                      onAction: _load,
                    )
                  : Column(
                      children: [
                        Expanded(child: _list()),
                      ],
                    ),
        ),
        bottomNavigationBar: !_loading && !_error && !_locked && _students.isNotEmpty
            ? StickyActionBar(child: _bottomBar())
            : null,
      ),
    );
  }

  Widget _list() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _students.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            children: [
              _PaperHeader(paper: _paper, sheet: _sheet, mode: _mode, scale: _scale, noun: _noun),
              const SizedBox(height: 12),
              if (_students.isEmpty)
                const SizedBox(
                  height: 260,
                  child: EmptyState(icon: Icons.groups_outlined, title: 'No students in this class'),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                  child: Row(
                    children: [
                      SizedBox(width: _rollW, child: Text('ROLL', style: _headStyle(context))),
                      Expanded(child: Text('STUDENT', style: _headStyle(context))),
                      if (_mode.usesMarks)
                        SizedBox(
                          width: _markW,
                          child: Text('/ ${fmtMark(_paper.maxMarks)}', style: _headStyle(context), textAlign: TextAlign.center),
                        ),
                      if (_mode.usesGrades) ...[
                        const SizedBox(width: 6),
                        SizedBox(width: _gradeW, child: Text('GRADE', style: _headStyle(context), textAlign: TextAlign.center)),
                      ],
                      SizedBox(width: _abW + 6),
                    ],
                  ),
                ),
            ],
          );
        }
        return _row(i - 1);
      },
    );
  }

  Widget _row(int index) {
    final s = _students[index];
    final input = _input(s.id);
    final missing = _showMissing && !input.isComplete(_mode);
    final bad = input.error != null && (_showMissing || !(input.error == 'Pick a grade' || input.error == 'Enter the mark'));
    final isLast = index == _students.length - 1;
    final mute = AppColors.onSurfaceMuted(context);
    final failing = !input.absent &&
        ((_mode == ExamResultMode.grades && input.grade != null && !GradeScale.isPass(_scale, input.grade!)) ||
            (_mode.usesMarks && input.score != null && input.score! < _paper.passMarks));
    String? note;
    Color noteColor = mute;
    if (bad) {
      note = input.error;
      noteColor = AppColors.error;
    } else if (input.absent) {
      note = 'Absent';
      noteColor = AppColors.warning;
    } else if (missing) {
      note = _mode == ExamResultMode.grades ? 'Needs a grade or AB' : 'Needs a mark or AB';
      noteColor = AppColors.error;
    } else if (failing) {
      note = _mode == ExamResultMode.grades ? 'Failing grade' : 'Below pass mark';
    } else if (_autoGrade.contains(s.id)) {
      note = 'Grade from the mark';
    }
    return Padding(
      key: _rowKeys[s.id],
      padding: const EdgeInsets.only(bottom: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: bad || missing ? AppColors.error.withValues(alpha: 0.06) : AppColors.onSurface(context).withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bad || missing ? AppColors.error.withValues(alpha: 0.5) : Colors.transparent),
        ),
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          children: [
            SizedBox(
              width: _rollW,
              child: Text(
                s.rollNumber.isEmpty ? '—' : s.rollNumber,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.accent),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                  if (note != null) Text(note, style: TextStyle(fontSize: 11, color: noteColor)),
                ],
              ),
            ),
            if (_mode.usesMarks)
              SizedBox(
                width: _markW,
                child: TextField(
                  controller: _c[s.id],
                  focusNode: _focus[s.id],
                  enabled: !_locked && !_busy,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  // Number pad for speed; absence goes through the AB button
                  // (typing AB still works where the keyboard allows).
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.aAbB]')),
                    LengthLimitingTextInputFormatter(5),
                  ],
                  onChanged: (_) => _markChanged(s.id),
                  onSubmitted: (_) {
                    if (!isLast) _focus[_students[index + 1].id]?.requestFocus();
                  },
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '—',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: bad && input.error != 'Pick a grade' ? AppColors.error : AppColors.divider,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accent, width: 1.8),
                    ),
                  ),
                ),
              ),
            if (_mode.usesGrades) ...[
              const SizedBox(width: 6),
              GradeCell(
                grade: input.absent ? null : _grade[s.id],
                absent: input.absent,
                failing: input.grade != null && !GradeScale.isPass(_scale, input.grade!),
                missing: (missing || (bad && input.error == 'Pick a grade')) && !input.absent,
                enabled: !_locked && !_busy,
                onTap: () => _pickGrade(index),
                width: _gradeW,
              ),
            ],
            const SizedBox(width: 6),
            SizedBox(
              width: _abW,
              child: _locked
                  ? const SizedBox.shrink()
                  : TextButton(
                      onPressed: _busy ? null : () => _toggleAbsent(s),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size(_abW, 40),
                        backgroundColor: input.absent ? AppColors.warning.withValues(alpha: 0.16) : null,
                        foregroundColor: input.absent ? AppColors.warning : AppColors.onSurfaceHint(context),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('AB', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _headStyle(BuildContext context) => TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
        color: AppColors.onSurfaceHint(context),
      );

  Widget _bottomBar() {
    final filled = _filled;
    final total = _students.length;
    final complete = filled == total;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '$filled of $total done',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: complete ? AppColors.success : AppColors.onSurfaceMuted(context),
                ),
              ),
              const Spacer(),
              if (_dirty)
                const Text('Unsaved changes', style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : filled / total,
              minHeight: 5,
              color: complete ? AppColors.success : AppColors.accent,
              backgroundColor: AppColors.accent.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _save,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                  icon: const Icon(Icons.save_outlined, size: 19),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.lock_outline_rounded, size: 19),
                  label: const Text('Submit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaperHeader extends StatelessWidget {
  final ExamPaper paper;
  final ExamMarkSheet? sheet;
  final ExamResultMode mode;
  final List<GradeBand> scale;
  final String noun;
  const _PaperHeader({required this.paper, required this.sheet, required this.mode, required this.scale, required this.noun});

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    final locked = sheet?.isSubmitted == true;
    final howTo = switch (mode) {
      ExamResultMode.marks => 'Type a mark, or tap AB for a student who was absent.',
      ExamResultMode.grades => 'Tap Grade to pick one — it moves on to the next student by itself. Tap AB for anyone absent.',
      ExamResultMode.marksAndGrades => GradeScale.isBanded(scale)
          ? 'Type the mark — the grade fills in from it, and you can change it. Tap AB for anyone absent.'
          : 'Type the mark and pick a grade for each student. Tap AB for anyone absent.',
    };
    return Column(
      children: [
        SoftSurface(
          depth: SoftDepth.two,
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ExamDates.long(paper.examDate), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(paper.timeLabel, style: TextStyle(fontSize: 12.5, color: mute)),
                  ],
                ),
              ),
              if (mode.usesMarks) ...[
                _Stat(label: 'Out of', value: fmtMark(paper.maxMarks)),
                const SizedBox(width: 16),
                _Stat(label: 'Pass', value: fmtMark(paper.passMarks)),
              ] else
                _Stat(label: 'Grades', value: '${scale.length}'),
            ],
          ),
        ),
        if (mode.usesGrades) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final b in scale)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (b.pass ? AppColors.accent : AppColors.error).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      b.min == null ? b.label : '${b.label} ${fmtMark(b.min!)}%+',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: b.pass ? AppColors.onSurface(context) : AppColors.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          decoration: BoxDecoration(
            color: (locked ? AppColors.success : AppColors.examCard).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(locked ? Icons.lock_rounded : Icons.info_outline_rounded,
                  size: 18, color: locked ? AppColors.success : AppColors.examCard),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  locked
                      ? 'Submitted${sheet?.submittedAt == null ? '' : ' on ${ExamDates.short(sheet!.submittedAt!.toLocal())}'}. '
                          'These $noun are locked — ask the admin if something needs correcting.'
                      : '$howTo Save as often as you like; Submit when every student is done.',
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.onSurface(context)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted(context))),
      ],
    );
  }
}
