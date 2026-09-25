import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'progress/progress_widgets.dart';

class HomeworkReviewScreen extends StatefulWidget {
  final Homework homework;
  final String teacherId;

  const HomeworkReviewScreen({
    super.key,
    required this.homework,
    required this.teacherId,
  });

  @override
  State<HomeworkReviewScreen> createState() => _HomeworkReviewScreenState();
}

class _HomeworkReviewScreenState extends State<HomeworkReviewScreen> {
  List<Student> _students = [];
  Map<String, HomeworkCompletion> _completions = {};
  bool _loading = true;
  bool _error = false;
  bool _busy = false;

  HomeworkCompletionRepository get _repo => context.read<HomeworkCompletionRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = false;
      _loading = _students.isEmpty;
    });
    final hw = widget.homework;
    final studentRepo = context.read<StudentRepository>();
    try {
      final students = hw.studentId != null
          ? [
              if (await studentRepo.getById(hw.studentId!) case final s?) s,
            ]
          : await studentRepo.getByClassroom(hw.classroomId);
      final completions = await _repo.forHomework(hw.id);
      if (!mounted) return;
      setState(() {
        _students = sortedRoster(students);
        _completions = {for (final c in completions) c.studentId: c};
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

  HomeworkCompletionStatus _statusOf(String studentId) =>
      _completions[studentId]?.status ?? HomeworkCompletionStatus.pending;

  /// Optimistic: flip locally, write once, roll back if the write fails.
  Future<void> _setStatus(List<Student> students, HomeworkCompletionStatus status) async {
    if (students.isEmpty || _busy) return;
    final before = Map<String, HomeworkCompletion>.from(_completions);
    final rows = [
      for (final s in students)
        _completions[s.id] ??
            HomeworkCompletion(homeworkId: widget.homework.id, studentId: s.id),
    ];
    setState(() {
      _busy = true;
      for (final c in rows) {
        _completions[c.studentId] = c.copyWith(status: status);
      }
    });
    try {
      await _repo.reviewMany(rows, status: status, reviewedBy: widget.teacherId);
      if (!mounted) return;
      setState(() => _busy = false);
      if (students.length > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approved ${students.length} students')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _completions = before;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't save — check the connection and try again."),
      ));
    }
  }

  int _order(HomeworkCompletionStatus s) => switch (s) {
        HomeworkCompletionStatus.underReview => 0,
        HomeworkCompletionStatus.pending => 1,
        HomeworkCompletionStatus.completed => 2,
      };

  @override
  Widget build(BuildContext context) {
    final hw = widget.homework;
    final submitted =
        _students.where((s) => _statusOf(s.id) == HomeworkCompletionStatus.underReview).toList();
    final done =
        _students.where((s) => _statusOf(s.id) == HomeworkCompletionStatus.completed).length;
    final notDone =
        _students.where((s) => _statusOf(s.id) != HomeworkCompletionStatus.completed).toList();
    final ordered = [..._students]
      ..sort((a, b) => _order(_statusOf(a.id)).compareTo(_order(_statusOf(b.id))));

    return Scaffold(
      appBar: AppBar(title: Text(hw.title, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error
                ? EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load submissions",
                    subtitle: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: _load,
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      children: [
                        SoftSurface(
                          depth: SoftDepth.one,
                          borderRadius: BorderRadius.circular(20),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(hw.subject,
                                  style: TextStyle(
                                      color: AppColors.onSurfaceMuted(context), fontSize: 12)),
                              if (hw.description.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(hw.description, style: const TextStyle(fontSize: 13.5, height: 1.35)),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _stat('${submitted.length}', 'to review', AppColors.warning),
                                  const SizedBox(width: 20),
                                  _stat('$done', 'approved', AppColors.success),
                                  const SizedBox(width: 20),
                                  _stat('${_students.length}', 'students',
                                      AppColors.onSurfaceMuted(context)),
                                ],
                              ),
                              if (submitted.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                SoftPrimaryButton(
                                  label: 'Approve all submitted (${submitted.length})',
                                  icon: Icons.done_all_rounded,
                                  onPressed: _busy
                                      ? null
                                      : () => _setStatus(submitted, HomeworkCompletionStatus.completed),
                                ),
                              ] else if (notDone.isNotEmpty && _students.length > 1) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: _busy ? null : () => _confirmAll(notDone),
                                    icon: const Icon(Icons.done_all_rounded),
                                    label: Text('Mark all ${notDone.length} as done'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_students.isEmpty)
                          const EmptyState(
                            icon: Icons.groups_outlined,
                            title: 'No students',
                            subtitle: 'This class has no roster yet.',
                          )
                        else
                          SoftSurface(
                            depth: SoftDepth.one,
                            borderRadius: BorderRadius.circular(20),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              children: [
                                for (var i = 0; i < ordered.length; i++) ...[
                                  if (i > 0) const Divider(height: 1, indent: 60, endIndent: 12),
                                  _row(ordered[i]),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Future<void> _confirmAll(List<Student> students) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark everyone as done?'),
        content: Text('${students.length} students haven\'t submitted in the app. '
            'Use this when you checked the work in class.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark done')),
        ],
      ),
    );
    if (ok == true) _setStatus(students, HomeworkCompletionStatus.completed);
  }

  Widget _row(Student s) {
    final status = _statusOf(s.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          StudentInitials(name: s.name, color: _color(status)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(_label(status), style: TextStyle(fontSize: 11.5, color: _color(status))),
              ],
            ),
          ),
          if (status == HomeworkCompletionStatus.completed)
            TextButton(
              onPressed: _busy ? null : () => _setStatus([s], HomeworkCompletionStatus.pending),
              child: const Text('Undo'),
            )
          else
            FilledButton.tonal(
              onPressed: _busy ? null : () => _setStatus([s], HomeworkCompletionStatus.completed),
              child: Text(status == HomeworkCompletionStatus.underReview ? 'Approve' : 'Mark done'),
            ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted(context))),
        ],
      );

  String _label(HomeworkCompletionStatus s) => switch (s) {
        HomeworkCompletionStatus.pending => 'Not submitted',
        HomeworkCompletionStatus.underReview => 'Submitted — awaiting your review',
        HomeworkCompletionStatus.completed => 'Approved',
      };

  Color _color(HomeworkCompletionStatus s) => switch (s) {
        HomeworkCompletionStatus.pending => AppColors.onSurfaceMuted(context),
        HomeworkCompletionStatus.underReview => AppColors.warning,
        HomeworkCompletionStatus.completed => AppColors.success,
      };
}
