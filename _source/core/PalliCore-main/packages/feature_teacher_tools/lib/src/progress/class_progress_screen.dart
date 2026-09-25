import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'progress_recorder_screen.dart';
import 'progress_widgets.dart';
import 'student_progress_screen.dart';

/// A class's progress hub: four one-tap actions that record for many
/// students at once, a star board, and what was recorded recently (with undo).
class ClassProgressScreen extends StatefulWidget {
  final Classroom classroom;
  final String teacherId;

  const ClassProgressScreen({super.key, required this.classroom, required this.teacherId});

  static Future<void> open(BuildContext context,
      {required Classroom classroom, required String teacherId}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider.value(value: context.read<ProgressRepository>()),
            RepositoryProvider.value(value: context.read<StudentRepository>()),
          ],
          child: ClassProgressScreen(classroom: classroom, teacherId: teacherId),
        ),
      ),
    );
  }

  @override
  State<ClassProgressScreen> createState() => _ClassProgressScreenState();
}

class _ClassProgressScreenState extends State<ClassProgressScreen> {
  List<Student> _students = [];
  Map<String, int> _stars = {};
  List<ProgressBatch> _recent = [];
  bool _loading = true;
  bool _error = false;
  String _query = '';

  ProgressRepository get _repo => context.read<ProgressRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _students.isEmpty;
      _error = false;
    });
    try {
      final students = sortedRoster(
          await context.read<StudentRepository>().getByClassroom(widget.classroom.id));
      final ids = students.map((s) => s.id).toList();
      final results = await Future.wait<Object>([
        _repo.starTotals(ids),
        _repo.recentStars(ids, limit: 80),
        _repo.recentActivities(ids, limit: 80),
        _repo.recentObservations(ids, limit: 80),
      ]);
      if (!mounted) return;
      setState(() {
        _students = students;
        _stars = results[0] as Map<String, int>;
        _recent = ProgressBatch.group(
          stars: results[1] as List<StarPoint>,
          activities: results[2] as List<Activity>,
          observations: results[3] as List<GrowthObservation>,
        ).take(25).toList();
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

  Future<void> _record(ProgressKind kind, {Set<String> preselected = const {}}) async {
    final n = await ProgressRecorderScreen.open(
      context,
      kind: kind,
      teacherId: widget.teacherId,
      students: _students,
      classroomId: widget.classroom.id,
      preselected: preselected,
    );
    if (n == null || n == 0 || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Saved for ${n == 1 ? '1 student' : '$n students'} — parents can see it now.'),
    ));
    _load();
  }

  Future<void> _openStudent(Student s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider.value(value: _repo),
            RepositoryProvider.value(value: context.read<StudentRepository>()),
          ],
          child: StudentProgressScreen(
            student: s,
            teacherId: widget.teacherId,
            classroomId: widget.classroom.id,
            classmates: _students,
          ),
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openBatch(ProgressBatch b) async {
    final names = {for (final s in _students) s.id: s.name};
    final mine = b.createdBy == widget.teacherId;
    final undo = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final meta = ProgressKindMeta.of(b.kind);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(meta.icon, color: meta.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(b.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${b.subtitle} · ${friendlyDate(b.date)}',
                    style: TextStyle(color: AppColors.onSurfaceMuted(ctx), fontSize: 13)),
                if (b.detail.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(b.detail, style: const TextStyle(fontSize: 14, height: 1.4)),
                ],
                const SizedBox(height: 14),
                Text('${b.studentIds.length} ${b.studentIds.length == 1 ? 'student' : 'students'}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final id in b.studentIds)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(names[id] ?? 'Student'),
                          ),
                      ],
                    ),
                  ),
                ),
                if (mine) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('Undo — remove for all these students'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (undo != true || !mounted) return;
    try {
      await _repo.deleteEntries(b.kind, b.ids);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Removed. Parents no longer see it.')));
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
      appBar: AppBar(
        title: Text('Progress · ${widget.classroom.name}', overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load progress",
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? _students
        : _students
            .where((s) => s.name.toLowerCase().contains(q) || s.rollNumber.toLowerCase() == q)
            .toList();
    final totalStars = _stars.values.fold<int>(0, (a, b) => a + b);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ActionGrid(onTap: _students.isEmpty ? null : (k) => _record(k)),
          if (_students.isEmpty) ...[
            const SizedBox(height: 24),
            const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No students in this class yet',
              subtitle: 'Once students are added you can record their progress here.',
            ),
          ] else ...[
            const SizedBox(height: 22),
            ProgressSectionTitle('Star board', trailing: '$totalStars ★ this year'),
            if (_students.length > 12)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Find a student',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
            SoftSurface(
              depth: SoftDepth.one,
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 60, endIndent: 12),
                    _StudentRow(
                      student: shown[i],
                      stars: _stars[shown[i].id] ?? 0,
                      onTap: () => _openStudent(shown[i]),
                      onStar: () => _record(ProgressKind.star, preselected: {shown[i].id}),
                    ),
                  ],
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No student matches "$_query".',
                          style: TextStyle(color: AppColors.onSurfaceMuted(context))),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const ProgressSectionTitle('Recently recorded'),
            if (_recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'Nothing yet. Use the buttons above — you can record for the whole class in one go.',
                  style: TextStyle(color: AppColors.onSurfaceMuted(context), height: 1.4),
                ),
              )
            else
              SoftSurface(
                depth: SoftDepth.one,
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < _recent.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 60, endIndent: 12),
                      _BatchRow(
                        batch: _recent[i],
                        names: {for (final s in _students) s.id: s.name},
                        onTap: () => _openBatch(_recent[i]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _ActionGrid extends StatelessWidget {
  final void Function(ProgressKind kind)? onTap;
  const _ActionGrid({required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget tile(ProgressKind k) {
      final m = ProgressKindMeta.of(k);
      return Expanded(
        child: SoftSurface(
          depth: SoftDepth.one,
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          onTap: onTap == null ? null : () => onTap!(k),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(m.icon, color: m.color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.action,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AdminLook.inkOf(context))),
                    const SizedBox(height: 2),
                    Text(m.hint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            height: 1.25,
                            color: AppColors.onSurfaceMuted(context))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [tile(ProgressKind.star), const SizedBox(width: 10), tile(ProgressKind.activity)]),
        const SizedBox(height: 10),
        Row(children: [
          tile(ProgressKind.observation),
          const SizedBox(width: 10),
          tile(ProgressKind.skill)
        ]),
      ],
    );
  }
}

class _StudentRow extends StatelessWidget {
  final Student student;
  final int stars;
  final VoidCallback onTap;
  final VoidCallback onStar;

  const _StudentRow({
    required this.student,
    required this.stars,
    required this.onTap,
    required this.onStar,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            StudentInitials(name: student.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                  if (student.rollNumber.isNotEmpty)
                    Text('Roll ${student.rollNumber}',
                        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceHint(context))),
                ],
              ),
            ),
            if (stars > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AdminLook.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 15, color: AdminLook.gold),
                    const SizedBox(width: 3),
                    Text('$stars',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
            IconButton(
              tooltip: 'Give a star',
              onPressed: onStar,
              icon: const Icon(Icons.star_outline_rounded, color: AdminLook.gold),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchRow extends StatelessWidget {
  final ProgressBatch batch;
  final Map<String, String> names;
  final VoidCallback onTap;
  const _BatchRow({required this.batch, required this.names, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = ProgressKindMeta.of(batch.kind);
    final n = batch.studentIds.length;
    final who = n == 1 ? (names[batch.studentIds.first] ?? '1 student') : '$n students';
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: meta.color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(meta.icon, color: meta.color, size: 20),
      ),
      title: Text(batch.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text('$who · ${friendlyDate(batch.date)}',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      trailing: batch.kind == ProgressKind.star
          ? Text('+${batch.points} ★',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AdminLook.gold))
          : const Icon(Icons.chevron_right_rounded),
    );
  }
}

/// Rows written in one teacher action, shown as one line ("Sports day · 12 students").
class ProgressBatch {
  final ProgressKind kind;
  final String title;
  final String subtitle;
  final String detail;
  final DateTime date;
  final String createdBy;
  final int points;
  final List<String> ids = [];
  final List<String> studentIds = [];

  ProgressBatch({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.createdBy,
    this.detail = '',
    this.points = 0,
  });

  static List<ProgressBatch> group({
    List<StarPoint> stars = const [],
    List<Activity> activities = const [],
    List<GrowthObservation> observations = const [],
  }) {
    final byKey = <String, ProgressBatch>{};
    void add(String key, ProgressBatch Function() create, String id, String studentId) {
      final b = byKey.putIfAbsent(key, create);
      b.ids.add(id);
      if (!b.studentIds.contains(studentId)) b.studentIds.add(studentId);
    }

    for (final s in stars) {
      add('s:${s.batchId ?? s.id}', () => ProgressBatch(
            kind: ProgressKind.star,
            title: s.reason,
            subtitle: s.points == 1 ? '1 star each' : '${s.points} stars each',
            date: s.createdAt ?? DateTime.now(),
            createdBy: s.awardedBy,
            points: s.points,
          ), s.id, s.studentId);
    }
    for (final a in activities) {
      add('a:${a.batchId ?? a.id}', () => ProgressBatch(
            kind: ProgressKind.activity,
            title: a.name,
            subtitle: [if (a.category.isNotEmpty) a.category, if ((a.result ?? '').isNotEmpty) a.result!]
                .join(' · '),
            detail: a.teacherRemarks ?? '',
            date: a.date,
            createdBy: a.createdBy,
          ), a.id, a.studentId);
    }
    for (final o in observations) {
      add('o:${o.batchId ?? o.id}', () => ProgressBatch(
            kind: ProgressKind.observation,
            title: o.title,
            subtitle: toneLabel(o.tone),
            detail: o.body,
            date: o.date,
            createdBy: o.createdBy,
          ), o.id, o.studentId);
    }
    return byKey.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }
}
