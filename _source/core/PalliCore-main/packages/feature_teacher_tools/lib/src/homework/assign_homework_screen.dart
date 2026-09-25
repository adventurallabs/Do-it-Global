import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'homework_progress.dart';

/// Assign (or edit) homework.
///
/// Laid out as three numbered steps because the teachers using it are not
/// software people: who it goes to, what the work is, when it is due. The old
/// form lived inline above the homework list, so every glance at "what did I
/// set 7-B?" meant scrolling past six empty input fields.
class AssignHomeworkScreen extends StatefulWidget {
  final String teacherId;
  final List<Classroom> classrooms;
  final Map<String, List<String>> subjectsByClassroom;

  /// Preselected class — set when opening from a timetable period or from a
  /// class's own section of the board.
  final String? initialClassroomId;
  final String? initialSubject;

  /// Non-null puts the screen in edit mode: one class, fields prefilled.
  final Homework? existing;

  const AssignHomeworkScreen({
    super.key,
    required this.teacherId,
    required this.classrooms,
    required this.subjectsByClassroom,
    this.initialClassroomId,
    this.initialSubject,
    this.existing,
  });

  /// Returns true when something was saved, so the caller can refresh.
  static Future<bool> open(
    BuildContext context, {
    required String teacherId,
    required List<Classroom> classrooms,
    required Map<String, List<String>> subjectsByClassroom,
    String? initialClassroomId,
    String? initialSubject,
    Homework? existing,
  }) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AssignHomeworkScreen(
          teacherId: teacherId,
          classrooms: classrooms,
          subjectsByClassroom: subjectsByClassroom,
          initialClassroomId: initialClassroomId,
          initialSubject: initialSubject,
          existing: existing,
        ),
      ),
    );
    return saved ?? false;
  }

  @override
  State<AssignHomeworkScreen> createState() => _AssignHomeworkScreenState();
}

class _AssignHomeworkScreenState extends State<AssignHomeworkScreen> {
  final _selected = <String>{};
  String? _subject;
  final _titleC = TextEditingController();
  final _descC = TextEditingController();
  final _attachmentC = TextEditingController();
  late DateTime _dueDate;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final hw = widget.existing;
    _dueDate = hw?.dueDate ?? DateTime.now().add(const Duration(days: 1));
    if (hw != null) {
      _selected.add(hw.classroomId);
      _subject = hw.subject;
      _titleC.text = hw.title;
      _descC.text = hw.description;
      _attachmentC.text = hw.attachmentUrl ?? '';
    } else {
      // Preselect from the caller, else from the only class they teach.
      if (widget.initialClassroomId != null) {
        _selected.add(widget.initialClassroomId!);
      } else if (widget.classrooms.length == 1) {
        _selected.add(widget.classrooms.first.id);
      }
      _subject = widget.initialSubject;
    }
    if (_subject == null) {
      final options = _subjectOptions();
      if (options.length == 1) _subject = options.first;
    }
  }

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _attachmentC.dispose();
    super.dispose();
  }

  /// Subjects the teacher is timetabled for across every selected class.
  List<String> _subjectOptions() {
    final out = <String>{};
    for (final id in _selected) {
      out.addAll(widget.subjectsByClassroom[id] ?? const []);
    }
    // Keep a subject that was picked before the class selection changed, so it
    // does not silently vanish from under the teacher.
    if (_subject != null) out.add(_subject!);
    final list = out.toList()..sort();
    return list;
  }

  List<Classroom> get _selectedClassrooms =>
      widget.classrooms.where((c) => _selected.contains(c.id)).toList();

  String get _targetSummary {
    final names = _selectedClassrooms.map((c) => c.displayName).toList();
    // Editing work whose class the teacher no longer holds: still name it
    // something sane rather than claiming nothing is chosen.
    if (names.isEmpty) return _isEdit ? 'its class' : 'No class chosen yet';
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    return '${names.take(names.length - 1).join(', ')} and ${names.last}';
  }

  bool get _canSave =>
      _selected.isNotEmpty && (_subject ?? '').isNotEmpty && _titleC.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final subjects = _subjectOptions();
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit homework' : 'Assign homework')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _step(
              1,
              'Who is it for?',
              _isEdit
                  ? 'Homework stays with the class it was set for.'
                  : widget.classrooms.length > 1
                      ? 'Tap every class that gets this work.'
                      : 'Your class.',
              child: _isEdit
                  // Read-only rather than a row of dead chips: the class is
                  // settled, so just say which one it is.
                  ? Row(
                      children: [
                        Icon(Icons.class_outlined,
                            size: 18, color: AppColors.onSurfaceMuted(context)),
                        const SizedBox(width: 8),
                        Text(
                          _targetSummary,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                      ],
                    )
                  : widget.classrooms.isEmpty
                      ? Text(
                          'No classes assigned to you yet. Ask the admin to put you on a timetable.',
                          style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 13),
                        )
                      : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in widget.classrooms)
                          FilterChip(
                            label: Text(c.displayName),
                            selected: _selected.contains(c.id),
                            onSelected: (on) => setState(() {
                              if (on) {
                                _selected.add(c.id);
                              } else {
                                _selected.remove(c.id);
                              }
                              final options = _subjectOptions();
                              if (_subject != null && !options.contains(_subject)) {
                                _subject = null;
                              }
                              if (_subject == null && options.length == 1) {
                                _subject = options.first;
                              }
                            }),
                          ),
                      ],
                    ),
            ),
            if (_selected.isNotEmpty) ...[
              const SizedBox(height: 10),
              _subjectPicker(subjects),
            ],
            const SizedBox(height: 22),
            _step(
              2,
              'What is the work?',
              'A short title is enough. Add details if you need to.',
              child: Column(
                children: [
                  SoftField(
                    child: TextField(
                      controller: _titleC,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Homework title',
                        hintText: 'e.g. Chapter 4 — exercises 1 to 6',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SoftField(
                    child: TextField(
                      controller: _descC,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Details (optional)',
                        prefixIcon: Icon(Icons.notes_rounded),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SoftField(
                    child: TextField(
                      controller: _attachmentC,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Link (optional)',
                        hintText: 'Paste a worksheet or video link',
                        prefixIcon: Icon(Icons.attach_file_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _step(
              3,
              'When is it due?',
              dueLabel(_dueDate) == 'Due today'
                  ? 'Due today — ${shortDate(_dueDate)}'
                  : '${dueLabel(_dueDate)} — ${shortDate(_dueDate)}',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _dueChip('Today', 0),
                  _dueChip('Tomorrow', 1),
                  _dueChip('In 2 days', 2),
                  _dueChip('Next week', 7),
                  ActionChip(
                    avatar: const Icon(Icons.event_outlined, size: 18),
                    label: const Text('Another date'),
                    onPressed: _pickDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (!_isEdit && _selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Goes to $_targetSummary',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.onSurfaceMuted(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            SoftPrimaryButton(
              label: _saving
                  ? 'Saving…'
                  : _isEdit
                      ? 'Save changes'
                      : _selected.length > 1
                          ? 'Assign to ${_selected.length} classes'
                          : 'Assign homework',
              icon: Icons.assignment_turned_in_outlined,
              onPressed: _canSave && !_saving ? _save : null,
            ),
            if (!_canSave) ...[
              const SizedBox(height: 10),
              Text(
                _missingHint(),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _missingHint() {
    if (_selected.isEmpty) return 'Pick a class first.';
    if ((_subject ?? '').isEmpty) return 'Pick the subject.';
    return 'Give the homework a title.';
  }

  Widget _subjectPicker(List<String> subjects) {
    return _step(
      null,
      'Subject',
      subjects.isEmpty
          ? "You're not timetabled for a subject in this class — pick one below."
          : null,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in subjects)
            ChoiceChip(
              label: Text(s),
              selected: _subject == s,
              onSelected: (_) => setState(() => _subject = s),
            ),
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: Text(subjects.isEmpty ? 'Choose subject' : 'Other'),
            onPressed: _pickOtherSubject,
          ),
        ],
      ),
    );
  }

  Future<void> _pickOtherSubject() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Pick a subject',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            for (final s in SubjectCatalog.orderedSubjects)
              ListTile(
                title: Text(s),
                trailing: _subject == s ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _subject = picked);
  }

  Widget _dueChip(String label, int daysFromToday) {
    final now = DateTime.now();
    final target = DateTime(now.year, now.month, now.day).add(Duration(days: daysFromToday));
    final selected = daysUntilDue(_dueDate) == daysFromToday;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _dueDate = target),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(now) ? now : _dueDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('en', 'IN'),
      fieldHintText: 'dd/mm/yyyy',
      errorFormatText: 'Enter date as dd/mm/yyyy',
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = context.read<HomeworkRepository>();
    final title = _titleC.text.trim();
    final desc = _descC.text.trim();
    final link = _attachmentC.text.trim();
    // Due "today" should mean end of the school day, not the moment of saving.
    final due = DateTime(_dueDate.year, _dueDate.month, _dueDate.day, 23, 59);

    final rows = <Homework>[
      if (_isEdit)
        Homework(
          id: widget.existing!.id,
          classroomId: widget.existing!.classroomId,
          subject: _subject!,
          title: title,
          description: desc,
          dueDate: due,
          createdBy: widget.existing!.createdBy,
          studentId: widget.existing!.studentId,
          attachmentUrl: link.isEmpty ? null : link,
          attachmentName: widget.existing!.attachmentName,
        )
      else
        for (final id in _selected)
          Homework(
            id: HomeworkRepository.newId(),
            classroomId: id,
            subject: _subject!,
            title: title,
            description: desc,
            dueDate: due,
            createdBy: widget.teacherId,
            attachmentUrl: link.isEmpty ? null : link,
          ),
    ];

    try {
      // Sequential, not Future.wait: a partial failure should leave a clear
      // "nothing after this point went out" rather than a scattered subset.
      for (final row in rows) {
        await repo.save(row);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't send the homework — check your connection and try again."),
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEdit
            ? 'Homework updated'
            : '$_subject homework sent to $_targetSummary'),
      ),
    );
    Navigator.pop(context, true);
  }

  Widget _step(int? number, String title, String? subtitle, {required Widget child}) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (number != null) ...[
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.accent),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AdminLook.inkOf(context),
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                  color: AppColors.onSurfaceMuted(context), fontSize: 12.5, height: 1.35),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
