import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'progress_recorder_screen.dart';
import 'progress_widgets.dart';

/// One student's progress at a glance — exactly what their parent sees —
/// with the same one-tap actions, pre-set to this student.
class StudentProgressScreen extends StatefulWidget {
  final Student student;
  final String teacherId;
  final String? classroomId;

  /// The rest of the class, so the recorder can add more students to the
  /// same entry. Loaded on demand when not passed.
  final List<Student> classmates;

  const StudentProgressScreen({
    super.key,
    required this.student,
    required this.teacherId,
    this.classroomId,
    this.classmates = const [],
  });

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _Entry {
  final ProgressKind kind;
  final String id;
  final String title;
  final String body;
  final DateTime date;
  final String createdBy;
  final Color color;
  final String badge;

  _Entry({
    required this.kind,
    required this.id,
    required this.title,
    required this.date,
    required this.createdBy,
    required this.color,
    this.body = '',
    this.badge = '',
  });
}

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  List<_Entry> _timeline = [];
  List<GrowthSkill> _skills = [];
  int _stars = 0;
  bool _loading = true;
  bool _error = false;
  List<Student> _classmates = const [];

  ProgressRepository get _repo => context.read<ProgressRepository>();

  @override
  void initState() {
    super.initState();
    _classmates = widget.classmates;
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    final ids = [widget.student.id];
    try {
      final r = await Future.wait<Object>([
        _repo.recentStars(ids, limit: 200),
        _repo.recentActivities(ids),
        _repo.recentObservations(ids),
        _repo.skillsFor(ids),
      ]);
      final stars = r[0] as List<StarPoint>;
      final entries = <_Entry>[
        for (final s in stars)
          _Entry(
            kind: ProgressKind.star,
            id: s.id,
            title: s.reason,
            date: s.createdAt ?? DateTime.now(),
            createdBy: s.awardedBy,
            color: AdminLook.gold,
            badge: '+${s.points} ★',
            body: s.awardedByName,
          ),
        for (final a in r[1] as List<Activity>)
          _Entry(
            kind: ProgressKind.activity,
            id: a.id,
            title: a.name,
            body: [
              if (a.category.isNotEmpty) a.category,
              if ((a.teacherRemarks ?? '').isNotEmpty) a.teacherRemarks!,
            ].join(' · '),
            date: a.date,
            createdBy: a.createdBy,
            color: AppColors.eventCard,
            badge: a.result ?? '',
          ),
        for (final o in r[2] as List<GrowthObservation>)
          _Entry(
            kind: ProgressKind.observation,
            id: o.id,
            title: o.title,
            body: o.body,
            date: o.date,
            createdBy: o.createdBy,
            color: toneColor(o.tone),
            badge: o.tone == ObservationTone.attention ? 'Needs attention' : '',
          ),
      ]..sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) return;
      setState(() {
        _timeline = entries;
        _stars = stars.fold(0, (sum, s) => sum + s.points);
        _skills = (r[3] as List<GrowthSkill>)
          ..sort((a, b) => a.category.compareTo(b.category) != 0
              ? a.category.compareTo(b.category)
              : a.name.compareTo(b.name));
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

  Future<void> _record(ProgressKind kind) async {
    var roster = _classmates;
    if (roster.isEmpty && widget.classroomId != null) {
      try {
        roster = await context.read<StudentRepository>().getByClassroom(widget.classroomId!);
        _classmates = roster;
      } catch (_) {}
    }
    if (!roster.any((s) => s.id == widget.student.id)) roster = [widget.student, ...roster];
    if (!mounted) return;
    final n = await ProgressRecorderScreen.open(
      context,
      kind: kind,
      teacherId: widget.teacherId,
      students: roster,
      classroomId: widget.classroomId,
      preselected: {widget.student.id},
    );
    if (n == null || n == 0 || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Saved — parents can see it now.')));
    _load();
  }

  Future<void> _remove(_Entry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this?'),
        content: Text('"${e.title}" will be removed for ${widget.student.name} only.'),
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
    try {
      await _repo.deleteEntries(e.kind, [e.id]);
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't remove it — check the connection and retry.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.student.name, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error
                ? EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load progress",
                    subtitle: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: () {
                      setState(() => _loading = true);
                      _load();
                    },
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        _header(),
                        const SizedBox(height: 12),
                        _actions(),
                        const SizedBox(height: 22),
                        ProgressSectionTitle('Skills',
                            trailing: _skills.isEmpty ? null : '${_skills.length} rated'),
                        _skillsCard(),
                        const SizedBox(height: 22),
                        const ProgressSectionTitle('History'),
                        _historyCard(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _header() {
    final s = widget.student;
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          StudentInitials(name: s.name, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AdminLook.inkOf(context))),
                const SizedBox(height: 2),
                Text(
                  [
                    if (s.rollNumber.isNotEmpty) 'Roll ${s.rollNumber}',
                    if (s.admissionNo.isNotEmpty) 'Reg. ${s.admissionNo}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceMuted(context)),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: AdminLook.gold, size: 26),
                  const SizedBox(width: 2),
                  Text('$_stars',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AdminLook.inkOf(context))),
                ],
              ),
              Text('stars', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted(context))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        for (final k in ProgressKind.values) ...[
          if (k != ProgressKind.values.first) const SizedBox(width: 8),
          Expanded(
            child: SoftSurface(
              depth: SoftDepth.one,
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              onTap: () => _record(k),
              child: Column(
                children: [
                  Icon(ProgressKindMeta.of(k).icon, color: ProgressKindMeta.of(k).color),
                  const SizedBox(height: 6),
                  Text(
                    switch (k) {
                      ProgressKind.star => 'Star',
                      ProgressKind.activity => 'Activity',
                      ProgressKind.observation => 'Note',
                      ProgressKind.skill => 'Skills',
                    },
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _skillsCard() {
    if (_skills.isEmpty) {
      return _hint('No skills rated yet. Tap "Skills" above to rate a few.');
    }
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        children: [
          for (final s in _skills)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(s.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      Text(s.level,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.examCard)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SkillLevelBar(level: s.level),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _historyCard() {
    if (_timeline.isEmpty) {
      return _hint('Nothing recorded yet. Stars, activities and notes you add show up here — '
          'and in the parent app.');
    }
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < _timeline.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 60, endIndent: 12),
            _row(_timeline[i]),
          ],
        ],
      ),
    );
  }

  Widget _row(_Entry e) {
    final meta = ProgressKindMeta.of(e.kind);
    final mine = e.createdBy == widget.teacherId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: e.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(meta.icon, color: e.color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                    if (e.badge.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(e.badge,
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: e.color)),
                      ),
                  ],
                ),
                if (e.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(e.body,
                      style: TextStyle(
                          fontSize: 13, height: 1.35, color: AppColors.onSurfaceMuted(context))),
                ],
                const SizedBox(height: 3),
                Text(friendlyDate(e.date),
                    style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceHint(context))),
              ],
            ),
          ),
          if (mine)
            IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline_rounded,
                  size: 20, color: AppColors.onSurfaceHint(context)),
              onPressed: () => _remove(e),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(text,
            style: TextStyle(color: AppColors.onSurfaceMuted(context), height: 1.4)),
      );
}
