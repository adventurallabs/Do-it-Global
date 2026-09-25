import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

/// One standard's timetable for one exam — built a subject at a time, shown
/// as the table it will be read as, then published to everyone concerned.
class GradeTimetableScreen extends StatefulWidget {
  final Exam exam;
  final String gradeKey;
  final List<Classroom> classrooms;

  const GradeTimetableScreen({
    super.key,
    required this.exam,
    required this.gradeKey,
    required this.classrooms,
  });

  static Future<void> open(
    BuildContext context, {
    required Exam exam,
    required String gradeKey,
    required List<Classroom> classrooms,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GradeTimetableScreen(exam: exam, gradeKey: gradeKey, classrooms: classrooms),
      ),
    );
  }

  @override
  State<GradeTimetableScreen> createState() => _GradeTimetableScreenState();
}

class _GradeTimetableScreenState extends State<GradeTimetableScreen> {
  List<ExamPaper> _papers = [];
  ExamSchedule? _schedule;
  List<ExamMarkSheet> _sheets = const [];
  List<Timetable> _timetables = const [];
  List<String> _subjects = const [];
  bool _loading = true;
  bool _error = false;
  bool _publishing = false;
  String? _freshId;

  late final List<Classroom> _sections = ExamPlanning.sectionsOf(widget.gradeKey, widget.classrooms);
  String get _gradeLabel => GradeCatalog.label(widget.gradeKey);

  /// Where this standard's marks would have no owner. Asked of the papers
  /// actually on the timetable — an unbuilt section strands every one of
  /// them, so the admin sees it here rather than at the publish dialog.
  ExamCoverage get _coverage => ExamPlanning.coverage(
        widget.gradeKey,
        classrooms: widget.classrooms,
        timetables: _timetables,
        subjects: [for (final p in _papers) p.subject],
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _papers.isEmpty;
      _error = false;
    });
    try {
      final repo = context.read<ExamRepository>();
      final (overview, timetables) = await (
        repo.overview(widget.exam.id, exam: widget.exam),
        context.read<TimetableRepository>().getAll(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _papers = overview.papersFor(widget.gradeKey);
        _schedule = overview.scheduleFor(widget.gradeKey);
        _sheets = overview.sheets;
        _timetables = timetables;
        _subjects = ExamPlanning.subjectsForGrade(
          widget.gradeKey,
          classrooms: widget.classrooms,
          timetables: timetables,
        );
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _papers.isEmpty;
        });
      }
    }
  }

  Future<void> _refreshSchedule() async {
    try {
      final s = await context.read<ExamRepository>().schedule(widget.exam.id, widget.gradeKey);
      if (mounted) setState(() => _schedule = s);
    } catch (_) {}
  }

  List<String> get _remainingSubjects =>
      _subjects.where((s) => !_papers.any((p) => p.sameSubject(s))).toList();

  Future<void> _editPaper([ExamPaper? paper]) async {
    final result = await showModalBottomSheet<_PaperResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PaperSheet(
        exam: widget.exam,
        gradeKey: widget.gradeKey,
        gradeLabel: _gradeLabel,
        editing: paper,
        papers: _papers,
        subjects: _subjects,
        marksStarted: paper != null && _sheets.any((s) => s.paperId == paper.id && s.enteredCount > 0),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _papers.removeWhere((p) => p.id == (result.deletedId ?? result.saved?.id));
      if (result.saved != null) {
        _papers.add(result.saved!);
        _freshId = paper == null ? result.saved!.id : null;
      }
      _papers.sort(ExamPaper.compare);
    });
    _refreshSchedule();
    HapticFeedback.lightImpact();
  }

  // ----------------------------------------------------------------- publish

  Future<void> _publish() async {
    final schedule = _schedule;
    if (schedule == null || _papers.isEmpty) return;
    final isUpdate = schedule.isPublished;

    // Who is about to be told — the admin should see it before, not after.
    int students = 0;
    final teacherNames = <String>[];
    // Grouped by cause: a section with no timetable at all is one line, not
    // one line per subject it happens to sit.
    final coverage = _coverage;
    try {
      final sectionIds = _sections.map((c) => c.id).toList();
      final (roster, teachers) = await (
        context.read<StudentRepository>().getByClassrooms(sectionIds),
        context.read<TeacherRepository>().getAll(),
      ).wait;
      students = roster.length;
      final ids = <String>{
        for (final c in _sections)
          if (c.classTeacherId.isNotEmpty) c.classTeacherId,
        for (final id in sectionIds) ...ExamPlanning.staffOf(id, timetables: _timetables),
      };
      teacherNames.addAll(teachers.where((t) => ids.contains(t.id)).map((t) => t.name));
    } catch (_) {}
    if (!mounted) return;

    final ok = await confirmExamAction(
      context,
      title: isUpdate ? 'Share the changes?' : 'Publish $_gradeLabel timetable?',
      message: isUpdate
          ? 'Everyone who has this timetable will see the new version and get a notification.'
          : 'It will appear in the Exams section of everyone below, and they will be notified.',
      confirmLabel: isUpdate ? 'Share changes' : 'Publish',
      icon: Icons.send_rounded,
      bullets: [
        'Parents of $students student${students == 1 ? '' : 's'} in ${_sectionSummary()}',
        if (teacherNames.isNotEmpty)
          '${teacherNames.length} teacher${teacherNames.length == 1 ? '' : 's'}: ${teacherNames.join(', ')}'
        else
          'Class teachers and subject teachers of $_gradeLabel',
        if (coverage.adminWarning != null) coverage.adminWarning!,
      ],
    );
    if (!ok || !mounted) return;
    setState(() => _publishing = true);
    try {
      final told = await context.read<ExamRepository>().publish(widget.exam.id, widget.gradeKey);
      await _refreshSchedule();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showSavedToast(
        context,
        title: isUpdate ? 'Changes shared' : 'Timetable published',
        subtitle: 'Sent to $told parent${told == 1 ? '' : 's'} and ${teacherNames.length} teacher${teacherNames.length == 1 ? '' : 's'}.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ExamRepository.describeError(e))));
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  String _sectionSummary() {
    final names = _sections.map((c) => c.resolvedSection).where((s) => s.isNotEmpty).toList();
    if (names.isEmpty) return _gradeLabel;
    return '$_gradeLabel ${names.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_gradeLabel timetable', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(widget.exam.name,
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
                    title: "Couldn't load the timetable",
                    subtitle: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: _load,
                  )
                : Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            children: [
                              _SectionsStrip(sections: _sections, gradeLabel: _gradeLabel),
                              const SizedBox(height: 14),
                              if (_coverage.untimetabled.isNotEmpty) ...[
                                _CoverageWarning(sections: _coverage.untimetabled),
                                const SizedBox(height: 14),
                              ],
                              if (_papers.isEmpty)
                                _EmptyTimetable(onAdd: () => _editPaper(), subjectCount: _subjects.length)
                              else ...[
                                ExamTimetableTable(
                                  papers: _papers,
                                  onTap: _editPaper,
                                  freshPaperId: _freshId,
                                  mode: widget.exam.resultMode,
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    'Tap a row to change or remove it.',
                                    style: TextStyle(fontSize: 12, color: AppColors.onSurfaceHint(context)),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _editPaper(),
                                    icon: const Icon(Icons.add_rounded),
                                    label: Text(
                                      _remainingSubjects.isEmpty
                                          ? 'Add subject'
                                          : 'Add subject · ${_remainingSubjects.length} left',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
      bottomNavigationBar: _loading || _error
          ? null
          : StickyActionBar(
              child: _PublishBar(
                schedule: _schedule,
                paperCount: _papers.length,
                busy: _publishing,
                onPublish: _publish,
              ),
            ),
    );
  }
}

/// Sections that have no class timetable at all.
///
/// Marks follow the timetable, per section: a section without one has no
/// subject teachers, so every teacher who opens its mark sheet is turned
/// away — including the one who plainly takes that subject in the section
/// next door. It reads to them as the app being broken, so say it here,
/// where the admin can fix it.
class _CoverageWarning extends StatelessWidget {
  final List<Classroom> sections;
  const _CoverageWarning({required this.sections});

  @override
  Widget build(BuildContext context) {
    final names = ExamCoverage.listSections(sections);
    final plural = sections.length > 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.report_problem_rounded, size: 19, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$names ${plural ? 'have' : 'has'} no class timetable',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  'No teacher can enter marks for ${plural ? 'these sections' : 'this section'} — '
                  'marks follow the class timetable, so build '
                  '${plural ? 'their timetables' : 'its timetable'} before the exam, '
                  'or you will have to enter every subject yourself.',
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.onSurfaceMuted(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionsStrip extends StatelessWidget {
  final List<Classroom> sections;
  final String gradeLabel;
  const _SectionsStrip({required this.sections, required this.gradeLabel});

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    final names = sections.map((c) => c.displayName).toList();
    return Row(
      children: [
        Icon(Icons.groups_2_outlined, size: 18, color: mute),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            names.isEmpty
                ? 'No classroom exists for $gradeLabel yet'
                : names.length == 1
                    ? 'For ${names.first}'
                    : 'Same timetable for ${names.join(', ')}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: mute),
          ),
        ),
      ],
    );
  }
}

class _EmptyTimetable extends StatelessWidget {
  final VoidCallback onAdd;
  final int subjectCount;
  const _EmptyTimetable({required this.onAdd, required this.subjectCount});

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
      child: Column(
        children: [
          Icon(Icons.table_chart_outlined, size: 40, color: AppColors.onSurfaceHint(context)),
          const SizedBox(height: 14),
          const Text('Build the timetable', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            subjectCount > 0
                ? 'Add each subject with its date, time, marks and syllabus. $subjectCount subjects are taught in this class.'
                : 'Add each subject with its date, time, marks and syllabus.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.onSurfaceMuted(context)),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add first subject'),
          ),
        ],
      ),
    );
  }
}

class _PublishBar extends StatelessWidget {
  final ExamSchedule? schedule;
  final int paperCount;
  final bool busy;
  final VoidCallback onPublish;

  const _PublishBar({required this.schedule, required this.paperCount, required this.busy, required this.onPublish});

  @override
  Widget build(BuildContext context) {
    final s = schedule;
    final published = s?.isPublished ?? false;
    final changes = s?.hasChanges ?? false;
    final canAct = paperCount > 0 && (!published || changes) && !busy;
    final (title, subtitle, color) = switch ((published, changes)) {
      (true, true) => ('Unshared changes', 'Edits since publishing are not sent yet.', AppColors.warning),
      (true, false) => (
          'Published',
          s?.publishedAt == null ? 'Visible to parents and teachers.' : 'Shared on ${ExamDates.short(s!.publishedAt!.toLocal())}.',
          AppColors.success,
        ),
      _ => (
          'Draft',
          paperCount == 0 ? 'Add subjects, then publish.' : 'Only you can see this until you publish.',
          AppColors.examCard,
        ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: canAct ? onPublish : null,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
            icon: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(published && !changes ? Icons.check_rounded : Icons.send_rounded, size: 18),
            label: Text(published ? (changes ? 'Share changes' : 'Published') : 'Publish'),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- paper form

class _PaperResult {
  final ExamPaper? saved;
  final String? deletedId;
  const _PaperResult({this.saved, this.deletedId});
}

class _PaperSheet extends StatefulWidget {
  final Exam exam;
  final String gradeKey;
  final String gradeLabel;
  final ExamPaper? editing;
  final List<ExamPaper> papers;
  final List<String> subjects;
  final bool marksStarted;

  const _PaperSheet({
    required this.exam,
    required this.gradeKey,
    required this.gradeLabel,
    required this.editing,
    required this.papers,
    required this.subjects,
    required this.marksStarted,
  });

  @override
  State<_PaperSheet> createState() => _PaperSheetState();
}

class _PaperSheetState extends State<_PaperSheet> {
  static const _maxPresets = [25.0, 50.0, 100.0];
  static const _durations = [60, 90, 120, 150, 180];

  String? _subject;
  bool _custom = false;
  final _customC = TextEditingController();
  late DateTime _date;
  late int _start;
  late int _end;
  final _maxC = TextEditingController();
  final _passC = TextEditingController();
  final _syllabusC = TextEditingController();
  bool _passTouched = false;
  bool _saving = false;
  String? _error;

  ExamPaper? get _editing => widget.editing;

  /// A grades-only exam has no total or pass mark to set.
  bool get _usesMarks => widget.exam.resultMode.usesMarks;
  List<ExamPaper> get _others => widget.papers.where((p) => p.id != _editing?.id).toList();

  /// Subjects on this class's timetable not already in the exam — or, if the
  /// class has no timetable yet, the school's common list.
  List<String> get _choices {
    final base = widget.subjects.isNotEmpty ? widget.subjects : SubjectCatalog.orderedSubjects;
    final free = base.where((s) => !_others.any((p) => p.sameSubject(s))).toList();
    final current = _editing?.subject;
    if (current != null && !free.any((s) => s.toLowerCase() == current.toLowerCase())) {
      free.insert(0, current);
    }
    return free;
  }

  @override
  void initState() {
    super.initState();
    final e = _editing;
    if (e != null) {
      _subject = e.subject;
      _date = e.examDate;
      _start = e.startMinutes;
      _end = e.endMinutes;
      _maxC.text = fmtMark(e.maxMarks);
      _passC.text = fmtMark(e.passMarks);
      _syllabusC.text = e.syllabus;
      _passTouched = true;
      _custom = !widget.subjects.any((s) => s.toLowerCase() == e.subject.toLowerCase()) && widget.subjects.isNotEmpty;
      if (_custom) _customC.text = e.subject;
    } else {
      // Carry on from the last paper: the next school day, same hours, same
      // marks — most timetables are one paper a day at a fixed time.
      final last = widget.papers.isEmpty ? null : ([...widget.papers]..sort(ExamPaper.compare)).last;
      _date = _nextSchoolDay(last?.examDate ?? DateTime.now());
      _start = last?.startMinutes ?? 10 * 60;
      _end = last?.endMinutes ?? 12 * 60;
      _maxC.text = fmtMark(last?.maxMarks ?? 100);
      _passC.text = fmtMark(last?.passMarks ?? _defaultPass(last?.maxMarks ?? 100));
      final choices = _choices;
      if (choices.length == 1) _subject = choices.first;
    }
  }

  @override
  void dispose() {
    _customC.dispose();
    _maxC.dispose();
    _passC.dispose();
    _syllabusC.dispose();
    super.dispose();
  }

  static DateTime _nextSchoolDay(DateTime from) {
    var d = ExamDates.day(from).add(const Duration(days: 1));
    if (d.weekday == DateTime.sunday) d = d.add(const Duration(days: 1));
    return d;
  }

  static double _defaultPass(double max) => (max * 0.35).ceilToDouble();

  String get _subjectText => (_custom ? _customC.text : (_subject ?? '')).trim();

  double? get _max => double.tryParse(_maxC.text.trim());
  double? get _pass => double.tryParse(_passC.text.trim());

  void _setMax(double v) {
    setState(() {
      _maxC.text = fmtMark(v);
      if (!_passTouched) _passC.text = fmtMark(_defaultPass(v));
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Exam date',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: start ? 'Starts at' : 'Ends at',
    );
    if (picked == null) return;
    final m = picked.hour * 60 + picked.minute;
    setState(() {
      if (start) {
        final length = _end - _start;
        _start = m;
        _end = (m + (length > 0 ? length : 120)).clamp(0, 23 * 60 + 59);
      } else {
        _end = m;
      }
    });
  }

  String? _validate() {
    final subject = _subjectText;
    if (subject.isEmpty) return 'Pick a subject.';
    if (_others.any((p) => p.sameSubject(subject))) return '$subject is already in this timetable.';
    if (_end <= _start) return 'The end time must be after the start time.';
    if (_usesMarks) {
      final max = _max;
      if (max == null || max <= 0) return 'Enter the total marks.';
      final pass = _pass;
      if (pass == null || pass < 0) return 'Enter the pass mark.';
      if (pass > max) return 'The pass mark can\'t be more than the total.';
    }
    final probe = ExamPaper(
      id: '_',
      examId: widget.exam.id,
      gradeKey: widget.gradeKey,
      subject: subject,
      examDate: _date,
      startTime: ExamDates.hhmm(_start),
      endTime: ExamDates.hhmm(_end),
    );
    for (final o in _others) {
      if (o.overlaps(probe)) {
        return 'Clashes with ${o.subject} on ${ExamDates.short(o.examDate)}, ${o.timeLabel}.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final paper = ExamPaper(
      id: _editing?.id ?? ExamRepository.newId('xp'),
      examId: widget.exam.id,
      gradeKey: widget.gradeKey,
      subject: _subjectText,
      examDate: _date,
      startTime: ExamDates.hhmm(_start),
      endTime: ExamDates.hhmm(_end),
      syllabus: _syllabusC.text.trim(),
      // A grades-only paper keeps neutral defaults; nothing reads them.
      maxMarks: _usesMarks ? _max! : 100,
      passMarks: _usesMarks ? _pass! : 0,
    );
    try {
      final saved = await context.read<ExamRepository>().savePaper(paper);
      if (mounted) Navigator.pop(context, _PaperResult(saved: saved));
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = ExamRepository.describeError(e);
        });
      }
    }
  }

  Future<void> _delete() async {
    final e = _editing;
    if (e == null) return;
    final ok = await confirmExamAction(
      context,
      title: 'Remove ${e.subject}?',
      message: widget.marksStarted
          ? 'Teachers have already entered marks for this paper. Removing it deletes those marks too.'
          : 'It will be taken off the ${widget.gradeLabel} timetable.',
      confirmLabel: 'Remove',
      icon: Icons.delete_outline_rounded,
      color: AppColors.error,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await context.read<ExamRepository>().deletePaper(e.id);
      if (mounted) Navigator.pop(context, _PaperResult(deletedId: e.id));
    } catch (err) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = ExamRepository.describeError(err);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = _choices;
    final mute = AppColors.onSurfaceMuted(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final length = _end - _start;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _editing == null ? 'Add a subject' : 'Edit ${_editing!.subject}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text('${widget.gradeLabel} · ${widget.exam.name}', style: TextStyle(fontSize: 13, color: mute)),
            const SizedBox(height: 18),

            _label('Subject'),
            if (widget.subjects.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'This class has no timetable yet, so these are the school\'s common subjects.',
                  style: TextStyle(fontSize: 12, color: AppColors.warning),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in choices)
                  ChoiceChip(
                    label: Text(s),
                    selected: !_custom && _subject?.toLowerCase() == s.toLowerCase(),
                    onSelected: (_) => setState(() {
                      _custom = false;
                      _subject = s;
                      _error = null;
                    }),
                  ),
                ChoiceChip(
                  avatar: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Other'),
                  selected: _custom,
                  onSelected: (_) => setState(() => _custom = true),
                ),
              ],
            ),
            if (_custom) ...[
              const SizedBox(height: 10),
              SoftField(
                child: TextField(
                  controller: _customC,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Subject name'),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Not on the class timetable — no teacher can enter its marks, so you will.',
                  style: TextStyle(fontSize: 11.5, color: mute),
                ),
              ),
            ],
            const SizedBox(height: 18),

            _label('Date & time'),
            _PickerTile(
              icon: Icons.event_rounded,
              label: 'Date',
              value: ExamDates.long(_date),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.play_arrow_rounded,
                    label: 'Starts',
                    value: ExamDates.display(ExamDates.hhmm(_start)),
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.stop_rounded,
                    label: 'Ends',
                    value: ExamDates.display(ExamDates.hhmm(_end)),
                    onTap: () => _pickTime(false),
                    error: _end <= _start,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in _durations)
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(d % 60 == 0 ? '${d ~/ 60} h' : '${d / 60} h'),
                    selected: length == d,
                    onSelected: (_) => setState(() => _end = (_start + d).clamp(0, 23 * 60 + 59)),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            if (_usesMarks) ...[
            _label('Marks'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SoftField(
                        child: TextField(
                          controller: _maxC,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          decoration: const InputDecoration(labelText: 'Out of'),
                          onChanged: (v) {
                            final m = double.tryParse(v);
                            setState(() {
                              if (m != null && !_passTouched) _passC.text = fmtMark(_defaultPass(m));
                              _error = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final m in _maxPresets)
                            ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(fmtMark(m)),
                              selected: _max == m,
                              onSelected: (_) => _setMax(m),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftField(
                    child: TextField(
                      controller: _passC,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: const InputDecoration(labelText: 'Pass mark'),
                      onChanged: (_) => setState(() {
                        _passTouched = true;
                        _error = null;
                      }),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ],

            _label('Syllabus'),
            SoftField(
              child: TextField(
                controller: _syllabusC,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'e.g. Lessons 1–4, poem "The Tree", grammar: tenses'),
              ),
            ),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _error == null
                  ? const SizedBox(height: 16)
                  : Padding(
                      key: ValueKey(_error),
                      padding: const EdgeInsets.only(top: 14, bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_editing != null) ...[
                  IconButton.outlined(
                    onPressed: _saving ? null : _delete,
                    tooltip: 'Remove from timetable',
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_editing == null ? Icons.playlist_add_rounded : Icons.check_rounded),
                      label: Text(_editing == null ? 'Add to timetable' : 'Save changes'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.onSurfaceHint(context),
          ),
        ),
      );
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool error;

  const _PickerTile({required this.icon, required this.label, required this.value, required this.onTap, this.error = false});

  @override
  Widget build(BuildContext context) {
    final color = error ? AppColors.error : AppColors.accent;
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted(context))),
                    Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
