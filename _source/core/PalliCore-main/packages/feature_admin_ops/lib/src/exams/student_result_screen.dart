import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

/// One student's result in one exam, subject by subject, as a mark statement.
/// The admin can correct any of them — including after the teacher has
/// submitted, which is exactly when a correction usually turns up.
///
/// Columns follow what the exam records: marks, grades, or both.
class StudentResultScreen extends StatefulWidget {
  final Exam exam;
  final Classroom classroom;
  final Student student;
  final List<ExamPaper> papers;
  final List<ExamMarkSheet> sheets;
  final List<Mark> marks;

  const StudentResultScreen({
    super.key,
    required this.exam,
    required this.classroom,
    required this.student,
    required this.papers,
    required this.sheets,
    required this.marks,
  });

  /// Returns true when marks were changed.
  static Future<bool?> open(
    BuildContext context, {
    required Exam exam,
    required Classroom classroom,
    required Student student,
    required List<ExamPaper> papers,
    required List<ExamMarkSheet> sheets,
    required List<Mark> marks,
  }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StudentResultScreen(
          exam: exam,
          classroom: classroom,
          student: student,
          papers: papers,
          sheets: sheets,
          marks: marks,
        ),
      ),
    );
  }

  @override
  State<StudentResultScreen> createState() => _StudentResultScreenState();
}

class _StudentResultScreenState extends State<StudentResultScreen> {
  late Map<String, Mark> _byPaper = {
    for (final m in widget.marks)
      if (m.paperId != null) m.paperId!: m,
  };
  final Map<String, TextEditingController> _c = {};
  final Map<String, String?> _grade = {};
  final Set<String> _absent = {};
  bool _editing = false;
  bool _saving = false;
  bool _changed = false;

  ExamResultMode get _mode => widget.exam.resultMode;
  List<GradeBand> get _scale => widget.exam.gradeScale;
  List<ExamPaper> get _papers => [...widget.papers]..sort(ExamPaper.compare);

  ExamMarkSheet? _sheetOf(String paperId) {
    for (final s in widget.sheets) {
      if (s.paperId == paperId) return s;
    }
    return null;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _startEdit() {
    _grade.clear();
    _absent.clear();
    for (final p in _papers) {
      final m = _byPaper[p.id];
      (_c[p.id] ??= TextEditingController()).text = ResultInput.markTextOf(m, _mode);
      _grade[p.id] = m?.isAbsent == true ? null : m?.grade;
      if (m?.isAbsent == true && !_mode.usesMarks) _absent.add(p.id);
    }
    setState(() => _editing = true);
  }

  ResultInput _input(ExamPaper p) => ResultInput.read(
        mode: _mode,
        markText: _c[p.id]?.text ?? '',
        grade: _grade[p.id],
        absentFlag: _absent.contains(p.id),
        max: p.maxMarks,
        scale: _scale,
      );

  void _markChanged(ExamPaper p) {
    // Keep the grade in step with the mark on a percentage scale, until the
    // admin picks one by hand.
    if (_mode == ExamResultMode.marksAndGrades && GradeScale.isBanded(_scale)) {
      final e = MarkEntry.parse(_c[p.id]!.text, p.maxMarks);
      if (e.score != null) _grade[p.id] = GradeScale.gradeFor(_scale, e.score! / p.maxMarks * 100);
    }
    setState(() {});
  }

  Future<void> _pickGrade(ExamPaper p) async {
    final e = MarkEntry.parse(_c[p.id]?.text ?? '', p.maxMarks);
    final choice = await showGradePicker(
      context,
      bands: _scale,
      title: p.subject,
      subtitle: widget.student.name,
      current: _grade[p.id],
      currentAbsent: _input(p).absent,
      suggested: e.score == null ? null : GradeScale.gradeFor(_scale, e.score! / p.maxMarks * 100),
    );
    if (choice == null || !mounted) return;
    setState(() {
      if (choice.absent) {
        _grade[p.id] = null;
        if (_mode.usesMarks) {
          _c[p.id]!.text = 'AB';
        } else {
          _absent.add(p.id);
        }
      } else {
        _absent.remove(p.id);
        if (_mode.usesMarks && MarkEntry.parse(_c[p.id]!.text, p.maxMarks).absent) _c[p.id]!.text = '';
        _grade[p.id] = choice.grade;
      }
    });
  }

  Future<void> _save() async {
    final inputs = {for (final p in _papers) p.id: _input(p)};
    // Blank rows are fine (they remove the mark); half-filled ones are not.
    if (inputs.values.any((i) => i.error != null)) {
      HapticFeedback.heavyImpact();
      setState(() {});
      return;
    }
    final upserts = <Mark>[];
    final cleared = <String>[];
    for (final p in _papers) {
      final i = inputs[p.id]!;
      final before = _byPaper[p.id];
      if (i.isEmpty) {
        if (before != null) cleared.add(before.id);
        continue;
      }
      if (i.matches(before, _mode)) continue;
      upserts.add(Mark(
        id: before?.id ?? ExamRepository.markId(p.id, widget.student.id),
        studentId: widget.student.id,
        subject: p.subject,
        score: i.score ?? 0,
        totalMarks: _mode.usesMarks ? p.maxMarks : 0,
        testType: widget.exam.name,
        date: p.examDate,
        updatedBy: 'admin',
        examId: widget.exam.id,
        paperId: p.id,
        classroomId: widget.classroom.id,
        isAbsent: i.absent,
        grade: i.grade,
      ));
    }
    if (upserts.isEmpty && cleared.isEmpty) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<ExamRepository>().saveStudentMarks(upserts: upserts, clearedIds: cleared);
      if (!mounted) return;
      setState(() {
        _byPaper = {..._byPaper}..removeWhere((_, m) => cleared.contains(m.id));
        for (final m in upserts) {
          _byPaper[m.paperId!] = m;
        }
        _editing = false;
        _saving = false;
        _changed = true;
      });
      showSavedToast(context, title: 'Result updated', subtitle: '${widget.student.name} · ${widget.exam.name}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ExamRepository.describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final papers = _papers;
    final result = StudentExamResult.build(
      studentId: widget.student.id,
      papers: papers,
      marks: _byPaper.values,
      isReleased: (_) => true, // the admin reads every mark, draft or not
      mode: _mode,
      scale: _scale,
    );
    final hint = TextStyle(fontSize: 12, height: 1.4, color: AppColors.onSurfaceHint(context));
    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) setState(() => _editing = false);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => _editing ? setState(() => _editing = false) : Navigator.pop(context, _changed)),
          title: Text(_editing ? 'Edit result' : 'Mark statement'),
          actions: [
            if (!_editing && papers.isNotEmpty)
              TextButton.icon(onPressed: _startEdit, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _StudentHeader(student: widget.student, classroom: widget.classroom, exam: widget.exam),
                    const SizedBox(height: 14),
                    SoftSurface(
                      depth: SoftDepth.one,
                      borderRadius: BorderRadius.circular(18),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          _HeaderRow(mode: _mode),
                          const Divider(height: 1),
                          for (var i = 0; i < papers.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.divider.withValues(alpha: 0.6)),
                            _editing
                                ? _EditRow(
                                    paper: papers[i],
                                    mode: _mode,
                                    scale: _scale,
                                    controller: _c[papers[i].id]!,
                                    input: _input(papers[i]),
                                    onMarkChanged: () => _markChanged(papers[i]),
                                    onPickGrade: () => _pickGrade(papers[i]),
                                  )
                                : _ReadRow(row: result.subjects[i], sheet: _sheetOf(papers[i].id), mode: _mode),
                          ],
                          if (_mode.usesMarks || result.isComplete) ...[
                            const Divider(height: 1),
                            _TotalRow(result: result),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _editing
                          ? switch (_mode) {
                              ExamResultMode.marks =>
                                'Type a mark, AB for absent, or clear the box to remove it. Changes to submitted subjects are shared immediately.',
                              ExamResultMode.grades =>
                                'Tap a grade to change it — pick Absent or Clear there too. Changes to submitted subjects are shared immediately.',
                              ExamResultMode.marksAndGrades =>
                                'Enter both the mark and the grade (AB in the mark box for absent). Changes to submitted subjects are shared immediately.',
                            }
                          : 'Draft entries are shown for your reference. Parents only see a subject once its teacher submits it.',
                      style: hint,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: !_editing
            ? null
            : StickyActionBar(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => setState(() => _editing = false),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_rounded),
                          label: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _StudentHeader extends StatelessWidget {
  final Student student;
  final Classroom classroom;
  final Exam exam;
  const _StudentHeader({required this.student, required this.classroom, required this.exam});

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    Widget cell(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: AppColors.onSurfaceHint(context))),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            ],
          ),
        );
    return SoftSurface(
      depth: SoftDepth.two,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(student.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          Text('${exam.name} · ${exam.resultMode.label}', style: TextStyle(fontSize: 13, color: mute)),
          const SizedBox(height: 12),
          Row(
            children: [
              cell('Roll no.', student.rollNumber.isEmpty ? '—' : student.rollNumber),
              cell('Register no.', student.admissionNo.isEmpty ? '—' : student.admissionNo),
              cell('Class', classroom.displayName),
            ],
          ),
        ],
      ),
    );
  }
}

const _maxW = 44.0;
const _passW = 40.0;
const _marksW = 62.0;
const _gradeW = 66.0;
const _resultW = 54.0;

class _HeaderRow extends StatelessWidget {
  final ExamResultMode mode;
  const _HeaderRow({required this.mode});

  @override
  Widget build(BuildContext context) {
    final s = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: AppColors.onSurfaceHint(context));
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          Expanded(child: Text('SUBJECT', style: s)),
          if (mode.usesMarks) SizedBox(width: _maxW, child: Text('MAX', style: s, textAlign: TextAlign.center)),
          if (mode == ExamResultMode.marks) SizedBox(width: _passW, child: Text('PASS', style: s, textAlign: TextAlign.center)),
          if (mode.usesMarks) SizedBox(width: _marksW, child: Text('MARKS', style: s, textAlign: TextAlign.center)),
          if (mode.usesGrades) SizedBox(width: _gradeW, child: Text('GRADE', style: s, textAlign: TextAlign.center)),
          SizedBox(width: _resultW, child: Text('RESULT', style: s, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _ReadRow extends StatelessWidget {
  final SubjectResult row;
  final ExamMarkSheet? sheet;
  final ExamResultMode mode;
  const _ReadRow({required this.row, required this.sheet, required this.mode});

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    final mark = row.mark;
    final draft = mark != null && sheet?.isSubmitted != true;
    final outcome = row.outcome;
    final color = outcomeColor(outcome, context);
    final valueStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: draft ? AppColors.warning : null);
    final absent = mark?.isAbsent == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.paper.subject, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  sheet?.isSubmitted == true
                      ? 'Submitted'
                      : mark == null
                          ? 'Not entered'
                          : 'Draft — not shared',
                  style: TextStyle(fontSize: 11, color: draft ? AppColors.warning : mute),
                ),
              ],
            ),
          ),
          if (mode.usesMarks)
            SizedBox(width: _maxW, child: Text(fmtMark(row.paper.maxMarks), textAlign: TextAlign.center, style: TextStyle(color: mute))),
          if (mode == ExamResultMode.marks)
            SizedBox(width: _passW, child: Text(fmtMark(row.paper.passMarks), textAlign: TextAlign.center, style: TextStyle(color: mute))),
          if (mode.usesMarks)
            SizedBox(
              width: _marksW,
              child: Text(
                mark == null ? '—' : (absent ? 'AB' : fmtMark(mark.score)),
                textAlign: TextAlign.center,
                style: valueStyle,
              ),
            ),
          if (mode.usesGrades)
            SizedBox(
              width: _gradeW,
              child: Text(
                mark == null ? '—' : (absent ? 'AB' : (mark.grade ?? '—')),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: valueStyle.copyWith(fontSize: (mark?.grade?.length ?? 0) > 4 ? 12 : 16),
              ),
            ),
          SizedBox(
            width: _resultW,
            child: Text(
              mark == null ? '' : outcome.label,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  final ExamPaper paper;
  final ExamResultMode mode;
  final List<GradeBand> scale;
  final TextEditingController controller;
  final ResultInput input;
  final VoidCallback onMarkChanged;
  final VoidCallback onPickGrade;

  const _EditRow({
    required this.paper,
    required this.mode,
    required this.scale,
    required this.controller,
    required this.input,
    required this.onMarkChanged,
    required this.onPickGrade,
  });

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    final bad = input.error != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(paper.subject, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                if (bad) Text(input.error!, style: const TextStyle(fontSize: 11, color: AppColors.error)),
                if (mode.usesMarks)
                  Text('out of ${fmtMark(paper.maxMarks)}', style: TextStyle(fontSize: 11, color: mute)),
              ],
            ),
          ),
          if (mode.usesMarks)
            SizedBox(
              width: 72,
              child: TextField(
                controller: controller,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.visiblePassword,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.aAbB]')), LengthLimitingTextInputFormatter(5)],
                onChanged: (_) => onMarkChanged(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '—',
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: bad ? AppColors.error : AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: bad ? AppColors.error : AppColors.accent, width: 1.6),
                  ),
                ),
              ),
            ),
          if (mode.usesGrades) ...[
            const SizedBox(width: 8),
            GradeCell(
              grade: input.absent ? null : input.grade,
              absent: input.absent,
              failing: input.grade != null && !GradeScale.isPass(scale, input.grade!),
              missing: bad && input.grade == null && !input.absent,
              onTap: onPickGrade,
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final StudentExamResult result;
  const _TotalRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final overall = result.overall;
    final color = outcomeColor(overall, context);
    final usesMarks = result.mode.usesMarks;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(usesMarks ? 'TOTAL' : 'OVERALL', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                Text(
                  !result.isComplete
                      ? '${result.awaitedCount} subject${result.awaitedCount == 1 ? '' : 's'} not entered'
                      : usesMarks
                          ? '${result.percent!.toStringAsFixed(1)}%${result.overallGrade == null ? '' : ' · grade ${result.overallGrade}'}'
                          : 'All subjects graded',
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context)),
                ),
              ],
            ),
          ),
          if (usesMarks)
            Text(
              '${fmtMark(result.scored)} / ${fmtMark(result.maxTotal)}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          const SizedBox(width: 12),
          if (overall != PaperOutcome.pending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
              child: Text(overall.label.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: color)),
            ),
        ],
      ),
    );
  }
}
