import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart';
import 'package:core_data/core_data.dart';
import 'clash_resolver.dart';
import 'timetable_bloc.dart';

class TimetableScreen extends StatefulWidget {
  final Timetable timetable;
  final int? intervalCount;
  final bool readOnly;

  const TimetableScreen({super.key, required this.timetable, this.intervalCount, this.readOnly = false});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  late String _selectedDay = _days[DateTime.now().weekday - 1];
  // Grid first. It used to open on the day view because an empty timetable
  // drew an empty grid, so composing meant inserting periods one at a time.
  // The grid now lays out the blank week from "periods per day" (see
  // Schedule.slotPlan), so the whole week is there to tap from the start.
  List<Teacher> _teachers = [];
  /// Every slot the rest of the school has already booked a teacher into.
  /// Without this the editor only ever saw one classroom, so the same teacher
  /// could be put in front of two classes at the same time.
  List<StaffBooking> _otherBookings = const [];
  Map<String, String> _classroomNames = const {};
  bool _weekView = true;

  @override
  void initState() {
    super.initState();
    _loadStaffContext();
  }

  /// Teachers, the other classrooms' names, and every live period they run —
  /// the three things needed to answer "is this teacher free?".
  Future<void> _loadStaffContext() async {
    try {
      final (teachers, classrooms, timetables) = await (
        context.read<TeacherRepository>().getAll(),
        context.read<ClassroomRepository>().getAll(),
        context.read<TimetableRepository>().getAll(),
      ).wait;
      if (!mounted) return;
      final names = {for (final c in classrooms) c.id: c.displayName};
      setState(() {
        _teachers = teachers;
        _classroomNames = names;
        // Only *other* classrooms count. This classroom's own periods are
        // already checked by the overlap rule, and its other drafts aren't
        // running.
        _otherBookings = StaffAvailability.bookings(
          timetables,
          excludeClassroomIds: {widget.timetable.classroomId},
          classroomNames: names,
        );
      });
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Timetable _resolve(TimetableState state) {
    if (state is TimetablesLoaded) {
      return state.timetables.firstWhere((t) => t.id == widget.timetable.id, orElse: () => widget.timetable);
    }
    return widget.timetable;
  }

  Map<String, String> get _staffNames => {for (final t in _teachers) t.id: t.name};

  String get _classroomName =>
      _classroomNames[widget.timetable.classroomId] ?? widget.timetable.classroomId;

  /// Periods in this timetable whose teacher is already booked by another
  /// class at the same time. Only meaningful once this timetable is live, so
  /// a draft is flagged as a warning and blocked at activation instead.
  List<StaffClash> _staffClashes(Timetable timetable) => StaffAvailability.clashesAgainst(
        timetable.periods,
        others: _otherBookings,
        timetableId: timetable.id,
        timetableName: timetable.name,
        classroomId: timetable.classroomId,
        classroomName: _classroomName,
      );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimetableBloc, TimetableState>(
      builder: (context, state) {
        final timetable = _resolve(state);
        final dayPeriods = [...timetable.periods.where((p) => p.dayOfWeek == _selectedDay && !p.isTemporary)]
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        final remaining = _remaining(timetable, _selectedDay);
        final clashDays = [
          for (final d in _days)
            if (Schedule.overlapsOn(timetable.periods, d).isNotEmpty) d,
        ];
        final clashIds = {
          for (final d in clashDays)
            for (final (a, b) in Schedule.overlapsOn(timetable.periods, d)) ...[a.id, b.id],
        };
        final staffClashes = _staffClashes(timetable);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.readOnly ? '${timetable.name} · view' : timetable.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (!widget.readOnly && !timetable.isActive)
                IconButton(
                  tooltip: 'Set as the active timetable for this classroom',
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  onPressed: () => _activate(context, timetable),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Grid'), icon: Icon(Icons.grid_view_rounded)),
                    ButtonSegment(value: false, label: Text('Day'), icon: Icon(Icons.view_agenda_outlined)),
                  ],
                  selected: {_weekView},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => setState(() => _weekView = selection.first),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
            children: [
              if (!widget.readOnly && !timetable.isActive)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Not active yet — teachers won't see these periods until you activate it.",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _activate(context, timetable),
                        child: const Text('Activate'),
                      ),
                    ],
                  ),
                ),
              if (staffClashes.isNotEmpty)
                _StaffClashBanner(
                  clashes: staffClashes,
                  staffNames: _staffNames,
                  readOnly: widget.readOnly,
                  onReview: () => _openStaffClashes(context, timetable, staffClashes),
                ),
              if (clashDays.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Two periods are booked at the same time on '
                              '${clashDays.map((d) => d.substring(0, 3)).join(', ')}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.readOnly
                                  ? 'Teachers and parents see both periods until an admin fixes it.'
                                  : 'Tap "Fix" to see exactly which periods clash and remove the extra one.',
                              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context)),
                            ),
                          ],
                        ),
                      ),
                      if (!widget.readOnly)
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _openResolver(context, timetable),
                          child: const Text('Fix'),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '${_format12(timetable.startTime)} – ${_format12(timetable.endTime)}',
                      style: TextStyle(color: AppColors.onSurfaceMuted(context), fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      remaining >= 0 ? '$remaining min remaining' : '${-remaining} min over',
                      style: TextStyle(
                        color: remaining >= 0 ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_weekView)
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _days.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final selected = _selectedDay == _days[index];
                      return ChoiceChip(
                        label: Text(_short[index]),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedDay = _days[index]),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: _weekView
                    ? TimetableGrid(
                        bottomPadding: widget.readOnly ? 0 : 88,
                        periods: timetable.periods,
                        dayStartTime: timetable.startTime,
                        dayEndTime: timetable.endTime,
                        intervalCount: widget.intervalCount ?? timetable.intervalCount,
                        staffNames: _staffNames,
                        readOnly: widget.readOnly,
                        clashIds: clashIds,
                        staffClashIds: {for (final c in staffClashes) c.a.periodId},
                        onCellTap: (day, startTime, period, slotMinutes) => _editPeriod(
                          context,
                          timetable,
                          period: period,
                          day: day,
                          startTime: startTime,
                          slotMinutes: slotMinutes,
                        ),
                        onClashTap: (day) => _openResolver(context, timetable, focusDay: day),
                      )
                    : _DayTimeline(
                        periods: dayPeriods,
                        clashesOf: (period) => Schedule.clashesWith(timetable.periods, period),
                        staffClashOf: (period) => StaffAvailability.conflictFor(
                          _otherBookings,
                          staffId: period.staffId,
                          dayOfWeek: period.dayOfWeek,
                          startTime: period.startTime,
                          durationMinutes: period.durationMinutes,
                        ),
                        onFix: () => _openResolver(context, timetable, focusDay: _selectedDay),
                        staffNames: _staffNames,
                        readOnly: widget.readOnly,
                        onAdd: () => _editPeriod(context, timetable, day: _selectedDay),
                        onEdit: (period) => _editPeriod(context, timetable, period: period, day: _selectedDay),
                      ),
              ),
            ],
            ),
          ),
          // Present in both views. It used to exist only in day view, so
          // composing a week meant discovering the toggle first.
          floatingActionButton: widget.readOnly
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _editPeriod(
                    context,
                    timetable,
                    day: _weekView ? _firstDayToFill(timetable) : _selectedDay,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add period'),
                  shape: const StadiumBorder(),
                ),
        );
      },
    );
  }

  int _remaining(Timetable timetable, String day) {
    final start = _minutes(timetable.startTime);
    final end = _minutes(timetable.endTime);
    final used = timetable.periods.where((p) => p.dayOfWeek == day && !p.isTemporary).fold<int>(0, (sum, p) => sum + p.durationMinutes);
    return (end - start) - used;
  }

  int _minutes(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String _format12(String value) {
    final parts = value.split(':');
    final hour = int.parse(parts[0]);
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${parts[1]} $suffix';
  }

  /// The day the grid's "Add period" should open on: the first weekday that
  /// still has room, so filling an empty week runs Monday-first instead of
  /// always landing on today.
  String _firstDayToFill(Timetable timetable) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    for (final day in weekdays) {
      if (_remaining(timetable, day) > 0) return day;
    }
    return _selectedDay;
  }

  /// When adding a fresh period with no explicit slot tapped (e.g. from the
  /// FAB in day view), default its start time to right after the last period
  /// already on that day — so periods chain together without manual entry.
  String? _suggestedStartTime(Timetable timetable, String day) {
    final dayPeriods = [...timetable.periods.where((p) => p.dayOfWeek == day && !p.isTemporary)]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (dayPeriods.isEmpty) return timetable.startTime;
    final last = dayPeriods.last;
    final endMinutes = _minutes(last.startTime) + last.durationMinutes;
    final hour = (endMinutes ~/ 60) % 24;
    final minute = endMinutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Activating a draft is the moment its periods start competing with the
  /// rest of the school, so it is the last place a double-booking can slip
  /// through. Refuse quietly-broken data: name every clash first.
  Future<void> _activate(BuildContext context, Timetable timetable) async {
    final bloc = context.read<TimetableBloc>();
    final clashes = _staffClashes(timetable);
    if (clashes.isNotEmpty) {
      final proceed = await _confirmActivateWithClashes(context, clashes);
      if (proceed != true) {
        if (context.mounted) _openStaffClashes(context, timetable, clashes);
        return;
      }
    }
    bloc.add(ActivateTimetable(timetable.id, timetable.classroomId));
  }

  Future<bool?> _confirmActivateWithClashes(BuildContext context, List<StaffClash> clashes) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Teachers are double-booked'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Going live would put ${clashes.length == 1 ? 'a teacher' : '${clashes.length} periods\' teachers'} '
              'in two classrooms at the same time:',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            for (final clash in clashes.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• ${_staffNames[clash.staffId] ?? clash.staffId} — ${clash.a.dayOfWeek} ${clash.a.range}: '
                  '${clash.a.periodName} here and ${clash.b.periodName} for ${clash.b.classroomName}',
                  style: TextStyle(fontSize: 13, height: 1.35, color: AppColors.onSurfaceMuted(ctx)),
                ),
              ),
            if (clashes.length > 4)
              Text('…and ${clashes.length - 4} more',
                  style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted(ctx))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Review clashes')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Activate anyway'),
          ),
        ],
      ),
    );
  }

  void _openStaffClashes(BuildContext context, Timetable timetable, List<StaffClash> clashes) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StaffClashSheet(
        clashes: clashes,
        staffNames: _staffNames,
        readOnly: widget.readOnly,
        onFix: (clash) {
          Navigator.pop(context);
          final latest = _resolve(context.read<TimetableBloc>().state);
          final period = latest.periods.where((p) => p.id == clash.a.periodId).firstOrNull;
          if (period == null) return;
          _editPeriod(context, latest, period: period, day: period.dayOfWeek);
        },
      ),
    );
  }

  void _openResolver(BuildContext context, Timetable timetable, {String? focusDay}) {
    showClashResolver(
      context,
      timetable: timetable,
      staffNames: _staffNames,
      focusDay: focusDay,
      onEdit: (period) {
        final latest = _resolve(context.read<TimetableBloc>().state);
        _editPeriod(context, latest, period: period, day: period.dayOfWeek);
      },
    );
  }

  void _editPeriod(
    BuildContext context,
    Timetable timetable, {
    Period? period,
    String? day,
    String? startTime,
    int? slotMinutes,
  }) {
    if (widget.readOnly) return;
    final resolvedDay = day ?? period?.dayOfWeek ?? _selectedDay;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PeriodSheet(
        period: period,
        initialDay: day,
        initialStartTime: startTime ?? (period == null ? _suggestedStartTime(timetable, resolvedDay) : null),
        // An empty cell already knows how long its row runs, so the form
        // opens on that rather than a fixed 45.
        initialDuration: period == null ? slotMinutes : null,
        // The librarian has no timetable screen of their own, so a period
        // given to them would never be seen or taught.
        teachers: _teachers.where((t) => !t.isLibrarian).toList(),
        existing: timetable.periods,
        otherBookings: _otherBookings,
        remainingMinutes: _remaining(timetable, resolvedDay),
        onSave: (next, applyWeekdays) {
          final bloc = context.read<TimetableBloc>();
          if (period == null) {
            bloc.add(AddPeriod(timetable.id, next, applyWeekdays: applyWeekdays));
          } else {
            bloc.add(UpdatePeriod(timetable.id, next));
          }
        },
        onDelete: period == null
            ? null
            : () async {
                final bloc = context.read<TimetableBloc>();
                final ids = await confirmPeriodDelete(
                  context,
                  period: period,
                  siblings: periodSiblings(timetable.periods, period),
                  staffName: _staffNames[period.staffId],
                );
                if (ids == null) return;
                bloc.add(DeletePeriods(timetable.id, ids));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ids.length == 1
                      ? 'Deleted ${period.name} · ${period.dayOfWeek} ${Schedule.format12(period.startTime)}'
                      : 'Deleted ${period.name} from ${ids.length} days'),
                ));
              },
        onTemporary: period == null
            ? null
            : (next) => context.read<TimetableBloc>().add(
                  UpdatePeriod(timetable.id, next.copyWith(isTemporary: true, date: DateTime.now()), isTemporary: true),
                ),
      ),
    );
  }
}

class _DayTimeline extends StatelessWidget {
  final List<Period> periods;
  final List<Period> Function(Period period) clashesOf;
  /// The other class this period's teacher is already in at that hour.
  final StaffBooking? Function(Period period) staffClashOf;
  final VoidCallback onFix;
  final Map<String, String> staffNames;
  final bool readOnly;
  final VoidCallback onAdd;
  final ValueChanged<Period> onEdit;

  const _DayTimeline({
    required this.periods,
    required this.clashesOf,
    required this.staffClashOf,
    required this.onFix,
    required this.staffNames,
    required this.readOnly,
    required this.onAdd,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) {
      return EmptyState(
        icon: Icons.schedule_rounded,
        title: 'No periods this day',
        subtitle: 'Add subjects, breaks and lunch in the order the class follows them.',
        actionLabel: readOnly ? null : 'Add period',
        onAction: readOnly ? null : onAdd,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: periods.length,
      itemBuilder: (context, index) {
        final period = periods[index];
        final staff = staffNames[period.staffId];
        final clashes = clashesOf(period);
        final staffClash = staffClashOf(period);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: readOnly ? null : () => onEdit(period),
              child: SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16),
      child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 44,
                      decoration: BoxDecoration(
                        color: clashes.isNotEmpty
                            ? AppColors.error
                            : staffClash != null
                                ? AppColors.warning
                                : AppColors.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(period.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            '${_format12(period.startTime)} – ${Schedule.format12(Schedule.endTime(period))}'
                            '${staff == null || staff.isEmpty ? '' : ' · $staff'}',
                            style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13),
                          ),
                          if (clashes.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Same time as ${clashes.map((c) => '${c.name} (${Schedule.range(c)})').join(', ')}',
                                style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          if (staffClash != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${staff ?? 'This teacher'} also takes ${staffClash.periodName} for '
                                '${staffClash.classroomName} at ${staffClash.range}',
                                style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!readOnly && clashes.isNotEmpty)
                      TextButton(
                        onPressed: onFix,
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        child: const Text('Fix'),
                      )
                    else if (!readOnly)
                      Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _format12(String value) {
    final parts = value.split(':');
    final hour = int.parse(parts[0]);
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${parts[1]} $suffix';
  }
}

class _PeriodSheet extends StatefulWidget {
  final Period? period;
  final List<Teacher> teachers;
  final List<Period> existing;

  /// What the rest of the school has this teacher doing. Empty means the
  /// check is simply unavailable (offline), never that everyone is free.
  final List<StaffBooking> otherBookings;
  final String? initialDay;
  final String? initialStartTime;
  /// How long the grid row this cell sits in runs. Only used for a new
  /// period — an existing one keeps its own length.
  final int? initialDuration;
  final int remainingMinutes;
  final void Function(Period period, bool applyWeekdays) onSave;
  final VoidCallback? onDelete;
  final ValueChanged<Period>? onTemporary;

  const _PeriodSheet({
    this.period,
    required this.teachers,
    this.existing = const [],
    this.otherBookings = const [],
    this.initialDay,
    this.initialStartTime,
    this.initialDuration,
    required this.remainingMinutes,
    required this.onSave,
    this.onDelete,
    this.onTemporary,
  });

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController(text: '45');
  String _selectedStaffId = 'N/A';
  String _dayOfWeek = 'Monday';
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  bool _applyWeekdays = false;
  String? _clash;
  /// Length that would make the candidate end right when the clashing
  /// period starts — offered as a one-tap fix.
  int? _fitMinutes;

  List<Period> get _currentClashes =>
      widget.period == null ? const [] : Schedule.clashesWith(widget.existing, widget.period!);

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  /// Every day this save would write to — one, or all five when "Repeat
  /// Mon–Fri" is on. A teacher free on Monday can still be busy on Thursday,
  /// so availability has to be checked against all of them.
  List<String> get _targetDays =>
      _applyWeekdays && widget.period == null ? _weekdays : [_dayOfWeek];

  Teacher? get _selectedStaff =>
      widget.teachers.where((t) => t.id == _selectedStaffId).firstOrNull;

  int get _duration {
    final value = int.tryParse(_durationController.text);
    return value != null && value > 0 ? value : 45;
  }

  String get _startHhmm =>
      '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';

  /// The other class this teacher is already standing in front of during the
  /// slot currently shown in the form, if any.
  StaffBooking? get _staffConflict {
    if (!StaffAvailability.isRealStaff(_selectedStaffId)) return null;
    for (final day in _targetDays) {
      final conflict = StaffAvailability.conflictFor(
        widget.otherBookings,
        staffId: _selectedStaffId,
        dayOfWeek: day,
        startTime: _startHhmm,
        durationMinutes: _duration,
      );
      if (conflict != null) return conflict;
    }
    return null;
  }

  /// Null when the period fits; otherwise a message naming the clash.
  String? _findClash(Period candidate) {
    final days = _applyWeekdays && widget.period == null ? _weekdays : [candidate.dayOfWeek];
    _fitMinutes = null;
    for (final day in days) {
      final other = Schedule.clashFor(widget.existing, candidate, day, ignoreId: widget.period?.id);
      if (other != null) {
        final start = Schedule.minutesOf(candidate.startTime);
        final otherStart = Schedule.minutesOf(other.startTime);
        final free = otherStart - start;
        if (free > 0) _fitMinutes = free;
        final hint = free > 0
            ? 'Shorten this to $free min so it ends at ${Schedule.format12(other.startTime)}, '
                'or start it at ${Schedule.format12(Schedule.endTime(other))} or later.'
            : 'Start it at ${Schedule.format12(Schedule.endTime(other))} or later, '
                'or delete ${other.name} on $day first.';
        return 'On $day, ${other.name} is already booked from ${Schedule.range(other)}. $hint';
      }
    }
    return null;
  }

  /// The hard rule: one teacher, one classroom, one time. Checked again here
  /// because the admin can pick a free teacher and *then* move the period.
  String? _findStaffClash(Period candidate) {
    if (!StaffAvailability.isRealStaff(candidate.staffId)) return null;
    final days = _applyWeekdays && widget.period == null ? _weekdays : [candidate.dayOfWeek];
    final name = _selectedStaff?.name ?? 'That teacher';
    for (final day in days) {
      final booking = StaffAvailability.conflictFor(
        widget.otherBookings,
        staffId: candidate.staffId,
        dayOfWeek: day,
        startTime: candidate.startTime,
        durationMinutes: candidate.durationMinutes,
      );
      if (booking != null) {
        return '$name already takes ${booking.periodName} for ${booking.classroomName} on $day, '
            '${booking.range}. Nobody can teach two classes at once — pick another teacher, '
            'or move this period outside ${booking.range}.';
      }
    }
    return null;
  }

  Future<void> _pickStaff() async {
    final days = _targetDays;
    final busy = StaffAvailability.busyDuringDays(
      widget.otherBookings,
      days: days,
      startTime: _startHhmm,
      durationMinutes: _duration,
    );
    final unavailable = {
      for (final entry in busy.entries) entry.key: TeacherUnavailable.fromBooking(entry.value),
    };
    final slot = '${days.length > 1 ? 'Mon–Fri' : _dayOfWeek} · '
        '${Schedule.format12(_startHhmm)} – ${Schedule.format12(Schedule.hhmm(Schedule.minutesOf(_startHhmm) + _duration))}';
    final pick = await showStaffPicker(
      context: context,
      teachers: widget.teachers,
      title: 'Who takes this period?',
      subtitle: slot,
      unavailable: unavailable,
      noneLabel: 'No staff (break / lunch)',
      noneSubtitle: 'Use for breaks, lunch and free periods',
      selectedId: _selectedStaffId,
    );
    if (pick == null || !mounted) return;
    setState(() {
      _selectedStaffId = pick.teacher?.id ?? StaffAvailability.noStaffId;
      _clash = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _dayOfWeek = widget.initialDay ?? 'Monday';
    if (widget.initialStartTime != null) {
      final parts = widget.initialStartTime!.split(':');
      _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    if (widget.initialDuration != null && widget.initialDuration! > 0) {
      _durationController.text = widget.initialDuration!.toString();
    }
    if (widget.period != null) {
      _nameController.text = widget.period!.name;
      _durationController.text = widget.period!.durationMinutes.toString();
      _selectedStaffId = widget.period!.staffId.isEmpty ? 'N/A' : widget.period!.staffId;
      _dayOfWeek = widget.period!.dayOfWeek;
      final parts = widget.period!.startTime.split(':');
      if (parts.length == 2) {
        _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
    final staffIds = {'N/A', ...widget.teachers.map((t) => t.id)};
    if (!staffIds.contains(_selectedStaffId)) _selectedStaffId = 'N/A';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(99))),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.period == null ? 'Add period' : 'Edit ${widget.period!.name}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.4),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.period == null
                      ? '${widget.remainingMinutes} minutes free on $_dayOfWeek'
                      : '${widget.period!.dayOfWeek} · ${Schedule.range(widget.period!)}',
                  style: TextStyle(color: widget.remainingMinutes >= 0 ? AppColors.onSurfaceMuted(context) : AppColors.error, fontSize: 13),
                ),
                if (_currentClashes.isNotEmpty && _clash == null) ...[
                  const SizedBox(height: 12),
                  _ClashNote(
                    text: 'Right now this runs at the same time as '
                        '${_currentClashes.map((c) => '${c.name} (${Schedule.range(c)})').join(', ')}. '
                        'Change the time or length below, or delete one of them.',
                  ),
                ],
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter a period name' : null,
                  decoration: const InputDecoration(labelText: 'Period name', hintText: 'Mathematics, Break, Lunch'),
                ),
                const SizedBox(height: 12),
                _StaffField(
                  teacher: _selectedStaff,
                  isNone: !StaffAvailability.isRealStaff(_selectedStaffId),
                  conflict: _staffConflict,
                  onTap: _pickStaff,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: _startTime);
                          if (picked != null) {
                            setState(() {
                              _startTime = picked;
                              _clash = null;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Start time'),
                          child: Text(_startTime.format(context)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Ends at'),
                        child: Text(
                          _endTime().format(context),
                          style: TextStyle(color: AppColors.onSurfaceMuted(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => _clash = null),
                  validator: (value) {
                    final duration = int.tryParse(value ?? '');
                    return duration == null || duration <= 0 ? 'Enter minutes greater than 0' : null;
                  },
                  decoration: const InputDecoration(labelText: 'Duration (minutes)', helperText: 'End time updates automatically'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _dayOfWeek,
                  items: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) => setState(() {
                    _dayOfWeek = val ?? _dayOfWeek;
                    _clash = null;
                  }),
                  decoration: const InputDecoration(labelText: 'Day'),
                ),
                if (widget.period == null) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Repeat Mon–Fri'),
                    subtitle: const Text('Places this period on every weekday'),
                    value: _applyWeekdays,
                    onChanged: (value) => setState(() {
                      _applyWeekdays = value;
                      _clash = null;
                    }),
                  ),
                ],
                const SizedBox(height: 20),
                if (_clash != null) ...[
                  _ClashNote(
                    text: _clash!,
                    actionLabel: _fitMinutes == null ? null : 'Shorten to $_fitMinutes min',
                    onAction: _fitMinutes == null
                        ? null
                        : () => setState(() {
                              _durationController.text = '$_fitMinutes';
                              _clash = null;
                              _fitMinutes = null;
                            }),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton(
                  onPressed: () {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    final next = _buildPeriod();
                    final clash = _findClash(next);
                    if (clash != null) {
                      setState(() => _clash = clash);
                      return;
                    }
                    final staffClash = _findStaffClash(next);
                    if (staffClash != null) {
                      setState(() {
                        _fitMinutes = null;
                        _clash = staffClash;
                      });
                      return;
                    }
                    widget.onSave(next, _applyWeekdays);
                    Navigator.pop(context);
                  },
                  child: const Text('Save period'),
                ),
                if (widget.onTemporary != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      final next = _buildPeriod();
                      // A one-day cover is still a real class — the stand-in
                      // has to be free for it, same as anyone else.
                      final staffClash = _findStaffClash(next);
                      if (staffClash != null) {
                        setState(() {
                          _fitMinutes = null;
                          _clash = staffClash;
                        });
                        return;
                      }
                      widget.onTemporary!(next);
                      Navigator.pop(context);
                    },
                    child: const Text('Substitute for today only'),
                  ),
                ],
                if (widget.onDelete != null)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDelete!();
                    },
                    child: const Text('Delete period', style: TextStyle(color: AppColors.error)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TimeOfDay _endTime() {
    final duration = int.tryParse(_durationController.text) ?? 0;
    final totalMinutes = _startTime.hour * 60 + _startTime.minute + duration;
    return TimeOfDay(hour: (totalMinutes ~/ 60) % 24, minute: totalMinutes % 60);
  }

  Period _buildPeriod() {
    final duration = int.tryParse(_durationController.text);
    return Period(
      id: widget.period?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      staffId: _selectedStaffId,
      startTime: '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
      durationMinutes: duration != null && duration > 0 ? duration : 45,
      dayOfWeek: _dayOfWeek,
      isTemporary: widget.period?.isTemporary ?? false,
      date: widget.period?.date,
    );
  }
}

/// The staff row in the period sheet: who is taking it, and — the moment the
/// day or time changes under a chosen teacher — a live warning that they are
/// no longer free.
class _StaffField extends StatelessWidget {
  final Teacher? teacher;
  final bool isNone;
  final StaffBooking? conflict;
  final VoidCallback onTap;

  const _StaffField({
    required this.teacher,
    required this.isNone,
    required this.conflict,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final busy = conflict != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Staff',
              errorText: busy ? 'Not free at this time' : null,
              suffixIcon: const Icon(Icons.search_rounded, size: 20),
            ),
            child: Row(
              children: [
                if (isNone)
                  Icon(Icons.free_breakfast_outlined, size: 18, color: AppColors.onSurfaceMuted(context))
                else
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: (busy ? AppColors.error : AppColors.accent).withValues(alpha: 0.15),
                    child: Text(
                      (teacher?.name.isNotEmpty ?? false) ? teacher!.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: busy ? AppColors.error : AppColors.accent,
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isNone ? 'No staff (break / lunch)' : (teacher?.name ?? 'Tap to choose'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isNone ? AppColors.onSurfaceMuted(context) : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 6),
          Text(
            '${teacher?.name ?? 'This teacher'} takes ${conflict!.periodName} for '
            '${conflict!.classroomName} on ${conflict!.detail}.',
            style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

/// Sits above the timetable when a teacher in it is already booked by another
/// class — the damage the old editor could save before anyone noticed.
class _StaffClashBanner extends StatelessWidget {
  final List<StaffClash> clashes;
  final Map<String, String> staffNames;
  final bool readOnly;
  final VoidCallback onReview;

  const _StaffClashBanner({
    required this.clashes,
    required this.staffNames,
    required this.readOnly,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final people = {for (final c in clashes) staffNames[c.staffId] ?? c.staffId};
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_off_outlined, size: 20, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clashes.length == 1
                      ? '${people.first} is in another class at the same time'
                      : '${clashes.length} periods need a teacher who is in another class',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error),
                ),
                const SizedBox(height: 2),
                Text(
                  readOnly
                      ? 'An admin has to give one of the two classes a different teacher.'
                      : 'Nobody can teach two classes at once. Tap "Review" to see each one.',
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context)),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onReview,
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }
}

/// Lists every period whose teacher belongs to another class at that hour,
/// naming both sides so the admin can decide which one to change.
class _StaffClashSheet extends StatelessWidget {
  final List<StaffClash> clashes;
  final Map<String, String> staffNames;
  final bool readOnly;
  final ValueChanged<StaffClash> onFix;

  const _StaffClashSheet({
    required this.clashes,
    required this.staffNames,
    required this.readOnly,
    required this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.onSurfaceHint(context).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('One teacher, two classes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Each row is a period here whose teacher is already standing in front of '
            'another class at that time. Give one of the two a different teacher, or '
            'move this period to an hour they are free.',
            style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          for (final clash in clashes)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.07),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(99)),
                        child: Text(clash.dayOfWeek.substring(0, 3),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          staffNames[clash.staffId] ?? clash.staffId,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _Side(
                    icon: Icons.edit_calendar_outlined,
                    title: '${clash.a.periodName} · ${clash.a.classroomName}',
                    subtitle: '${clash.a.range} · this timetable',
                  ),
                  const SizedBox(height: 6),
                  _Side(
                    icon: Icons.meeting_room_outlined,
                    title: '${clash.b.periodName} · ${clash.b.classroomName}',
                    subtitle: '${clash.b.range} · ${clash.b.timetableName}'
                        '${clash.b.isCover ? ' · one-day cover' : ''}',
                  ),
                  if (!readOnly) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonal(
                        onPressed: () => onFix(clash),
                        child: const Text('Change this period'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Side({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.onSurfaceMuted(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted(context))),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClashNote extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ClashNote({required this.text, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, style: TextStyle(color: AppColors.onSurface(context), fontSize: 13, height: 1.4)),
              ),
            ],
          ),
          if (actionLabel != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(actionLabel!),
              ),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}
