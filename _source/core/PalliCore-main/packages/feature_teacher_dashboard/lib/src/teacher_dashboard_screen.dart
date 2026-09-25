import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_teacher_attendance/feature_teacher_attendance.dart';
import 'package:feature_teacher_tools/feature_teacher_tools.dart';
import 'package:feature_library/feature_library.dart';
import 'teacher_dashboard_bloc.dart';
import 'my_week_screen.dart';

class _TakeAttendanceCard extends StatelessWidget {
  final Classroom classroom;
  final String teacherId;
  final bool marked;

  const _TakeAttendanceCard({required this.classroom, required this.teacherId, required this.marked});

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      depth: SoftDepth.two,
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text('${classroom.displayName} · Attendance')),
            body: SafeArea(
              child: ClassDailyAttendanceScreen(
                classroomId: classroom.id,
                classroomName: classroom.displayName,
                teacherId: teacherId,
              ),
            ),
          ),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            marked ? Icons.check_circle_rounded : Icons.fact_check_outlined,
            color: marked ? AppColors.success : AppColors.accent,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Take attendance · ${classroom.displayName}',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.onSurface(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  marked ? 'Marked for today — tap to update' : 'Not marked yet today',
                  style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
        ],
      ),
    );
  }
}

class TeacherDashboardScreen extends StatelessWidget {
  final String teacherId;
  final String teacherName;
  final List<Widget> headerActions;

  const TeacherDashboardScreen({
    super.key,
    required this.teacherId,
    this.teacherName = 'Teacher',
    this.headerActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<TeacherDashboardBloc, TeacherDashboardState>(
          builder: (context, state) {
            if (state is TeacherDashboardInitial) {
              context.read<TeacherDashboardBloc>().add(LoadTeacherDashboard(teacherId));
              return const Center(child: CircularProgressIndicator());
            }
            // The bloc outlives a sign-out, so a second teacher signing in on
            // the same phone arrives to the first one's loaded dashboard —
            // their classes and roll call, under the new teacher's name. Only
            // `Initial` used to trigger a load, and a stale `Loaded` is not
            // `Initial`, so it sat there until the app was killed.
            if (state is TeacherDashboardLoaded && state.teacherId != teacherId) {
              context.read<TeacherDashboardBloc>().add(LoadTeacherDashboard(teacherId));
              return const Center(child: CircularProgressIndicator());
            }
            if (state is TeacherDashboardLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is TeacherDashboardError) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 48),
                      SizedBox(height: 12),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.onSurfaceMuted(context)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            context.read<TeacherDashboardBloc>().add(LoadTeacherDashboard(teacherId)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (state is TeacherDashboardLoaded) {
              return RefreshIndicator(
                color: AppColors.accent,
                onRefresh: () async {
                  context.read<TeacherDashboardBloc>().add(LoadTeacherDashboard(teacherId));
                  await context.read<TeacherDashboardBloc>().stream.firstWhere(
                        (s) => s is TeacherDashboardLoaded || s is TeacherDashboardError,
                      );
                },
                child: _DashboardBody(
                  state: state,
                  teacherName: teacherName,
                  headerActions: headerActions,
                ),
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final TeacherDashboardLoaded state;
  final String teacherName;
  final List<Widget> headerActions;

  const _DashboardBody({
    required this.state,
    required this.teacherName,
    this.headerActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final periods = state.todayPeriods;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SoftPageHeader(
            title: 'Home',
            actions: [
              ...headerActions,
              SoftIconButton(
                icon: Icons.logout_rounded,
                tooltip: 'Sign out',
                elevated: false,
                onTap: () async {
                  final bloc = context.read<LoginBloc>();
                  if (await confirmSignOut(context)) bloc.add(LogoutRequested());
                },
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: NeoClockCard(
            subtitle: 'Good ${_greeting()}',
            title: teacherName,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _WeekStat(label: 'Assigned today', value: '${state.todayAssigned}'),
                  const SizedBox(width: 12),
                  _WeekStat(label: 'Attended today', value: '${state.todayAttended}'),
                  const SizedBox(width: 12),
                  // Was "Missed today", in red. A period that ended without
                  // anyone tapping Start was almost always taught anyway, so
                  // the count accused teachers of something it couldn't know.
                  _WeekStat(label: 'Ended today', value: '${state.todayEnded}'),
                  if (state.reassignedToday > 0) ...[
                    const SizedBox(width: 12),
                    _WeekStat(
                      label: 'Re-assigned today',
                      value: '${state.reassignedToday}',
                      color: AppColors.temporaryPeriod,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (state.myClassroom != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _TakeAttendanceCard(classroom: state.myClassroom!, teacherId: state.teacherId, marked: state.homeroomMarkedToday),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            // A fresh state object per Home refresh, so pull-to-refresh
            // refreshes these counts too.
            child: TeacherExamShortcuts(teacherId: state.teacherId, refreshToken: state),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            // Draws nothing at all unless this teacher heads an event
            // category — see TeacherEventsCard.
            child: TeacherEventsCard(teacherId: state.teacherId, refreshToken: state),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            // Hidden until this teacher borrows their first library book.
            child: BorrowedBooksCard(teacherId: state.teacherId, refreshToken: state),
          ),
        ),
        ContainedSliver(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Today's schedule",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface(context),
                    ),
                  ),
                ),
                Text(
                  periods.isEmpty
                      ? 'Free day'
                      : '${periods.length} period${periods.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: AppColors.onSurfaceHint(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MyWeekScreen(teacherId: state.teacherId)),
                  ),
                  icon: const Icon(Icons.calendar_view_week_rounded, size: 18),
                  label: const Text('My week'),
                ),
              ],
            ),
          ),
        ),
        if (periods.isEmpty)
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 280,
              child: EmptyState(
                icon: Icons.event_available_rounded,
                title: 'No classes today',
                subtitle: 'Pull down anytime to refresh your schedule.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = periods[index];
                  final log = state.classLogs[item.period.id];
                  final status = _PeriodStatus.from(item.period, log);
                  final pendingReassignment = state.pendingOutgoing[item.period.id];
                  return AnimatedListItem(
                    index: index,
                    child: _TimelinePeriodCard(
                      item: item,
                      status: status,
                      teacherId: state.teacherId,
                      isLast: index == periods.length - 1,
                      pendingReassignment: pendingReassignment,
                      myClassroom: state.myClassroom,
                      homeroomMarkedToday: state.homeroomMarkedToday,
                    ),
                  );
                },
                childCount: periods.length,
              ),
            ),
          ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

class ContainedSliver extends StatelessWidget {
  final Widget child;
  const ContainedSliver({super.key, required this.child});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(child: child);
}

class _WeekStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _WeekStat({
    required this.label,
    required this.value,
    this.color = AdminLook.gold,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: SoftSurface(
        depth: SoftDepth.one,
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.05,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.onSurfaceMuted(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A period is only ever ahead, happening, or over. There is deliberately no
/// "missed": not tapping Start on a class you taught is a logging gap, not a
/// failure, and the dashboard shouldn't accuse a teacher of one.
enum _PeriodKind { current, started, upcoming, ended }

class _PeriodStatus {
  final _PeriodKind kind;
  final Color color;
  final String label;
  final IconData icon;

  const _PeriodStatus({
    required this.kind,
    required this.color,
    required this.label,
    required this.icon,
  });

  factory _PeriodStatus.from(Period period, ClassLog? log) {
    final now = DateTime.now();
    final startTime = _parseTime(period.startTime);
    final endTime = startTime.add(Duration(minutes: period.durationMinutes));
    final isCurrent = now.isAfter(startTime) && now.isBefore(endTime);
    final isUpcoming = now.isBefore(startTime);
    final isStarted = log != null && log.status == 'started';

    if (isCurrent && !isStarted) {
      return const _PeriodStatus(
        kind: _PeriodKind.current,
        color: AppColors.currentPeriod,
        label: 'Now',
        icon: Icons.play_circle_fill_rounded,
      );
    }
    if (isStarted) {
      return const _PeriodStatus(
        kind: _PeriodKind.started,
        color: AppColors.success,
        label: 'Taken',
        icon: Icons.check_circle_rounded,
      );
    }
    if (isUpcoming) {
      return const _PeriodStatus(
        kind: _PeriodKind.upcoming,
        color: AppColors.upcomingPeriod,
        label: 'Upcoming',
        icon: Icons.schedule_rounded,
      );
    }
    return const _PeriodStatus(
      kind: _PeriodKind.ended,
      color: AppColors.endedPeriod,
      label: 'Ended',
      icon: Icons.check_rounded,
    );
  }

  static DateTime _parseTime(String timeStr) {
    final now = DateTime.now();
    final parts = timeStr.split(':');
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }
}

class _TimelinePeriodCard extends StatelessWidget {
  final ScheduledPeriod item;
  final _PeriodStatus status;
  final String teacherId;
  final bool isLast;
  final PeriodReassignment? pendingReassignment;
  /// The homeroom this teacher is class teacher of, if any.
  final Classroom? myClassroom;
  final bool homeroomMarkedToday;

  const _TimelinePeriodCard({
    required this.item,
    required this.status,
    required this.teacherId,
    required this.isLast,
    this.pendingReassignment,
    this.myClassroom,
    this.homeroomMarkedToday = false,
  });

  /// Attendance is the class teacher's daily roll call, marked once for the
  /// whole school day. A subject teacher taking it again every period would
  /// both duplicate the work and skew the percentage a parent reads, since
  /// every row counts. So this period only offers roll call when it is the
  /// teacher's own homeroom and nobody has marked it yet today.
  bool get _offersRollCall =>
      myClassroom != null && myClassroom!.id == item.classroomId && !homeroomMarkedToday;

  bool get _canReassign =>
      pendingReassignment == null &&
      (status.kind == _PeriodKind.current || status.kind == _PeriodKind.upcoming);

  /// Breaks and lunch are on the timetable but nobody sets homework for them.
  bool get _teachesSubject {
    final name = item.period.name.toLowerCase();
    return !name.contains('break') && !name.contains('lunch');
  }

  Future<void> _assignHomework(BuildContext context) async {
    final classroom = await context.read<ClassroomRepository>().getById(item.classroomId);
    if (!context.mounted) return;
    if (classroom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open that class — pull down to refresh.")),
      );
      return;
    }
    await AssignHomeworkScreen.open(
      context,
      teacherId: teacherId,
      classrooms: [classroom],
      subjectsByClassroom: {classroom.id: [item.period.name]},
      initialClassroomId: classroom.id,
      initialSubject: item.period.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final period = item.period;
    final endTime = _parseTime(period.startTime).add(Duration(minutes: period.durationMinutes));
    final isNow = status.kind == _PeriodKind.current;
    final bloc = context.read<TeacherDashboardBloc>();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 58,
            child: Column(
              children: [
                Text(
                  Schedule.format12(period.startTime),
                  style: TextStyle(
                    color: isNow ? AppColors.accent : AppColors.onSurface(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _formatEndTime(endTime),
                  style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 11),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: isLast ? Colors.transparent : AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SoftSurface(
              depth: SoftDepth.one,
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
              padding: EdgeInsets.fromLTRB(16, 16, 16, 14),
              borderRadius: BorderRadius.circular(22),
              onTap: () => _showActions(context, bloc),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          period.name,
                          style: TextStyle(
                            color: AppColors.onSurface(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: status.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(status.icon, size: 13, color: status.color),
                            const SizedBox(width: 4),
                            Text(
                              status.label,
                              style: TextStyle(
                                color: status.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.class_outlined, size: 15, color: AppColors.onSurfaceMuted(context)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.classroomName,
                          style: TextStyle(
                            color: AppColors.onSurfaceMuted(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${period.durationMinutes} min',
                        style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 12),
                      ),
                    ],
                  ),
                  if (period.isTemporary) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.temporaryPeriod.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Temporary coverage',
                        style: TextStyle(
                          color: AppColors.temporaryPeriod,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (pendingReassignment != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Reassignment requested',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (isNow) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _startClass(context, bloc),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: Text(_offersRollCall ? 'Start class & roll call' : 'Start class'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.currentPeriod,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startClass(BuildContext context, TeacherDashboardBloc bloc) async {
    bloc.add(StartClass(item.period, teacherId));
    if (_offersRollCall) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text('Roll call · ${myClassroom!.displayName}')),
            body: SafeArea(
              child: ClassDailyAttendanceScreen(
                classroomId: myClassroom!.id,
                classroomName: myClassroom!.displayName,
                teacherId: teacherId,
              ),
            ),
          ),
        ),
      );
      // Coming back from roll call, the dashboard's "not marked yet" card and
      // this period's label are both stale until the day is re-read.
      bloc.add(LoadTeacherDashboard(teacherId));
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${item.period.name} started · ${item.classroomName}'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _showActions(BuildContext context, TeacherDashboardBloc bloc) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(99))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(item.period.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
            if (status.kind == _PeriodKind.current)
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded, color: AppColors.currentPeriod),
                title: const Text('Start class'),
                subtitle: _offersRollCall ? const Text('Opens roll call for your class') : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _startClass(context, bloc);
                },
              ),
            // Assigning from here skips the whole class-and-subject hunt: the
            // teacher has just taught this period, so both are already known.
            if (_teachesSubject)
              ListTile(
                leading: const Icon(Icons.assignment_outlined, color: AppColors.accent),
                title: const Text('Assign homework'),
                subtitle: Text('${item.period.name} · ${item.classroomName}'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _assignHomework(context);
                },
              ),
            ListTile(
              enabled: _canReassign,
              leading: Icon(Icons.swap_horiz_rounded, color: _canReassign ? AppColors.accent : AppColors.onSurfaceHint(context)),
              title: const Text('Reassign to another teacher'),
              subtitle: pendingReassignment != null
                  ? const Text('A reassignment request is already pending for this period')
                  : status.kind == _PeriodKind.started || status.kind == _PeriodKind.ended
                      ? const Text('This period has already started or ended')
                      : const Text('Just for today'),
              onTap: !_canReassign
                  ? null
                  : () {
                      Navigator.pop(sheetContext);
                      _pickSubstitute(context, bloc);
                    },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSubstitute(BuildContext context, TeacherDashboardBloc bloc) async {
    final classroomRepo = context.read<ClassroomRepository>();
    final timetableRepo = context.read<TimetableRepository>();
    final teachers = await context.read<TeacherRepository>().getAll();
    // The librarian never sees a teacher dashboard, so can't take a cover.
    final candidates = teachers.where((t) => t.id != teacherId && !t.isLibrarian).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    // Whoever takes this period has to actually be free for it — asking a
    // teacher to cover an hour they already teach just moves the clash.
    var blocked = const <String, TeacherUnavailable>{};
    try {
      final today = DateTime.now();
      final (classrooms, timetables) = await (classroomRepo.getAll(), timetableRepo.getAll()).wait;
      final busy = StaffAvailability.busyDuring(
        StaffAvailability.bookings(
          timetables,
          on: today,
          classroomNames: {for (final c in classrooms) c.id: c.displayName},
        ),
        dayOfWeek: item.period.dayOfWeek,
        startTime: item.period.startTime,
        durationMinutes: item.period.durationMinutes,
        ignorePeriodIds: {item.period.id},
      );
      blocked = {
        for (final entry in busy.entries) entry.key: TeacherUnavailable.fromBooking(entry.value),
      };
    } catch (_) {
      // Offline: fall back to an unfiltered list rather than blocking cover.
    }
    if (!context.mounted) return;
    final selected = await showTeacherPicker(
      context: context,
      teachers: candidates,
      title: 'Reassign "${item.period.name}"',
      subtitle: '${Schedule.range(item.period)} · they accept or decline covering today only.',
      unavailable: blocked,
    );
    if (selected == null || !context.mounted) return;
    bloc.add(RequestReassignment(item, teacherId, selected.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Asked ${selected.name} to cover "${item.period.name}" today')),
    );
  }

  /// The school reads clock times as 12-hour everywhere — one formatter,
  /// [Schedule.format12], so the dashboard, the week view and the parent's
  /// timetable all agree.
  String _formatEndTime(DateTime endTime) {
    return Schedule.format12(
      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
    );
  }

  DateTime _parseTime(String timeStr) {
    final now = DateTime.now();
    final parts = timeStr.split(':');
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }
}

