import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:go_router/go_router.dart';
import 'ops_format.dart';

class LeaveDeskScreen extends StatefulWidget {
  const LeaveDeskScreen({super.key});

  @override
  State<LeaveDeskScreen> createState() => _LeaveDeskScreenState();
}

class _LeaveDeskScreenState extends State<LeaveDeskScreen> {
  List<LeaveRequest> _leaves = [];
  List<Teacher> _staff = [];
  bool _loading = true;
  bool _hasError = false;

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
      final (leaves, staff) = await (
        context.read<LeaveRequestRepository>().getAll(),
        context.read<TeacherRepository>().getAll(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _leaves = leaves;
        _staff = staff;
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

  Teacher? _teacher(String id) {
    for (final t in _staff) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave & substitution'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: SafeArea(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load leave requests",
              subtitle: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: _load,
            )
          : _leaves.isEmpty
              ? const EmptyState(icon: Icons.event_busy_rounded, title: 'No leave requests', subtitle: 'Teachers can request leave from Classes')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _leaves.length,
                  itemBuilder: (context, index) {
                    final leave = _leaves[index];
                    final teacher = _teacher(leave.teacherId);
                    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(teacher?.name ?? leave.teacherId, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              ),
                              StatusPill(label: leave.status.name, color: _color(leave.status)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('${prettyDate(leave.fromDate)} – ${prettyDate(leave.toDate)}', style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13)),
                          Text(leave.reason, style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 13)),
                          if (leave.coverage.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('${leave.coverage.length} substitute period(s) assigned', style: const TextStyle(color: AppColors.success, fontSize: 12)),
                          ],
                          if (leave.status == LeaveStatus.pending) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => _reject(leave),
                                  child: const Text('Reject'),
                                ),
                                const Spacer(),
                                ElevatedButton(
                                  onPressed: () => _cover(leave),
                                  child: const Text('Approve & cover'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
      ),
    );
  }

  Color _color(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.pending:
        return AppColors.warning;
      case LeaveStatus.approved:
        return AppColors.success;
      case LeaveStatus.rejected:
        return AppColors.error;
    }
  }

  Future<void> _reject(LeaveRequest leave) async {
    await context.read<LeaveRequestRepository>().upsert(leave.copyWith(status: LeaveStatus.rejected));
    await _load();
  }

  /// Who cannot cover [item]: staff with their own class at that hour, staff
  /// on approved leave themselves, and staff already promised to another
  /// period in this same sheet that runs at the same time.
  Map<String, TeacherUnavailable> _blockedSubstitutes({
    required _Affected item,
    required List<StaffBooking> bookings,
    required Map<String, LeaveRequest> onLeave,
    required Map<String, String> picks,
    required List<_Affected> affected,
    required Map<String, String> classroomNames,
  }) {
    final blocked = <String, TeacherUnavailable>{};
    final busy = StaffAvailability.busyDuring(
      bookings,
      dayOfWeek: item.period.dayOfWeek,
      startTime: item.period.startTime,
      durationMinutes: item.period.durationMinutes,
      // The period being covered is the one we're replacing — its own entry
      // must not count as a reason nobody can take it.
      ignorePeriodIds: {item.period.id},
    );
    busy.forEach((staffId, booking) => blocked[staffId] = TeacherUnavailable.fromBooking(booking));
    for (final entry in onLeave.entries) {
      blocked[entry.key] = TeacherUnavailable(
        'On leave',
        detail: '${prettyDate(entry.value.fromDate)} – ${prettyDate(entry.value.toDate)}',
      );
    }
    for (final other in affected) {
      if (other.key == item.key) continue;
      final pickedId = picks[other.key];
      if (pickedId == null) continue;
      if (other.date != item.date) continue;
      if (other.period.dayOfWeek != item.period.dayOfWeek) continue;
      final start = Schedule.minutesOf(other.period.startTime);
      final end = start + other.period.durationMinutes;
      final itemStart = Schedule.minutesOf(item.period.startTime);
      final itemEnd = itemStart + item.period.durationMinutes;
      if (start >= itemEnd || itemStart >= end) continue;
      blocked[pickedId] = TeacherUnavailable(
        'Already covering ${other.period.name} · '
        '${classroomNames[other.timetable.classroomId] ?? other.timetable.classroomId}',
        detail: 'In this same substitution · ${Schedule.range(other.period)}',
      );
    }
    return blocked;
  }

  Future<void> _cover(LeaveRequest leave) async {
    final timetables = await context.read<TimetableRepository>().getAll();
    final classrooms = await context.read<ClassroomRepository>().getAll();
    final affected = <_Affected>[];
    for (var day = DateTime(leave.fromDate.year, leave.fromDate.month, leave.fromDate.day);
        !day.isAfter(leave.toDate);
        day = day.add(const Duration(days: 1))) {
      if (day.weekday > 5) continue;
      final weekday = GradeCatalog.weekdayName(day);
      for (final timetable in timetables.where((t) => t.isActive)) {
        for (final period in timetable.periods) {
          if (period.isTemporary || period.staffId != leave.teacherId) continue;
          if (period.dayOfWeek != weekday) continue;
          if (period.staffId == 'N/A') continue;
          affected.add(_Affected(timetable: timetable, period: period, date: day));
        }
      }
    }

    if (!mounted) return;
    if (affected.isEmpty) {
      await context.read<LeaveRequestRepository>().upsert(leave.copyWith(status: LeaveStatus.approved));
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave approved. No periods needed cover.')));
      }
      return;
    }

    final substitutes = <String, String>{};
    final teaching = _staff.where((t) => t.isTeaching && t.id != leave.teacherId).toList();
    final classroomNames = {for (final c in classrooms) c.id: c.displayName};
    // Everything the school already has its teachers doing on each leave
    // date — resolved per date, so cover already assigned for that day counts
    // too. A substitute who is busy, or on leave themselves, cannot take a
    // period: they are shown greyed out with the reason instead of being
    // silently double-booked.
    final bookingsByDate = <String, List<StaffBooking>>{
      for (final date in {for (final item in affected) item.date})
        date.toIso8601String(): StaffAvailability.bookings(
          timetables,
          on: date,
          classroomNames: classroomNames,
        ),
    };
    final otherLeave = <String, LeaveRequest>{};
    for (final other in _leaves) {
      if (other.id == leave.id || other.status != LeaveStatus.approved) continue;
      final overlaps = !other.toDate.isBefore(leave.fromDate) && !other.fromDate.isAfter(leave.toDate);
      if (overlaps) otherLeave[other.teacherId] = other;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) {
        return SafeArea(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return SizedBox(
                height: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assign substitutes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('${affected.length} periods on the leave dates', style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: affected.length,
                        itemBuilder: (context, index) {
                          final item = affected[index];
                          final classroom = classrooms.where((c) => c.id == item.timetable.classroomId);
                          final pickedId = substitutes[item.key];
                          final picked = pickedId == null
                              ? null
                              : teaching.where((t) => t.id == pickedId).firstOrNull;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final selected = await showTeacherPicker(
                                  context: context,
                                  teachers: teaching,
                                  title: 'Choose substitute',
                                  subtitle: '${item.period.name} · '
                                      '${Schedule.range(item.period)} · ${prettyDate(item.date)}',
                                  selectedId: pickedId,
                                  unavailable: _blockedSubstitutes(
                                    item: item,
                                    bookings: bookingsByDate[item.date.toIso8601String()] ?? const [],
                                    onLeave: otherLeave,
                                    picks: substitutes,
                                    affected: affected,
                                    classroomNames: classroomNames,
                                  ),
                                );
                                if (selected != null) {
                                  setModal(() => substitutes[item.key] = selected.id);
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: '${classroom.isEmpty ? item.timetable.classroomId : classroom.first.displayName} · ${item.period.name} · ${item.period.startTime}',
                                ),
                                child: Text(
                                  picked?.name ?? 'Tap to choose',
                                  style: picked == null ? TextStyle(color: AppColors.onSurfaceHint(context)) : null,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: substitutes.length == affected.length ? () => Navigator.pop(sheet, true) : null,
                        child: const Text('Create temporary timetable'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          ),
        );
      },
    );

    if (saved != true || !mounted) return;
    final coverage = <LeaveCoverage>[
      for (final item in affected)
        LeaveCoverage(
          periodId: item.period.id,
          timetableId: item.timetable.id,
          classroomId: item.timetable.classroomId,
          originalStaffId: leave.teacherId,
          substituteStaffId: substitutes[item.key]!,
          subject: item.period.name,
          startTime: item.period.startTime,
          dayOfWeek: item.period.dayOfWeek,
          date: item.date,
        ),
    ];
    // Several affected periods can share a timetable (the same class across
    // the leave's date range) — addTemporaryCoverage does a read-modify-write,
    // so those must land as one write per timetable, not one per period.
    // Different timetables are independent rows, so those batches run
    // together.
    final byTimetable = <String, List<_Affected>>{};
    for (final item in affected) {
      byTimetable.putIfAbsent(item.timetable.id, () => []).add(item);
    }
    final timetableRepo = context.read<TimetableRepository>();
    await Future.wait(byTimetable.entries.map((entry) => timetableRepo.addTemporaryCoverageBatch(
          timetableId: entry.key,
          assignments: [
            for (final item in entry.value)
              (original: item.period, substituteStaffId: substitutes[item.key]!, date: item.date),
          ],
        )));
    await context.read<LeaveRequestRepository>().upsert(
          leave.copyWith(status: LeaveStatus.approved, coverage: coverage),
        );
    await context.read<AnnouncementRepository>().upsert(
          Announcement(
            id: 'leave-${leave.id}',
            title: 'Substitution assigned',
            content: '${_teacher(leave.teacherId)?.name ?? 'A teacher'} is on leave ${prettyDate(leave.fromDate)}. Temporary periods have been added to the timetable.',
            target: AnnouncementTarget.teachers,
            createdAt: DateTime.now(),
            expiresAt: leave.toDate.add(const Duration(days: 1)),
          ),
        );
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave approved and substitutes notified.')));
    }
  }
}

class _Affected {
  final Timetable timetable;
  final Period period;
  final DateTime date;
  _Affected({required this.timetable, required this.period, required this.date});
  String get key => '${timetable.id}-${period.id}-${date.toIso8601String()}';
}
