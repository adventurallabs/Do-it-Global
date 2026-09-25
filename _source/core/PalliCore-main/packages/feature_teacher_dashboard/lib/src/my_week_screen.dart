import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

/// A teacher's own week across every class they teach — so "what do I have
/// tomorrow?" doesn't mean opening each class timetable one by one.
class MyWeekScreen extends StatefulWidget {
  final String teacherId;
  const MyWeekScreen({super.key, required this.teacherId});

  @override
  State<MyWeekScreen> createState() => _MyWeekScreenState();
}

class _MyWeekScreenState extends State<MyWeekScreen> {
  List<Timetable> _active = [];
  /// period id -> class name ("LKG - A"); period ids are unique per school.
  final Map<String, String> _classOf = {};
  bool _loading = true;
  bool _error = false;
  bool _gridView = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final results = await Future.wait<Object>([
        context.read<TimetableRepository>().getAll(),
        context.read<ClassroomRepository>().getAll(),
      ]);
      if (!mounted) return;
      final timetables = (results[0] as List<Timetable>).where((t) => t.isActive).toList();
      final classes = results[1] as List<Classroom>;
      final names = {for (final c in classes) c.id: c.name};
      setState(() {
        _active = timetables;
        _classOf
          ..clear()
          ..addAll({
            for (final t in timetables)
              for (final p in t.periods) p.id: names[t.classroomId] ?? '',
          });
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

  /// My regular periods, used to decide which days to offer.
  List<Period> get _mine => [
        for (final t in _active)
          for (final p in t.periods)
            if (!p.isTemporary && p.staffId == widget.teacherId) p,
      ];

  /// Resolve each class timetable on its own (covers only replace a slot in
  /// their own class), then keep what's mine — including covers I'm taking,
  /// and dropping my periods someone else is covering that day.
  List<Period> _resolve(String day, DateTime date) {
    final out = <Period>[];
    for (final t in _active) {
      for (final p in Schedule.periodsOn(t.periods, day, date: date)) {
        if (p.staffId == widget.teacherId) out.add(p);
      }
    }
    out.sort((a, b) => Schedule.minutesOf(a.startTime).compareTo(Schedule.minutesOf(b.startTime)));
    return out;
  }

  String _classFor(Period p) => _classOf[p.id] ?? '';

  /// The whole week at once: every period that is mine, across every class,
  /// laid out day by column. The day view answers "what's next"; this one
  /// answers "when am I free on Thursday".
  Widget _grid() {
    final mine = _mine;
    if (mine.isEmpty) {
      return const EmptyState(
        icon: Icons.grid_view_rounded,
        title: 'No periods assigned',
        subtitle: "You'll see your week once the admin puts you on a class timetable.",
      );
    }
    // The rows are whatever times this teacher actually teaches at — they
    // are rarely on one class's bell schedule, since the week is pulled from
    // every classroom they walk into.
    final starts = {for (final p in mine) Schedule.minutesOf(p.startTime)}.toList()..sort();
    final ends = [for (final p in mine) Schedule.endMinutes(p)];
    return SingleChildScrollView(
      child: TimetableGrid(
        periods: mine,
        readOnly: true,
        dayStartTime: Schedule.hhmm(starts.first),
        dayEndTime: Schedule.hhmm(ends.reduce((a, b) => a > b ? a : b)),
        subtitleOf: _classFor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My week'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Day'), icon: Icon(Icons.view_agenda_outlined)),
                ButtonSegment(value: true, label: Text('Grid'), icon: Icon(Icons.grid_view_rounded)),
              ],
              selected: {_gridView},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _gridView = s.first),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error
                ? EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load your timetable",
                    subtitle: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: _load,
                  )
                : _gridView
                    ? _grid()
                    : DayScheduleView(
                        periods: _mine,
                        resolver: _resolve,
                        subtitleOf: _classFor,
                        emptyTitle: 'No periods assigned',
                        emptySubtitle:
                            "You'll see your week once the admin puts you on a class timetable.",
                      ),
      ),
    );
  }
}
