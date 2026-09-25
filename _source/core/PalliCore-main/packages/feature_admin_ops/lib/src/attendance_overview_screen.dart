import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:feature_teacher_attendance/feature_teacher_attendance.dart';
import 'ops_format.dart';

class AttendanceOverviewScreen extends StatefulWidget {
  const AttendanceOverviewScreen({super.key});

  @override
  State<AttendanceOverviewScreen> createState() => _AttendanceOverviewScreenState();
}

class _AttendanceOverviewScreenState extends State<AttendanceOverviewScreen> {
  bool _loading = true;
  bool _hasError = false;
  DateTime _day = DateTime.now();
  List<Student> _students = [];
  List<Classroom> _classrooms = [];
  List<Teacher> _staff = [];
  List<Attendance> _studentRows = [];
  List<StaffAttendance> _staffRows = [];
  List<Attendance> _monthRows = [];

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
      final (students, classrooms, staff, studentRows, staffRows, monthRows) = await (
        context.read<StudentRepository>().getAll(),
        context.read<ClassroomRepository>().getAll(),
        context.read<TeacherRepository>().getAll(),
        context.read<AttendanceRepository>().getByDate(_day),
        context.read<StaffAttendanceRepository>().getByDate(_day),
        context.read<AttendanceRepository>().getByMonth(_day.year, _day.month),
      ).wait;
      if (!mounted) return;
      setState(() {
        _students = students.where((s) => s.lifecycle == StudentLifecycle.enrolled && s.classroomId.isNotEmpty).toList();
        _classrooms = classrooms;
        _staff = staff;
        _studentRows = studentRows;
        _staffRows = staffRows;
        _monthRows = monthRows;
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

  Map<String, AttendanceStatus> get _studentMap {
    final map = <String, AttendanceStatus>{};
    for (final row in _studentRows) {
      map[row.studentId] = row.status;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/admin'),
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Today'),
              Tab(text: 'Class-wise'),
              Tab(text: 'Reports'),
              Tab(text: 'Absent'),
            ],
          ),
        ),
        body: SafeArea(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _hasError
            ? EmptyState(
                icon: Icons.cloud_off_rounded,
                title: "Couldn't load attendance",
                subtitle: 'Check your connection and try again.',
                actionLabel: 'Retry',
                onAction: _load,
              )
            : TabBarView(
                children: [
                  _todayTab(),
                  _classTab(),
                  _reportsTab(),
                  _absentTab(),
                ],
              ),
        ),
      ),
    );
  }

  Widget _todayTab() {
    final map = _studentMap;
    var present = 0, absent = 0;
    for (final student in _students) {
      if (map[student.id] == AttendanceStatus.absent) {
        absent++;
      } else if (map.containsKey(student.id)) {
        present++;
      }
    }
    final teaching = _staff.where((t) => t.isTeaching).toList();
    final staffMap = {for (final row in _staffRows) row.staffId: row.status};
    var staffPresent = 0, staffAbsent = 0;
    for (final member in teaching) {
      if (staffMap[member.id] == AttendanceStatus.absent) {
        staffAbsent++;
      } else {
        staffPresent++;
      }
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Today · ${prettyDate(_day)}', style: TextStyle(color: AppColors.onSurfaceMuted(context))),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _stat('Students present', '$present', AppColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _stat('Students absent', '$absent', AppColors.error)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _stat('Teachers present', '$staffPresent', AppColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _stat('Teachers absent', '$staffAbsent', AppColors.error)),
          ],
        ),
      ],
    );
  }

  Widget _classTab() {
    final map = _studentMap;
    final groups = GradeCatalog.group(_classrooms, includeEmpty: false);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 8),
              child: Text(group.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            ...group.classrooms.map((classroom) {
              final roster = _students.where((s) => s.classroomId == classroom.id).toList();
              final abs = roster.where((s) => map[s.id] == AttendanceStatus.absent).length;
              final pre = roster.where((s) => map.containsKey(s.id) && map[s.id] != AttendanceStatus.absent).length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: Text('${classroom.displayName} · Attendance')),
                          body: SafeArea(
                            child: ClassDailyAttendanceScreen(
                              classroomId: classroom.id,
                              classroomName: classroom.displayName,
                              teacherId: classroom.classTeacherId,
                              readOnly: true,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(14),
      child: Row(
                      children: [
                        Expanded(
                          child: Text(classroom.displayName, style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Text('$pre present · $abs absent', style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _reportsTab() {
    final days = <DateTime, int>{};
    for (final row in _monthRows) {
      if (row.status != AttendanceStatus.absent) continue;
      final key = DateTime(row.date.year, row.date.month, row.date.day);
      days[key] = (days[key] ?? 0) + 1;
    }
    final entries = days.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Daily absences this month', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Daily report uses today\'s roll. Monthly report counts absences logged this month.', style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13)),
        const SizedBox(height: 16),
        _stat('Absences this month', '${_monthRows.where((r) => r.status == AttendanceStatus.absent).length}', AppColors.warning),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          Text('No absence records for this month yet.', style: TextStyle(color: AppColors.onSurfaceHint(context)))
        else
          ...entries.map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(prettyDate(e.key)),
              trailing: Text('${e.value} absent', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  Widget _absentTab() {
    final map = _studentMap;
    final absent = _students.where((s) => map[s.id] == AttendanceStatus.absent).toList();
    if (absent.isEmpty) {
      return const EmptyState(icon: Icons.verified_rounded, title: 'No absences today', subtitle: 'Every marked student is present');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: absent.length,
      itemBuilder: (context, index) {
        final student = absent[index];
        final classroom = _classrooms.where((c) => c.id == student.classroomId);
        return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(16),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
            children: [
              const Icon(Icons.person_off_rounded, color: AppColors.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${classroom.isEmpty ? 'Class' : classroom.first.displayName} · Roll ${student.rollNumber}',
                      style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value, Color color) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13)),
        ],
      ),
    );
  }
}
