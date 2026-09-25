import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

/// "Today at school" composer — one summary per class per day, shown on the
/// parent app's Today screen.
class ClassUpdateScreen extends StatefulWidget {
  final String classroomId;
  final String classroomName;
  final String teacherId;

  const ClassUpdateScreen({
    super.key,
    required this.classroomId,
    required this.classroomName,
    required this.teacherId,
  });

  @override
  State<ClassUpdateScreen> createState() => _ClassUpdateScreenState();
}

class _ClassUpdateScreenState extends State<ClassUpdateScreen> {
  final _noteC = TextEditingController();
  final List<_LearningRow> _learning = [];
  final List<_SignalRow> _signals = [];
  ClassDaySummary? _existing;
  bool _loading = true;
  bool _hasError = false;
  bool _saving = false;

  ClassDaySummaryRepository get _repo => context.read<ClassDaySummaryRepository>();

  // Stored values stay as-is (the parent app renders them); teachers see labels.
  static const _indicators = [
    ('↑', 'Improving'),
    ('👍', 'Doing well'),
    ('steady', 'Steady'),
    ('focus', 'Needs focus'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final existing =
          await _repo.getForClassroomOnDate(widget.classroomId, DateTime.now());
      if (!mounted) return;
      setState(() {
        _existing = existing;
        _noteC.text = existing?.teacherNote ?? '';
        _learning
          ..clear()
          ..addAll((existing?.learning ?? []).map(
              (l) => _LearningRow(subject: l.subject, topic: l.topic)));
        _signals
          ..clear()
          ..addAll((existing?.growthSignals ?? []).map(
              (s) => _SignalRow(name: s.name, indicator: s.indicator)));
        if (_learning.isEmpty) _learning.add(_LearningRow());
        if (_signals.isEmpty) _signals.add(_SignalRow());
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

  @override
  void dispose() {
    _noteC.dispose();
    for (final r in _learning) {
      r.dispose();
    }
    for (final s in _signals) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final diaryRepo = context.read<DiaryNoteRepository>();
    final now = DateTime.now();
    final summary = ClassDaySummary(
      id: _existing?.id ?? 'cds-${now.millisecondsSinceEpoch}',
      classroomId: widget.classroomId,
      summaryDate: DateTime(now.year, now.month, now.day),
      teacherNote: _noteC.text.trim(),
      learning: _learning
          .where((r) => r.subject.text.trim().isNotEmpty)
          .map((r) => LearningItem(
              subject: r.subject.text.trim(), topic: r.topic.text.trim()))
          .toList(),
      growthSignals: _signals
          .where((s) => s.name.text.trim().isNotEmpty)
          .map((s) => GrowthSignal(name: s.name.text.trim(), indicator: s.indicator))
          .toList(),
      createdBy: widget.teacherId,
    );
    try {
      await _repo.upsert(summary);

      // Also drop the note into the class diary so it shows in the parent Diary.
      if (summary.teacherNote.isNotEmpty) {
        await diaryRepo.upsert(DiaryNote(
          id: 'dn-${now.millisecondsSinceEpoch}',
          classroomId: widget.classroomId,
          noteDate: DateTime(now.year, now.month, now.day),
          kind: DiaryNoteKind.teacherNote,
          title: 'Class teacher',
          body: summary.teacherNote,
          createdBy: widget.teacherId,
        ));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't share the update — check the connection and try again."),
      ));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Update shared with parents')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Today · ${widget.classroomName}'),
      ),
      body: SafeArea(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load today's update",
              subtitle: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: _load,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                _section('Teacher note', 'A line for the parents about today'),
                const SizedBox(height: 8),
                SoftField(
                  child: TextField(
                    controller: _noteC,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'The class worked well on ...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _section("Today's learning", 'Subject + topic covered'),
                const SizedBox(height: 8),
                ..._learning.asMap().entries.map((e) => _learningRow(e.key)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _learning.add(_LearningRow())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add subject'),
                  ),
                ),
                const SizedBox(height: 16),
                _section('Growing in', 'Skills the class is building, and how it went'),
                const SizedBox(height: 8),
                ..._signals.asMap().entries.map((e) => _signalRow(e.key)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _signals.add(_SignalRow())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add skill'),
                  ),
                ),
                const SizedBox(height: 28),
                if (_saving)
                  const SizedBox(
                    height: 52,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                  )
                else
                  SoftPrimaryButton(
                    label: _existing == null ? 'Share with parents' : 'Update for parents',
                    icon: Icons.send_rounded,
                    onPressed: _save,
                  ),
              ],
            ),
      ),
    );
  }

  Widget _section(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface(context))),
          Text(subtitle,
              style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12)),
        ],
      );

  Widget _learningRow(int i) {
    final row = _learning[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: row.subject,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Subject', isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: row.topic,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Topic', isDense: true),
            ),
          ),
          if (_learning.length > 1)
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
              onPressed: () => setState(() {
                _learning.removeAt(i).dispose();
              }),
            ),
        ],
      ),
    );
  }

  Widget _signalRow(int i) {
    final row = _signals[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row.name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Skill or value (e.g. Teamwork)',
                    isDense: true,
                  ),
                ),
              ),
              if (_signals.length > 1)
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                  onPressed: () => setState(() {
                    _signals.removeAt(i).dispose();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (value, label) in _indicators)
                ChoiceChip(
                  label: Text(label),
                  selected: row.indicator == value,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => row.indicator = value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LearningRow {
  final TextEditingController subject;
  final TextEditingController topic;
  _LearningRow({String subject = '', String topic = ''})
      : subject = TextEditingController(text: subject),
        topic = TextEditingController(text: topic);
  void dispose() {
    subject.dispose();
    topic.dispose();
  }
}

class _SignalRow {
  final TextEditingController name;
  String indicator;
  _SignalRow({String name = '', this.indicator = '↑'})
      : name = TextEditingController(text: name);
  void dispose() => name.dispose();
}
