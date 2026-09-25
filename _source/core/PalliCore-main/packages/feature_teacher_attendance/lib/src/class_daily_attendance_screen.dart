import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';

enum _SortMode { name, roll, register }

enum _MarkMode { present, absent }

/// Daily homeroom roll-call for one classroom — distinct from per-subject
/// attendance. When [readOnly] is true (admin viewing any class) it renders
/// each student's current status instead of an editable checklist.
class ClassDailyAttendanceScreen extends StatefulWidget {
  final String classroomId;
  final String classroomName;
  final String teacherId;
  final bool readOnly;
  final DateTime? date;

  const ClassDailyAttendanceScreen({
    super.key,
    required this.classroomId,
    required this.classroomName,
    required this.teacherId,
    this.readOnly = false,
    this.date,
  });

  @override
  State<ClassDailyAttendanceScreen> createState() => _ClassDailyAttendanceScreenState();
}

const _snackMargin = EdgeInsets.fromLTRB(16, 0, 16, 96);

class _ClassDailyAttendanceScreenState extends State<ClassDailyAttendanceScreen> {
  late final DateTime _date = widget.date ?? DateTime.now();
  bool _loading = true;
  List<Student> _students = [];
  Map<String, AttendanceStatus> _existing = {};
  final Set<String> _checked = {};
  _SortMode _sort = _SortMode.name;
  _MarkMode _mode = _MarkMode.present;
  String _query = '';
  bool _saving = false;
  bool _alreadyMarked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final students = await context.read<StudentRepository>().getByClassroom(widget.classroomId);
    final rows = await context.read<AttendanceRepository>().getHomeroomForClassroom(widget.classroomId, _date);
    if (!mounted) return;
    final existing = {for (final r in rows) r.studentId: r.status};
    setState(() {
      _students = students;
      _existing = existing;
      _mode = _MarkMode.present;
      _checked
        ..clear()
        ..addAll(existing.entries.where((e) => e.value != AttendanceStatus.absent).map((e) => e.key));
      _alreadyMarked = rows.isNotEmpty;
      _loading = false;
    });
  }

  List<Student> get _sorted {
    final list = [...(_query.trim().isEmpty ? _students : _filtered)];
    switch (_sort) {
      case _SortMode.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _SortMode.roll:
        list.sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
      case _SortMode.register:
        list.sort((a, b) => a.admissionNo.compareTo(b.admissionNo));
    }
    return list;
  }

  List<Student> get _filtered {
    final q = _query.trim().toLowerCase();
    return _students.where((s) =>
        s.name.toLowerCase().contains(q) || s.rollNumber.toLowerCase().contains(q) || s.admissionNo.toLowerCase().contains(q)).toList();
  }

  bool _isPresent(Student s) {
    final checked = _checked.contains(s.id);
    return _mode == _MarkMode.present ? checked : !checked;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_students.isEmpty) {
      return const EmptyState(icon: Icons.groups_outlined, title: 'No students in this class yet');
    }
    final sorted = _sorted;
    return Column(
      children: [
        Expanded(
          // A CustomScrollView (rather than a fixed header + Expanded list)
          // means the header controls never fight a shrinking viewport for
          // space — e.g. when the search field's keyboard opens inside an
          // already-short tab — everything just scrolls together instead of
          // overflowing.
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      if (widget.readOnly)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _prettyDate(_date),
                            style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
                          ),
                        )
                      else
                        SoftSegmentedControl(
                          labels: const ['Mark present', 'Mark absent'],
                          index: _mode.index,
                          onChanged: (i) => setState(() => _mode = _MarkMode.values[i]),
                        ),
                      const SizedBox(height: 8),
                      SoftField(
                        child: TextField(
                          onChanged: (val) => setState(() => _query = val),
                          decoration: InputDecoration(
                            hintText: 'Search by name, roll or register number',
                            prefixIcon: const Icon(Icons.search_rounded),
                            border: InputBorder.none,
                            suffixIcon: PopupMenuButton<_SortMode>(
                              tooltip: 'Sort by',
                              icon: Icon(Icons.sort_rounded, color: AppColors.onSurfaceMuted(context)),
                              initialValue: _sort,
                              onSelected: (mode) => setState(() => _sort = mode),
                              itemBuilder: (context) => [
                                CheckedPopupMenuItem(value: _SortMode.name, checked: _sort == _SortMode.name, child: const Text('Name')),
                                CheckedPopupMenuItem(value: _SortMode.roll, checked: _sort == _SortMode.roll, child: const Text('Roll no.')),
                                CheckedPopupMenuItem(value: _SortMode.register, checked: _sort == _SortMode.register, child: const Text('Register no.')),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!widget.readOnly) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '${_checked.length} of ${_students.length} selected',
                              style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12),
                            ),
                            const Spacer(),
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 32),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => setState(() => _checked.addAll(_students.map((s) => s.id))),
                              child: const Text('Select all'),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 32),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => setState(_checked.clear),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (sorted.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('No students found', style: TextStyle(color: AppColors.onSurfaceMuted(context))),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final student = sorted[index];
                        final subtitle = switch (_sort) {
                          _SortMode.name => 'Roll ${student.rollNumber}',
                          _SortMode.roll => 'Roll ${student.rollNumber}',
                          _SortMode.register => 'Reg. ${student.admissionNo}',
                        };
                        if (widget.readOnly) {
                          final status = _existing[student.id];
                          return ListTile(
                            title: Text(student.name),
                            subtitle: Text(subtitle),
                            trailing: _StatusBadge(status: status),
                          );
                        }
                        return CheckboxListTile(
                          value: _checked.contains(student.id),
                          onChanged: (val) => setState(() {
                            if (val == true) {
                              _checked.add(student.id);
                            } else {
                              _checked.remove(student.id);
                            }
                          }),
                          title: Text(student.name),
                          subtitle: Text(subtitle),
                          secondary: Icon(
                            _isPresent(student) ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: _isPresent(student) ? AppColors.success : AppColors.error,
                          ),
                        );
                      },
                      childCount: sorted.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!widget.readOnly)
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SafeArea(
              top: false,
              child: SoftPrimaryButton(
                label: _saving ? 'Saving…' : (_alreadyMarked ? 'Update attendance' : 'Submit attendance'),
                icon: _saving ? null : Icons.check_rounded,
                onPressed: _saving ? null : _submit,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final dateKey = '${_date.year.toString().padLeft(4, '0')}${_date.month.toString().padLeft(2, '0')}${_date.day.toString().padLeft(2, '0')}';
    final rows = _students.map((s) {
      return Attendance(
        id: 'home-${s.id}-$dateKey',
        studentId: s.id,
        classroomId: widget.classroomId,
        periodId: 'homeroom',
        date: _date,
        status: _isPresent(s) ? AttendanceStatus.present : AttendanceStatus.absent,
        markedBy: widget.teacherId,
      );
    }).toList();
    try {
      await context.read<AttendanceRepository>().submitAttendance(rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        // Lifted clear of the Submit bar this screen keeps at its bottom.
        margin: _snackMargin,
        content: Text("Couldn't save attendance — check the connection and try again. Your marks are kept."),
      ));
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _alreadyMarked = true;
      _existing = {for (final r in rows) r.studentId: r.status};
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(margin: _snackMargin, content: Text('Attendance saved')),
    );
  }

  String _prettyDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final AttendanceStatus? status;
  const _StatusBadge({this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return Text('Not marked', style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12));
    }
    Color color;
    String label;
    switch (status!) {
      case AttendanceStatus.present:
        color = AppColors.success;
        label = 'Present';
      case AttendanceStatus.absent:
        color = AppColors.error;
        label = 'Absent';
      case AttendanceStatus.od:
        color = AppColors.warning;
        label = 'OD';
      case AttendanceStatus.delayed:
        color = AppColors.accent;
        label = 'Delayed';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
