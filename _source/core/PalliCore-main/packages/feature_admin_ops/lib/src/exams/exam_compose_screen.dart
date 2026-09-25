import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

/// Step one of an exam: what it's called and which standards sit it.
///
/// The admin picks standards, not sections — 4th Std A and 4th Std B sit the
/// same papers, so asking for each section separately is busywork that can
/// only produce mismatched timetables.
class ExamComposeScreen extends StatefulWidget {
  final List<Classroom> classrooms;
  final ExamOverview? editing;

  const ExamComposeScreen({super.key, required this.classrooms, this.editing});

  /// Returns the saved exam, or null if the admin backed out.
  static Future<Exam?> open(
    BuildContext context, {
    required List<Classroom> classrooms,
    ExamOverview? editing,
  }) {
    return Navigator.push<Exam>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExamComposeScreen(classrooms: classrooms, editing: editing),
      ),
    );
  }

  @override
  State<ExamComposeScreen> createState() => _ExamComposeScreenState();
}

class _ExamComposeScreenState extends State<ExamComposeScreen> {
  static const _presets = ['Unit test 1', 'Quarterly', 'Half-yearly', 'Unit test 2', 'Annual'];

  final _name = TextEditingController();
  final Set<String> _grades = {};
  bool _saving = false;
  List<Classroom> _classrooms = const [];

  ExamResultMode _mode = ExamResultMode.marks;
  String? _presetId;
  List<GradeBand> _bands = const [];
  bool _customScale = false;
  final List<_BandDraft> _custom = [];

  bool get _isEdit => widget.editing != null;

  /// Once any mark exists the database refuses a change of result type or
  /// scale; the screen says so up front instead of failing on save.
  bool get _modeLocked => widget.editing?.sheets.any((s) => s.enteredCount > 0) ?? false;

  List<GradeBand> get _effectiveBands => _customScale
      ? [
          for (final d in _custom) GradeBand(label: d.label.text.trim(), pass: d.pass),
        ]
      : _bands;

  String? get _scaleError => _mode.usesGrades ? GradeScale.validate(_effectiveBands) : null;

  void _usePreset(GradeScalePreset p) {
    _customScale = false;
    _presetId = p.id;
    _bands = p.bands;
  }

  void _startCustom() {
    _customScale = true;
    if (_custom.isEmpty) {
      final seed = _bands.isNotEmpty ? _bands : GradeScale.presets[1].bands;
      for (final b in seed) {
        _custom.add(_BandDraft(b.label, b.pass));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _classrooms = widget.classrooms;
    final e = widget.editing;
    if (e != null) {
      _name.text = e.exam.name;
      _grades.addAll(e.schedules.map((s) => s.gradeKey));
      _mode = e.exam.resultMode;
      _bands = e.exam.gradeScale;
      final preset = GradeScale.presetMatching(_bands);
      if (preset != null) {
        _presetId = preset.id;
      } else if (_bands.isNotEmpty) {
        _startCustom();
      }
    }
    _name.addListener(() => setState(() {}));
    if (_classrooms.isEmpty) {
      _loadingClassrooms = true;
      _loadClassrooms();
    }
  }

  bool _loadingClassrooms = false;

  Future<void> _loadClassrooms() async {
    if (!_loadingClassrooms) setState(() => _loadingClassrooms = true);
    try {
      final list = await context.read<ClassroomRepository>().getAll();
      if (mounted) setState(() => _classrooms = list);
    } catch (_) {
      // Falls through to the empty state, which offers a retry.
    } finally {
      if (mounted) setState(() => _loadingClassrooms = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    for (final d in _custom) {
      d.label.dispose();
    }
    super.dispose();
  }

  List<ClassroomGradeGroup> get _groups => GradeCatalog.group(_classrooms, includeEmpty: false);

  bool get _canSave =>
      _name.text.trim().isNotEmpty && _grades.isNotEmpty && !_saving && (_modeLocked || _scaleError == null);

  Future<void> _save() async {
    if (!_canSave) return;
    final repo = context.read<ExamRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final grades = GradeCatalog.sortKeys(_grades);
    final classroomIds = [
      for (final g in grades) ...ExamPlanning.sectionsOf(g, _classrooms).map((c) => c.id),
    ];

    final editing = widget.editing;
    if (editing != null) {
      final removed = editing.schedules.where((s) => !_grades.contains(s.gradeKey)).toList();
      final losing = removed.where((s) => s.paperCount > 0).toList();
      if (losing.isNotEmpty) {
        final ok = await confirmExamAction(
          context,
          title: 'Remove ${losing.length == 1 ? 'this class' : 'these classes'}?',
          message: 'Their timetable and any marks already entered for them will be deleted.',
          confirmLabel: 'Remove',
          icon: Icons.warning_amber_rounded,
          color: AppColors.error,
          bullets: [
            for (final s in losing)
              '${GradeCatalog.label(s.gradeKey)} — ${s.paperCount} subject${s.paperCount == 1 ? '' : 's'}',
          ],
        );
        if (!ok) return;
      }
    }

    setState(() => _saving = true);
    try {
      late final Exam saved;
      if (editing == null) {
        saved = Exam(
          id: ExamRepository.newId('ex'),
          name: _name.text.trim(),
          academicYearId: await _currentYearId(),
          startDate: DateTime.now(),
          endDate: DateTime.now(),
          gradeKeys: grades,
          classroomIds: classroomIds,
          subjects: const [],
          resultMode: _mode,
          gradeScale: _mode.usesGrades ? _effectiveBands : const [],
        );
        await repo.createExam(saved);
      } else {
        saved = editing.exam.copyWith(
          name: _name.text.trim(),
          gradeKeys: grades,
          classroomIds: classroomIds,
          resultMode: _modeLocked ? null : _mode,
          gradeScale: _modeLocked ? null : (_mode.usesGrades ? _effectiveBands : const []),
        );
        await repo.updateExam(saved, previousGrades: editing.schedules.map((s) => s.gradeKey).toList());
      }
      navigator.pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(ExamRepository.describeError(e))));
    }
  }

  Future<String> _currentYearId() async {
    try {
      final years = await context.read<AcademicYearRepository>().getAll();
      for (final y in years) {
        if (y.isCurrent) return y.id;
      }
      if (years.isNotEmpty) return years.first.id;
    } catch (_) {}
    return 'ay-current';
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final allSelected = groups.isNotEmpty && groups.every((g) => _grades.contains(g.gradeKey));
    final mute = AppColors.onSurfaceMuted(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit exam' : 'New exam')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _StepLabel(number: 1, title: 'Name the exam'),
                  const SizedBox(height: 10),
                  SoftField(
                    child: TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(hintText: 'e.g. Quarterly examination'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in _presets)
                        ChoiceChip(
                          label: Text(p),
                          selected: _name.text.trim() == p,
                          onSelected: (_) => setState(() {
                            _name.text = p;
                            _name.selection = TextSelection.collapsed(offset: p.length);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(child: _StepLabel(number: 2, title: 'Classes taking it')),
                      if (groups.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() {
                            if (allSelected) {
                              _grades.clear();
                            } else {
                              _grades.addAll(groups.map((g) => g.gradeKey));
                            }
                          }),
                          child: Text(allSelected ? 'Clear' : 'Select all'),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 36, bottom: 12),
                    child: Text(
                      'Every section of a class sits the same timetable.',
                      style: TextStyle(fontSize: 12.5, color: mute),
                    ),
                  ),
                  if (groups.isEmpty && _loadingClassrooms)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (groups.isEmpty)
                    EmptyState(
                      icon: Icons.class_outlined,
                      title: 'No classrooms yet',
                      subtitle: 'Create classrooms first, then come back to add them to an exam.',
                      actionLabel: 'Retry',
                      onAction: _loadClassrooms,
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: groups.length,
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        mainAxisExtent: 76,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (context, i) {
                        final g = groups[i];
                        final selected = _grades.contains(g.gradeKey);
                        return _GradeTile(
                          group: g,
                          selected: selected,
                          onTap: () => setState(() {
                            if (!selected) {
                              _grades.add(g.gradeKey);
                            } else {
                              _grades.remove(g.gradeKey);
                            }
                          }),
                        );
                      },
                    ),
                  const SizedBox(height: 28),
                  _StepLabel(number: 3, title: 'How are results recorded?'),
                  const SizedBox(height: 12),
                  if (_modeLocked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InfoLine(
                        icon: Icons.lock_outline_rounded,
                        text: 'Marks have already been entered, so the result type and grade scale are fixed.',
                      ),
                    ),
                  for (final m in ExamResultMode.values)
                    _ModeOption(
                      mode: m,
                      selected: _mode == m,
                      enabled: !_modeLocked,
                      onTap: () => setState(() {
                        _mode = m;
                        if (m.usesGrades && _bands.isEmpty) _usePreset(GradeScale.presets.first);
                      }),
                    ),
                  if (_mode.usesGrades) ...[
                    const SizedBox(height: 18),
                    Text(
                      'GRADE SCALE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.onSurfaceHint(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in GradeScale.presets)
                          ChoiceChip(
                            label: Text(p.name),
                            selected: !_customScale && _presetId == p.id,
                            onSelected: _modeLocked ? null : (_) => setState(() => _usePreset(p)),
                          ),
                        ChoiceChip(
                          avatar: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('Custom'),
                          selected: _customScale,
                          onSelected: _modeLocked ? null : (_) => setState(_startCustom),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_customScale)
                      _CustomScaleEditor(
                        drafts: _custom,
                        enabled: !_modeLocked,
                        onChanged: () => setState(() {}),
                      )
                    else
                      _ScalePreview(bands: _bands, hint: GradeScale.presets.where((p) => p.id == _presetId).firstOrNull?.hint),
                    if (_scaleError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_scaleError!, style: const TextStyle(color: AppColors.error, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: StickyActionBar(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _canSave ? _save : null,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_isEdit ? Icons.check_rounded : Icons.arrow_forward_rounded),
              label: Text(
                _isEdit
                    ? 'Save changes'
                    : _grades.isEmpty
                        ? 'Pick at least one class'
                        : 'Create exam · ${_grades.length} class${_grades.length == 1 ? '' : 'es'}',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final int number;
  final String title;
  const _StepLabel({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.14), shape: BoxShape.circle),
          child: Text('$number', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent)),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _GradeTile extends StatelessWidget {
  final ClassroomGradeGroup group;
  final bool selected;
  final VoidCallback onTap;
  const _GradeTile({required this.group, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sections = group.classrooms.map((c) => c.resolvedSection).where((s) => s.isNotEmpty).toList();
    final subtitle = sections.isEmpty
        ? '1 class'
        : '${sections.length} section${sections.length == 1 ? '' : 's'} · ${sections.join(', ')}';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? AppColors.accent.withValues(alpha: 0.12) : AppColors.onSurface(context).withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.divider,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? AppColors.accent : AppColors.onSurfaceHint(context),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceMuted(context)),
                      ),
                    ],
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

class _BandDraft {
  final TextEditingController label;
  bool pass;
  _BandDraft(String text, this.pass) : label = TextEditingController(text: text);
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.examCard.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.examCard),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.35))),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final ExamResultMode mode;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ModeOption({required this.mode, required this.selected, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = switch (mode) {
      ExamResultMode.marks => Icons.pin_outlined,
      ExamResultMode.grades => Icons.military_tech_outlined,
      ExamResultMode.marksAndGrades => Icons.join_inner_rounded,
    };
    final color = selected ? AppColors.accent : AppColors.onSurfaceHint(context);
    return Opacity(
      opacity: enabled || selected ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: selected ? AppColors.accent : AppColors.divider, width: selected ? 1.6 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mode.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                        Text(mode.description,
                            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context))),
                      ],
                    ),
                  ),
                  Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScalePreview extends StatelessWidget {
  final List<GradeBand> bands;
  final String? hint;
  const _ScalePreview({required this.bands, this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final b in bands)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (b.pass ? AppColors.accent : AppColors.error).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  b.min == null ? b.label : '${b.label}  ${fmtMark(b.min!)}%+',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: b.pass ? AppColors.onSurface(context) : AppColors.error,
                  ),
                ),
              ),
          ],
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(hint!, style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context))),
          ),
      ],
    );
  }
}

/// Best grade first. Custom scales carry no percentages, so teachers pick
/// the grade themselves even when a mark is entered too.
class _CustomScaleEditor extends StatelessWidget {
  final List<_BandDraft> drafts;
  final bool enabled;
  final VoidCallback onChanged;

  const _CustomScaleEditor({required this.drafts, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Best grade first. Switch on "Fail" for grades that don\'t pass.',
            style: TextStyle(fontSize: 12, color: mute)),
        const SizedBox(height: 8),
        for (var i = 0; i < drafts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 22, child: Text('${i + 1}', style: TextStyle(color: mute, fontWeight: FontWeight.w700))),
                Expanded(
                  child: TextField(
                    controller: drafts[i].label,
                    enabled: enabled,
                    maxLength: 16,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(isDense: true, counterText: '', hintText: 'Grade'),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Fail'),
                  selected: !drafts[i].pass,
                  selectedColor: AppColors.error.withValues(alpha: 0.18),
                  onSelected: enabled
                      ? (v) {
                          drafts[i].pass = !v;
                          onChanged();
                        }
                      : null,
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: enabled && drafts.length > 2
                      ? () {
                          drafts.removeAt(i).label.dispose();
                          onChanged();
                        }
                      : null,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
        if (drafts.length < 12)
          TextButton.icon(
            onPressed: enabled
                ? () {
                    drafts.add(_BandDraft('', true));
                    onChanged();
                  }
                : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add grade'),
          ),
      ],
    );
  }
}
