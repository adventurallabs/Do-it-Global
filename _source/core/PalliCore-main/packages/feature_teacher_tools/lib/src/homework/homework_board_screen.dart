import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../homework_review_screen.dart';
import 'assign_homework_screen.dart';
import 'homework_progress.dart';

/// The teacher's homework board.
///
/// Everything a teacher assigns used to land in one undifferentiated
/// "Recently assigned" strip showing title and subject only — a teacher with
/// six classes could not tell which class a row belonged to. Here every
/// homework sits under its class, carries a plain-language due date, and shows
/// how many submissions are waiting.
class HomeworkBoardScreen extends StatefulWidget {
  final String teacherId;
  final List<Classroom> classrooms;
  final Map<String, List<String>> subjectsByClassroom;

  /// Homework count held by the bloc. The board lives inside an [IndexedStack]
  /// and so is never rebuilt from scratch; when work is assigned elsewhere —
  /// the class workspace, a timetable period — this changing is what tells it
  /// to go and fetch again.
  final int assignedCount;

  const HomeworkBoardScreen({
    super.key,
    required this.teacherId,
    required this.classrooms,
    required this.subjectsByClassroom,
    this.assignedCount = 0,
  });

  @override
  State<HomeworkBoardScreen> createState() => _HomeworkBoardScreenState();
}

class _HomeworkBoardScreenState extends State<HomeworkBoardScreen> {
  List<Homework> _homework = [];
  Map<String, HomeworkProgress> _progress = {};
  Map<String, String> _studentNames = {};
  bool _loading = true;
  bool _error = false;
  bool _showPast = false;

  /// null = every class.
  String? _classFilter;

  /// Classes whose list is expanded past the first few rows.
  final _expanded = <String>{};

  static const _collapsedRows = 4;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeworkBoardScreen old) {
    super.didUpdateWidget(old);
    final classesArrived =
        old.classrooms.length != widget.classrooms.length && _homework.isEmpty;
    if (classesArrived || old.assignedCount != widget.assignedCount) _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _error = false;
        _loading = _homework.isEmpty;
      });
    }
    try {
      final homeworkRepo = context.read<HomeworkRepository>();
      final completionRepo = context.read<HomeworkCompletionRepository>();
      final studentRepo = context.read<StudentRepository>();

      final results = await Future.wait<dynamic>([
        homeworkRepo.getByTeacher(widget.teacherId),
        studentRepo.getAll(),
      ]);
      final homework = (results[0] as List<Homework>)
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      final students = results[1] as List<Student>;

      final completions =
          await completionRepo.forHomeworkIds([for (final h in homework) h.id]);

      final rosterSize = <String, int>{};
      final names = <String, String>{};
      for (final s in students) {
        names[s.id] = s.name;
        if (s.classroomId.isNotEmpty) {
          rosterSize[s.classroomId] = (rosterSize[s.classroomId] ?? 0) + 1;
        }
      }

      final byHomework = <String, List<HomeworkCompletion>>{};
      for (final c in completions) {
        byHomework.putIfAbsent(c.homeworkId, () => []).add(c);
      }

      final progress = <String, HomeworkProgress>{};
      for (final h in homework) {
        final rows = byHomework[h.id] ?? const <HomeworkCompletion>[];
        progress[h.id] = HomeworkProgress(
          // Work set for one student is measured against that student alone.
          total: h.studentId != null ? 1 : (rosterSize[h.classroomId] ?? 0),
          toReview: rows
              .where((c) => c.status == HomeworkCompletionStatus.underReview)
              .length,
          done: rows
              .where((c) => c.status == HomeworkCompletionStatus.completed)
              .length,
        );
      }

      if (!mounted) return;
      setState(() {
        _homework = homework;
        _progress = progress;
        _studentNames = names;
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

  HomeworkProgress _progressOf(Homework h) => _progress[h.id] ?? const HomeworkProgress();

  /// Past = due date gone by and nothing left for the teacher to act on.
  bool _isPast(Homework h) =>
      isOverdue(h.dueDate) && _progressOf(h).toReview == 0;

  Classroom? _classroomOf(String id) {
    for (final c in widget.classrooms) {
      if (c.id == id) return c;
    }
    return null;
  }

  String _classNameOf(String id) => _classroomOf(id)?.displayName ?? 'Other class';

  int _reviewCountFor(String classroomId) => _homework
      .where((h) => h.classroomId == classroomId)
      .fold(0, (sum, h) => sum + _progressOf(h).toReview);

  int get _totalToReview =>
      _homework.fold(0, (sum, h) => sum + _progressOf(h).toReview);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load homework",
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    final visible = _homework
        .where((h) => _classFilter == null || h.classroomId == _classFilter)
        .where((h) => _showPast || !_isPast(h))
        .toList();

    // Class ids in the teacher's own class order, so the board reads the same
    // way every time rather than reshuffling as due dates pass.
    final order = [
      for (final c in widget.classrooms) c.id,
      ...visible.map((h) => h.classroomId),
    ];
    final grouped = <String, List<Homework>>{};
    for (final id in order) {
      if (visible.any((h) => h.classroomId == id)) {
        grouped.putIfAbsent(id, () => []);
      }
    }
    for (final h in visible) {
      grouped[h.classroomId]!.add(h);
    }
    for (final rows in grouped.values) {
      rows.sort((a, b) {
        // Anything waiting on the teacher floats to the top of its class.
        final ar = _progressOf(a).toReview > 0 ? 0 : 1;
        final br = _progressOf(b).toReview > 0 ? 0 : 1;
        if (ar != br) return ar.compareTo(br);
        return a.dueDate.compareTo(b.dueDate);
      });
    }

    final hiddenPast = _homework
        .where((h) => _classFilter == null || h.classroomId == _classFilter)
        .where(_isPast)
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          SoftPrimaryButton(
            label: 'Assign homework',
            icon: Icons.add_rounded,
            onPressed: widget.classrooms.isEmpty ? null : _assign,
          ),
          if (_totalToReview > 0) ...[
            const SizedBox(height: 14),
            _reviewBanner(),
          ],
          if (widget.classrooms.length > 1) ...[
            const SizedBox(height: 16),
            _classFilterRow(),
          ],
          const SizedBox(height: 16),
          if (grouped.isEmpty)
            _emptyState(hiddenPast)
          else
            for (final entry in grouped.entries) ...[
              _classSection(entry.key, entry.value),
              const SizedBox(height: 14),
            ],
          if (hiddenPast > 0) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showPast = !_showPast),
                icon: Icon(
                  _showPast ? Icons.visibility_off_outlined : Icons.history_rounded,
                  size: 18,
                ),
                label: Text(_showPast
                    ? 'Hide finished homework'
                    : 'Show $hiddenPast finished'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyState(int hiddenPast) {
    final filtered = _classFilter != null;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: EmptyState(
        icon: Icons.assignment_outlined,
        title: filtered
            ? 'Nothing set for ${_classNameOf(_classFilter!)}'
            : hiddenPast > 0
                ? 'Nothing due right now'
                : 'No homework yet',
        subtitle: hiddenPast > 0
            ? 'Every homework here has been finished.'
            : 'Tap "Assign homework" above to set your first one.',
      ),
    );
  }

  Widget _reviewBanner() {
    final classes = widget.classrooms
        .where((c) => _reviewCountFor(c.id) > 0)
        .map((c) => c.displayName)
        .toList();
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Icon(Icons.rate_review_outlined, color: AppColors.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_totalToReview submission${_totalToReview == 1 ? '' : 's'} waiting for you',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  classes.isEmpty ? 'Tap a card below to review' : classes.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.onSurfaceMuted(context), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _classFilterRow() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All classes'),
              selected: _classFilter == null,
              onSelected: (_) => setState(() => _classFilter = null),
            ),
          ),
          for (final c in widget.classrooms)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: _reviewCountFor(c.id) > 0
                    ? CircleAvatar(
                        backgroundColor: AppColors.warning,
                        child: Text(
                          '${_reviewCountFor(c.id)}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      )
                    : null,
                label: Text(c.displayName),
                selected: _classFilter == c.id,
                onSelected: (_) => setState(
                    () => _classFilter = _classFilter == c.id ? null : c.id),
              ),
            ),
        ],
      ),
    );
  }

  Widget _classSection(String classroomId, List<Homework> rows) {
    final isOpen = _expanded.contains(classroomId);
    final shown = isOpen ? rows : rows.take(_collapsedRows).toList();
    final toReview = rows.fold(0, (s, h) => s + _progressOf(h).toReview);
    final subjects = widget.subjectsByClassroom[classroomId] ?? const <String>[];

    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _classNameOf(classroomId),
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: AdminLook.inkOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          '${rows.length} homework',
                          if (subjects.isNotEmpty) subjects.join(', '),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.onSurfaceMuted(context), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (toReview > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$toReview to review',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                // Only for classes the teacher still holds — homework can
                // outlive a timetable change that took the class away.
                if (_classroomOf(classroomId) != null)
                  IconButton(
                    tooltip: 'Assign to ${_classNameOf(classroomId)}',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => _assign(classroomId: classroomId),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 18, endIndent: 18),
            _homeworkRow(shown[i]),
          ],
          if (rows.length > _collapsedRows)
            TextButton(
              onPressed: () => setState(() {
                if (isOpen) {
                  _expanded.remove(classroomId);
                } else {
                  _expanded.add(classroomId);
                }
              }),
              child: Text(isOpen
                  ? 'Show less'
                  : 'Show all ${rows.length} for ${_classNameOf(classroomId)}'),
            ),
        ],
      ),
    );
  }

  Widget _homeworkRow(Homework hw) {
    final progress = _progressOf(hw);
    final individual = hw.studentId != null;
    final who = individual ? (_studentNames[hw.studentId] ?? 'One student') : null;

    return InkWell(
      onTap: () => _openReview(hw),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 6, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (individual) ...[
                        Icon(Icons.person_outline_rounded,
                            size: 15, color: AppColors.accent),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          hw.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.25),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        individual ? '${hw.subject} · $who' : hw.subject,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceMuted(context)),
                      ),
                      Text(' · ',
                          style: TextStyle(color: AppColors.onSurfaceHint(context))),
                      Text(
                        dueLabel(hw.dueDate),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: dueColor(context, hw.dueDate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        progress.toReview > 0
                            ? Icons.rate_review_rounded
                            : progress.allDone
                                ? Icons.check_circle_rounded
                                : Icons.people_outline_rounded,
                        size: 13,
                        color: progress.color(context),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        progress.label,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: progress.color(context)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: Icon(Icons.more_vert_rounded,
                  color: AppColors.onSurfaceHint(context), size: 20),
              onSelected: (value) {
                if (value == 'edit') _edit(hw);
                if (value == 'delete') _confirmDelete(hw);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReview(Homework hw) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeworkReviewScreen(homework: hw, teacherId: widget.teacherId),
      ),
    );
    // Approvals happen in there; the counts here have to catch up.
    if (mounted) _load();
  }

  Future<void> _assign({String? classroomId}) async {
    final saved = await AssignHomeworkScreen.open(
      context,
      teacherId: widget.teacherId,
      classrooms: widget.classrooms,
      subjectsByClassroom: widget.subjectsByClassroom,
      initialClassroomId: classroomId,
    );
    if (saved && mounted) _load();
  }

  Future<void> _edit(Homework hw) async {
    final saved = await AssignHomeworkScreen.open(
      context,
      teacherId: widget.teacherId,
      classrooms: widget.classrooms,
      subjectsByClassroom: widget.subjectsByClassroom,
      existing: hw,
    );
    if (saved && mounted) _load();
  }

  Future<void> _confirmDelete(Homework hw) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this homework?'),
        content: Text(
          '"${hw.title}" will disappear for '
          '${hw.studentId != null ? 'the student' : _classNameOf(hw.classroomId)} '
          'and their parents. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<HomeworkRepository>().remove(hw.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Homework deleted')));
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't delete it — check your connection and try again."),
      ));
    }
  }
}
