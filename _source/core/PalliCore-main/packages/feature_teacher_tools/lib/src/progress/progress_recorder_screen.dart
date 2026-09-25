import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'progress_widgets.dart';

/// One screen for every progress action: pick WHAT (a preset or your own),
/// pick WHO (one student, a few, or the whole class), tap save once.
///
/// Returns the number of students recorded (null / 0 when cancelled).
class ProgressRecorderScreen extends StatefulWidget {
  final ProgressKind kind;
  final String teacherId;
  final String? classroomId;
  final List<Student> students;
  final Set<String> preselected;

  const ProgressRecorderScreen({
    super.key,
    required this.kind,
    required this.teacherId,
    required this.students,
    this.classroomId,
    this.preselected = const {},
  });

  static Future<int?> open(
    BuildContext context, {
    required ProgressKind kind,
    required String teacherId,
    required List<Student> students,
    String? classroomId,
    Set<String> preselected = const {},
  }) {
    return Navigator.push<int>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RepositoryProvider.value(
          value: context.read<ProgressRepository>(),
          child: ProgressRecorderScreen(
            kind: kind,
            teacherId: teacherId,
            students: students,
            classroomId: classroomId,
            preselected: preselected,
          ),
        ),
      ),
    );
  }

  @override
  State<ProgressRecorderScreen> createState() => _ProgressRecorderScreenState();
}

const _mine = '__mine__';

class _ProgressRecorderScreenState extends State<ProgressRecorderScreen> {
  late final ProgressKindMeta _meta = ProgressKindMeta.of(widget.kind);
  late final List<Student> _roster = sortedRoster(widget.students);

  List<ProgressTemplate> _myTemplates = [];
  final List<ProgressTemplate> _sessionTemplates = [];
  String? _category; // null = all
  String _presetQuery = '';
  ProgressTemplate? _selected;

  late final Set<String> _who = {...widget.preselected};
  String _studentQuery = '';

  // per-kind details
  int _points = 1;
  DateTime _date = DateTime.now();
  String? _result;
  final _remarksC = TextEditingController();
  final _bodyC = TextEditingController();
  ObservationTone _tone = ObservationTone.positive;

  // skills: studentId -> skillName(lower) -> level label
  Map<String, Map<String, String>> _existingSkills = {};
  final Map<String, int> _levels = {};

  bool _saving = false;

  ProgressRepository get _repo => context.read<ProgressRepository>();
  bool get _isSkill => widget.kind == ProgressKind.skill;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    if (_isSkill) _loadSkills();
  }

  @override
  void dispose() {
    _remarksC.dispose();
    _bodyC.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final mine = await _repo.myTemplates(widget.teacherId);
      if (!mounted) return;
      setState(() => _myTemplates = mine.where((t) => t.kind == widget.kind).toList());
    } catch (_) {
      // built-ins still work offline — the teacher's own presets just don't show
    }
  }

  Future<void> _loadSkills() async {
    try {
      final skills = await _repo.skillsFor(_roster.map((s) => s.id).toList());
      if (!mounted) return;
      final map = <String, Map<String, String>>{};
      for (final s in skills) {
        (map[s.studentId] ??= {})[s.name.toLowerCase()] = s.level;
      }
      setState(() {
        _existingSkills = map;
        if (_selected != null) _prefillLevels(_selected!);
      });
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // presets
  // ---------------------------------------------------------------------------

  List<ProgressTemplate> get _allTemplates => [
        ..._sessionTemplates,
        ..._myTemplates,
        ...ProgressCatalog.builtInsFor(widget.kind),
      ];

  List<String> get _categories {
    final seen = <String>{};
    return [
      for (final t in _allTemplates)
        if (t.category.isNotEmpty && seen.add(t.category)) t.category,
    ];
  }

  List<ProgressTemplate> get _visibleTemplates {
    final q = _presetQuery.trim().toLowerCase();
    return _allTemplates.where((t) {
      if (_category == _mine && t.isBuiltIn) return false;
      if (_category != null && _category != _mine && t.category != _category) return false;
      if (q.isNotEmpty &&
          !t.title.toLowerCase().contains(q) &&
          !t.body.toLowerCase().contains(q) &&
          !t.category.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _select(ProgressTemplate t) {
    setState(() {
      if (_selected?.id == t.id) {
        _selected = null;
        return;
      }
      _selected = t;
      if (widget.kind == ProgressKind.observation) {
        _bodyC.text = t.body;
        _tone = t.tone;
      }
      if (_isSkill) _prefillLevels(t);
    });
  }

  void _prefillLevels(ProgressTemplate skill) {
    _levels.clear();
    for (final s in _roster) {
      final step = SkillLevel.stepOf(_existingSkills[s.id]?[skill.title.toLowerCase()] ?? '');
      if (step > 0) _levels[s.id] = step;
    }
  }

  Future<void> _createTemplate() async {
    final created = await showModalBottomSheet<(ProgressTemplate, bool)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _TemplateForm(kind: widget.kind, teacherId: widget.teacherId),
    );
    if (created == null || !mounted) return;
    final (template, keep) = created;
    if (keep) {
      try {
        await _repo.saveTemplate(template);
        if (!mounted) return;
        setState(() => _myTemplates = [template, ..._myTemplates]);
      } catch (_) {
        if (!mounted) return;
        setState(() => _sessionTemplates.insert(0, template));
        _snack("Couldn't save it to your presets — it's still selected for now.");
      }
    } else {
      setState(() => _sessionTemplates.insert(0, template));
    }
    setState(() => _category = null);
    _select(template);
  }

  Future<void> _deleteTemplate(ProgressTemplate t) async {
    if (t.isBuiltIn) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove preset?'),
        content: Text('"${t.title}" will be removed from your presets. '
            'Anything already recorded with it stays.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _myTemplates.removeWhere((x) => x.id == t.id);
      _sessionTemplates.removeWhere((x) => x.id == t.id);
      if (_selected?.id == t.id) _selected = null;
    });
    try {
      await _repo.deleteTemplate(t.id);
    } catch (_) {
      _snack("Couldn't remove it right now. Try again later.");
    }
  }

  // ---------------------------------------------------------------------------
  // save
  // ---------------------------------------------------------------------------

  /// Skill ratings that actually change something.
  Map<String, int> get _skillChanges {
    final t = _selected;
    if (t == null) return const {};
    final out = <String, int>{};
    _levels.forEach((studentId, step) {
      if (step <= 0) return;
      final before = SkillLevel.stepOf(_existingSkills[studentId]?[t.title.toLowerCase()] ?? '');
      if (before != step) out[studentId] = step;
    });
    return out;
  }

  int get _count => _isSkill ? _skillChanges.length : _who.length;

  bool get _canSave {
    if (_saving || _selected == null || _count == 0) return false;
    if (widget.kind == ProgressKind.observation && _bodyC.text.trim().isEmpty) return false;
    return true;
  }

  String get _saveLabel {
    final n = _count;
    final who = n == 1 ? '1 student' : '$n students';
    return switch (widget.kind) {
      ProgressKind.star => n == 0
          ? 'Choose students'
          : 'Give $_points ${_points == 1 ? 'star' : 'stars'} to $who',
      ProgressKind.skill => n == 0 ? 'Set a level for someone' : 'Save $n ${n == 1 ? 'rating' : 'ratings'}',
      _ => n == 0 ? 'Choose students' : 'Save for $who',
    };
  }

  Future<void> _save() async {
    final t = _selected;
    if (t == null || !_canSave) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final stamp = now.microsecondsSinceEpoch;
    final batch = 'b-$stamp';
    final ids = _roster.where((s) => _who.contains(s.id)).map((s) => s.id).toList();
    try {
      switch (widget.kind) {
        case ProgressKind.star:
          await _repo.awardStars([
            for (var i = 0; i < ids.length; i++)
              StarPoint(
                id: 'star-$stamp-$i',
                studentId: ids[i],
                classroomId: widget.classroomId,
                points: _points,
                reason: t.title,
                batchId: batch,
                awardedBy: widget.teacherId,
              ),
          ]);
        case ProgressKind.activity:
          final remarks = _remarksC.text.trim();
          await _repo.recordActivities([
            for (var i = 0; i < ids.length; i++)
              Activity(
                id: 'act-$stamp-$i',
                studentId: ids[i],
                classroomId: widget.classroomId,
                name: t.title,
                date: _date,
                category: t.category,
                result: _result,
                teacherRemarks: remarks.isEmpty ? null : remarks,
                createdBy: widget.teacherId,
                batchId: batch,
              ),
          ]);
        case ProgressKind.observation:
          await _repo.recordObservations([
            for (var i = 0; i < ids.length; i++)
              GrowthObservation(
                id: 'obs-$stamp-$i',
                studentId: ids[i],
                classroomId: widget.classroomId,
                title: t.title,
                body: _bodyC.text.trim(),
                date: now,
                createdBy: widget.teacherId,
                tone: _tone,
                category: t.category,
                batchId: batch,
              ),
          ]);
        case ProgressKind.skill:
          await _repo.rateSkills([
            for (final e in _skillChanges.entries)
              GrowthSkill(
                id: ProgressRepository.skillRowId(e.key, t.title),
                studentId: e.key,
                classroomId: widget.classroomId,
                name: t.title,
                level: SkillLevel.labels[e.value - 1],
                category: t.category,
                framework: 'Teacher assessment',
                ratedBy: widget.teacherId,
              ),
          ]);
      }
      if (!mounted) return;
      Navigator.pop(context, _count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack("Couldn't save — check the internet connection and try again. Nothing was lost.");
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------------------------
  // build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final discard = _selected != null || _who.length != widget.preselected.length;
    return PopScope(
      canPop: !discard || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard this?'),
            content: const Text("You haven't saved yet."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep editing')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(_meta.icon, color: _meta.color, size: 22),
              const SizedBox(width: 10),
              Flexible(child: Text(_meta.action, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: ListView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _step(1, _whatTitle, _presetSection()),
                      if (_selected != null && _hasDetails) ...[
                        const SizedBox(height: 14),
                        _step(2, 'Details', _detailsSection()),
                      ],
                      const SizedBox(height: 14),
                      _step(_selected != null && _hasDetails ? 3 : 2, _whoTitle,
                          _isSkill ? _skillRatingSection() : _studentSection()),
                    ],
                  ),
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  String get _whatTitle => switch (widget.kind) {
        ProgressKind.star => 'What is it for?',
        ProgressKind.activity => 'Which activity?',
        ProgressKind.observation => 'Pick a note',
        ProgressKind.skill => 'Which skill?',
      };

  String get _whoTitle => _isSkill ? 'Set each student\'s level' : 'Who is it for?';

  bool get _hasDetails => widget.kind != ProgressKind.skill;

  Widget _step(int n, String title, Widget child) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _meta.color.withValues(alpha: 0.16),
                ),
                child: Text('$n',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: _meta.color)),
              ),
              const SizedBox(width: 10),
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // --- step 1: presets ---------------------------------------------------------

  Widget _presetSection() {
    final visible = _visibleTemplates;
    final showSearch = _allTemplates.length > 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSearch) ...[
          TextField(
            onChanged: (v) => setState(() => _presetQuery = v),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search presets',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _catChip('All', null),
              if (_myTemplates.isNotEmpty || _sessionTemplates.isNotEmpty) _catChip('Mine', _mine),
              for (final c in _categories) _catChip(c, c),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (widget.kind == ProgressKind.observation)
          ..._observationCards(visible)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _newPresetPill(),
              for (final t in visible)
                SelectPill(
                  label: t.title,
                  selected: _selected?.id == t.id,
                  color: _meta.color,
                  icon: t.isBuiltIn ? null : Icons.bookmark_rounded,
                  onTap: () => _select(t),
                  onLongPress: t.isBuiltIn ? null : () => _deleteTemplate(t),
                ),
            ],
          ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Nothing matches. Tap "Create new" to add your own.',
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted(context)),
            ),
          ),
        if (_myTemplates.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Your presets are marked with a bookmark — long-press one to remove it.',
              style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceHint(context)),
            ),
          ),
      ],
    );
  }

  Widget _catChip(String label, String? value) {
    final selected = _category == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => setState(() => _category = value),
      ),
    );
  }

  Widget _newPresetPill() {
    return ActionChip(
      avatar: Icon(Icons.add_rounded, size: 18, color: _meta.color),
      label: const Text('Create new'),
      onPressed: _createTemplate,
      shape: StadiumBorder(side: BorderSide(color: _meta.color.withValues(alpha: 0.6))),
      backgroundColor: _meta.color.withValues(alpha: 0.08),
    );
  }

  List<Widget> _observationCards(List<ProgressTemplate> visible) {
    return [
      _ObservationPresetCard(
        title: 'Write your own note',
        body: 'Save it as a preset to reuse it for other students.',
        color: _meta.color,
        leadingIcon: Icons.add_rounded,
        selected: false,
        onTap: _createTemplate,
      ),
      for (final t in visible)
        _ObservationPresetCard(
          title: t.title,
          body: t.body,
          color: toneColor(t.tone),
          selected: _selected?.id == t.id,
          mine: !t.isBuiltIn,
          onTap: () => _select(t),
          onLongPress: t.isBuiltIn ? null : () => _deleteTemplate(t),
        ),
    ];
  }

  // --- step 2: details ---------------------------------------------------------

  Widget _detailsSection() {
    switch (widget.kind) {
      case ProgressKind.star:
        return Row(
          children: [
            for (var p = 1; p <= 3; p++) ...[
              Expanded(
                child: _StarChoice(
                  points: p,
                  selected: _points == p,
                  onTap: () => setState(() => _points = p),
                ),
              ),
              if (p < 3) const SizedBox(width: 8),
            ],
          ],
        );
      case ProgressKind.activity:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label('When'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SelectPill(
                  label: 'Today',
                  selected: _isToday(_date),
                  color: _meta.color,
                  onTap: () => setState(() => _date = DateTime.now()),
                ),
                SelectPill(
                  label: _isToday(_date) ? 'Pick a date' : friendlyDate(_date),
                  selected: !_isToday(_date),
                  color: _meta.color,
                  icon: Icons.calendar_today_rounded,
                  onTap: _pickDate,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _label('Result (optional)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in ProgressCatalog.activityResults)
                  SelectPill(
                    label: r,
                    selected: _result == r,
                    color: _meta.color,
                    onTap: () => setState(() => _result = _result == r ? null : r),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _remarksC,
              maxLines: 2,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Remark for parents (optional)',
                hintText: 'e.g. Performed confidently on stage',
              ),
            ),
          ],
        );
      case ProgressKind.observation:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _bodyC,
              maxLines: 5,
              minLines: 3,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What parents will read',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            _label('Type'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tone in ObservationTone.values)
                  SelectPill(
                    label: toneLabel(tone),
                    selected: _tone == tone,
                    color: toneColor(tone),
                    onTap: () => setState(() => _tone = tone),
                  ),
              ],
            ),
            if (_tone == ObservationTone.attention)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Parents get this as an important notification.',
                  style: TextStyle(fontSize: 12, color: AppColors.warning),
                ),
              ),
          ],
        );
      case ProgressKind.skill:
        return const SizedBox.shrink();
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceMuted(context))),
      );

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      locale: const Locale('en', 'IN'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  // --- step 3: students --------------------------------------------------------

  List<Student> get _filteredRoster {
    final q = _studentQuery.trim().toLowerCase();
    if (q.isEmpty) return _roster;
    return _roster
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.rollNumber.toLowerCase() == q ||
            s.admissionNo.toLowerCase().contains(q))
        .toList();
  }

  Widget _studentSection() {
    if (_roster.isEmpty) {
      return Text('No students in this class yet.',
          style: TextStyle(color: AppColors.onSurfaceMuted(context)));
    }
    final all = _who.length == _roster.length;
    final list = _filteredRoster;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_who.length} of ${_roster.length} selected',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted(context)),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                if (all) {
                  _who.clear();
                } else {
                  _who.addAll(_roster.map((s) => s.id));
                }
              }),
              icon: Icon(all ? Icons.remove_done_rounded : Icons.done_all_rounded, size: 18),
              label: Text(all ? 'Clear' : 'Whole class'),
            ),
          ],
        ),
        if (_roster.length > 12) ...[
          const SizedBox(height: 4),
          TextField(
            onChanged: (v) => setState(() => _studentQuery = v),
            decoration: const InputDecoration(
              hintText: 'Find a student',
              prefixIcon: Icon(Icons.person_search_rounded),
              isDense: true,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in list)
              SelectPill(
                label: s.rollNumber.isEmpty ? s.name : '${s.rollNumber}. ${s.name}',
                selected: _who.contains(s.id),
                color: _meta.color,
                leading: _who.contains(s.id)
                    ? null
                    : StudentInitials(name: s.name, size: 28, color: _meta.color),
                onTap: () => setState(() {
                  if (!_who.remove(s.id)) _who.add(s.id);
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _skillRatingSection() {
    final skill = _selected;
    if (skill == null) {
      return Text('Pick a skill above, then tap a level for each student.',
          style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted(context)));
    }
    final list = _filteredRoster;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Set everyone to'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var step = 1; step <= 4; step++)
              ActionChip(
                label: Text(SkillLevel.labels[step - 1]),
                onPressed: () => setState(() {
                  for (final s in _roster) {
                    _levels[s.id] = step;
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'E = Emerging · D = Developing · P = Proficient · A = Advanced',
          style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceHint(context)),
        ),
        if (_roster.length > 12) ...[
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _studentQuery = v),
            decoration: const InputDecoration(
              hintText: 'Find a student',
              prefixIcon: Icon(Icons.person_search_rounded),
              isDense: true,
            ),
          ),
        ],
        const SizedBox(height: 8),
        for (final s in list)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                StudentInitials(name: s.name, size: 32, color: _meta.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Builder(builder: (context) {
                        final now = _existingSkills[s.id]?[skill.title.toLowerCase()];
                        final changed = _skillChanges.containsKey(s.id);
                        return Text(
                          changed
                              ? 'New: ${SkillLevel.labels[_levels[s.id]! - 1]}'
                              : (now == null || now.isEmpty ? 'Not rated yet' : 'Now: $now'),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: changed ? FontWeight.w700 : FontWeight.w400,
                            color: changed ? _meta.color : AppColors.onSurfaceHint(context),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                SkillLevelPicker(
                  compact: true,
                  value: _levels[s.id] ?? 0,
                  onChanged: (v) => setState(() {
                    if (v == 0) {
                      _levels.remove(s.id);
                    } else {
                      _levels[s.id] = v;
                    }
                  }),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AdminLook.canvasOf(context),
        border: Border(
          top: BorderSide(color: AppColors.onSurfaceHint(context).withValues(alpha: 0.2)),
        ),
      ),
      child: _saving
          ? const SizedBox(
              height: 52,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          : SoftPrimaryButton(
              label: _selected == null ? _pickFirstLabel : _saveLabel,
              icon: _canSave ? Icons.check_rounded : null,
              onPressed: _canSave ? _save : null,
            ),
    );
  }

  String get _pickFirstLabel => switch (widget.kind) {
        ProgressKind.star => 'Pick a reason',
        ProgressKind.activity => 'Pick an activity',
        ProgressKind.observation => 'Pick a note',
        ProgressKind.skill => 'Pick a skill',
      };
}

// -----------------------------------------------------------------------------
// pieces
// -----------------------------------------------------------------------------

class _StarChoice extends StatelessWidget {
  final int points;
  final bool selected;
  final VoidCallback onTap;
  const _StarChoice({required this.points, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const gold = AdminLook.gold;
    return Material(
      color: selected ? gold.withValues(alpha: 0.18) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? gold : AppColors.onSurfaceHint(context).withValues(alpha: 0.4),
          width: selected ? 1.8 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < points; i++)
                    const Icon(Icons.star_rounded, color: gold, size: 20),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                points == 1 ? '1 star' : '$points stars',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: AdminLook.inkOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObservationPresetCard extends StatelessWidget {
  final String title;
  final String body;
  final Color color;
  final bool selected;
  final bool mine;
  final IconData? leadingIcon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ObservationPresetCard({
    required this.title,
    required this.body,
    required this.color,
    required this.selected,
    required this.onTap,
    this.mine = false,
    this.leadingIcon,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? color : AppColors.onSurfaceHint(context).withValues(alpha: 0.35),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: leadingIcon != null
                      ? Icon(leadingIcon, size: 18, color: color)
                      : Icon(selected ? Icons.check_circle_rounded : Icons.circle,
                          size: selected ? 18 : 10, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(title,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AdminLook.inkOf(context))),
                          ),
                          if (mine) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.bookmark_rounded,
                                size: 14, color: AppColors.onSurfaceHint(context)),
                          ],
                        ],
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: AppColors.onSurfaceMuted(context))),
                      ],
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

/// "Create your own" preset form. Pops `(template, keepAsPreset)`.
class _TemplateForm extends StatefulWidget {
  final ProgressKind kind;
  final String teacherId;
  const _TemplateForm({required this.kind, required this.teacherId});

  @override
  State<_TemplateForm> createState() => _TemplateFormState();
}

class _TemplateFormState extends State<_TemplateForm> {
  final _titleC = TextEditingController();
  final _bodyC = TextEditingController();
  final _categoryC = TextEditingController();
  late final List<String> _suggested = ProgressCatalog.categoriesFor(widget.kind);
  String? _category;
  ObservationTone _tone = ObservationTone.positive;
  bool _keep = true;

  @override
  void dispose() {
    _titleC.dispose();
    _bodyC.dispose();
    _categoryC.dispose();
    super.dispose();
  }

  bool get _isObs => widget.kind == ProgressKind.observation;

  String get _titleLabel => switch (widget.kind) {
        ProgressKind.star => 'Reason (e.g. Helped organise the class library)',
        ProgressKind.activity => 'Activity name',
        ProgressKind.observation => 'Short title',
        ProgressKind.skill => 'Skill name',
      };

  bool get _valid =>
      _titleC.text.trim().isNotEmpty && (!_isObs || _bodyC.text.trim().isNotEmpty);

  void _submit() {
    if (!_valid) return;
    final category = (_category == null ? _categoryC.text : _category!).trim();
    Navigator.pop(
      context,
      (
        ProgressTemplate(
          id: 'tpl-${DateTime.now().microsecondsSinceEpoch}',
          kind: widget.kind,
          title: _titleC.text.trim(),
          category: category,
          body: _isObs ? _bodyC.text.trim() : '',
          tone: _tone,
          createdBy: widget.teacherId,
        ),
        _keep,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = ProgressKindMeta.of(widget.kind);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              switch (widget.kind) {
                ProgressKind.star => 'New star reason',
                ProgressKind.activity => 'New activity',
                ProgressKind.observation => 'New note',
                ProgressKind.skill => 'New skill',
              },
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AdminLook.inkOf(context)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleC,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: _titleLabel),
            ),
            if (_isObs) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _bodyC,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'What parents will read',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tone in ObservationTone.values)
                    SelectPill(
                      label: toneLabel(tone),
                      selected: _tone == tone,
                      color: toneColor(tone),
                      onTap: () => setState(() => _tone = tone),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text('Group',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceMuted(context))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _suggested)
                  SelectPill(
                    label: c,
                    selected: _category == c,
                    color: meta.color,
                    onTap: () => setState(() => _category = _category == c ? null : c),
                  ),
              ],
            ),
            if (_category == null) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _categoryC,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Or type a new group (optional)',
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _keep,
              onChanged: (v) => setState(() => _keep = v),
              title: const Text('Save to my presets'),
              subtitle: const Text('Reuse it for other students with one tap'),
            ),
            const SizedBox(height: 8),
            SoftPrimaryButton(
              label: 'Use this',
              icon: Icons.check_rounded,
              onPressed: _valid ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
