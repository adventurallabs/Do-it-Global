import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

/// What the attendance-rate card on the home screen actually means.
///
/// The card can only ever be a number and a caveat. This is where the caveat
/// gets its detail: which classes have been called, which have not, and how
/// the last fortnight has gone.
class AttendanceInsightsScreen extends StatefulWidget {
  const AttendanceInsightsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AttendanceInsightsScreen()),
      );

  @override
  State<AttendanceInsightsScreen> createState() => _AttendanceInsightsScreenState();
}

class _AttendanceInsightsScreenState extends State<AttendanceInsightsScreen> {
  /// Roughly three school weeks — long enough to show a pattern, short enough
  /// that every bar still has room to be read.
  static const _trendDays = 21;

  DailyAttendance _today = const DailyAttendance();
  List<_ClassDay> _byClass = const [];
  List<AttendanceTrendPoint> _trend = const [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = false);
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: _trendDays - 1));
      final (students, classrooms, rows) = await (
        context.read<StudentRepository>().getAll(),
        context.read<ClassroomRepository>().getAll(),
        context.read<AttendanceRepository>().getHomeroomBetween(from, now),
      ).wait;
      if (!mounted) return;

      final todayRows = rows.where((r) => _sameDay(r.date, now)).toList();
      final today = DailyAttendance.forDay(
        students: students,
        classrooms: classrooms,
        rows: todayRows,
      );

      // Per class, today.
      final enrolled = students.where((s) =>
          s.isActive &&
          s.lifecycle == StudentLifecycle.enrolled &&
          s.classroomId.isNotEmpty);
      final byClassroom = <String, List<Student>>{};
      for (final s in enrolled) {
        byClassroom.putIfAbsent(s.classroomId, () => []).add(s);
      }
      final nameOf = {for (final c in classrooms) c.id: c.displayName};
      // One pass to bucket the rows, instead of re-reading the whole day's
      // attendance once per class.
      final rowsOfClass = <String, List<Attendance>>{};
      for (final r in todayRows) {
        rowsOfClass.putIfAbsent(r.classroomId, () => []).add(r);
      }
      final classDays = <_ClassDay>[];
      for (final entry in byClassroom.entries) {
        final day = DailyAttendance.forDay(
          students: entry.value,
          classrooms: classrooms,
          rows: rowsOfClass[entry.key] ?? const <Attendance>[],
        );
        classDays.add(_ClassDay(nameOf[entry.key] ?? entry.key, day));
      }
      // Uncalled classes first — they are the thing to act on.
      classDays.sort((a, b) {
        final byCalled = (a.day.notTakenYet ? 0 : 1).compareTo(b.day.notTakenYet ? 0 : 1);
        return byCalled != 0 ? byCalled : a.name.compareTo(b.name);
      });

      // The trend, one point per calendar day, weekends dropped when nothing
      // was recorded on them.
      // Bucketed by calendar day up front. Asking `where(sameDay)` inside the
      // loop meant walking the whole term's rows once per day on the chart.
      final rowsOfDay = <DateTime, List<Attendance>>{};
      for (final r in rows) {
        final key = DateTime(r.date.year, r.date.month, r.date.day);
        rowsOfDay.putIfAbsent(key, () => []).add(r);
      }
      final trend = <AttendanceTrendPoint>[];
      for (var i = 0; i < _trendDays; i++) {
        final date = from.add(Duration(days: i));
        final dayRows = rowsOfDay[DateTime(date.year, date.month, date.day)] ??
            const <Attendance>[];
        final isWeekend = date.weekday == DateTime.sunday;
        if (dayRows.isEmpty && isWeekend) continue;
        final day = DailyAttendance.forDay(
          students: students,
          classrooms: classrooms,
          rows: dayRows,
        );
        trend.add(AttendanceTrendPoint(
          date: date,
          ratePercent: day.ratePercent,
          fullyMarked: day.fullyMarked,
          marked: day.marked,
          expected: day.expected,
        ));
      }

      if (!mounted) return;
      setState(() {
        _today = today;
        _byClass = classDays;
        _trend = trend;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance today')),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load attendance",
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    final mute = AppColors.onSurfaceMuted(context);
    final pending = _today.classroomsPending;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // The headline, with the caveat attached rather than implied.
          SoftSurface(
            depth: SoftDepth.one,
            borderRadius: BorderRadius.circular(22),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_today.rateLabel,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.4,
                          color: AppColors.onSurface(context),
                        )),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Text(
                        _today.notTakenYet
                            ? 'no roll called yet'
                            : 'of ${_today.marked} marked',
                        style: TextStyle(fontSize: 13, color: mute),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_today.statusLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _today.fullyMarked ? AppColors.success : AppColors.warning,
                    )),
                const SizedBox(height: 18),
                AttendanceCompositionBar(
                  // Not "all enrolled" when some are in no class — the bar can
                  // only speak for the children a roll call could reach.
                  title: _today.unplaced == 0
                      ? 'ALL ${_today.expected} ENROLLED CHILDREN'
                      : 'THE ${_today.expected} CHILDREN IN A CLASS',
                  present: _today.present,
                  absent: _today.absent,
                  unmarked: _today.unmarked,
                ),
                if (_today.unplacedLabel case final label?) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.person_off_outlined,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$label, so no roll call can reach them.',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.32)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.pending_actions_outlined,
                      size: 19, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Still to call: ${pending.length} class${pending.length == 1 ? '' : 'es'}',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(pending.join(', '),
                            style: TextStyle(fontSize: 12.5, height: 1.35, color: mute)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          _SectionTitle('By class, today', trailing: '${_byClass.length}'),
          const SizedBox(height: 4),
          SoftSurface(
            depth: SoftDepth.one,
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              children: [
                for (var i = 0; i < _byClass.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
                  ClassAttendanceRow(
                    name: _byClass[i].name,
                    present: _byClass[i].day.present,
                    absent: _byClass[i].day.absent,
                    unmarked: _byClass[i].day.unmarked,
                  ),
                ],
                if (_byClass.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text('No class has a child enrolled yet.',
                        style: TextStyle(fontSize: 13, color: mute)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _SectionTitle('Last three weeks'),
          const SizedBox(height: 10),
          SoftSurface(
            depth: SoftDepth.one,
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: AttendanceTrendChart(points: _trend),
          ),
          const SizedBox(height: 10),
          Text(
            'A day is only comparable with another when both were fully marked. '
            'Hollow bars are days a class was missed; a gap is a day nobody '
            'called a roll.',
            style: TextStyle(fontSize: 12, height: 1.4, color: mute),
          ),
        ],
      ),
    );
  }
}

class _ClassDay {
  final String name;
  final DailyAttendance day;
  const _ClassDay(this.name, this.day);
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final String? trailing;
  const _SectionTitle(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: AppColors.onSurfaceMuted(context))),
        if (trailing != null)
          Text(trailing!,
              style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceHint(context))),
      ],
    );
  }
}
