import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

/// Whose attendance is being read.
enum AttendanceSubject { student, staff }

/// One person's year, month by month.
///
/// The same screen for a child and for a teacher: the question is identical,
/// only the table the rows come from differs. Keeping it one screen keeps the
/// two from drifting into saying the same thing two ways.
class AttendanceHistoryScreen extends StatefulWidget {
  final String personId;
  final String personName;
  final AttendanceSubject subject;

  const AttendanceHistoryScreen({
    super.key,
    required this.personId,
    required this.personName,
    required this.subject,
  });

  static Future<void> open(
    BuildContext context, {
    required String personId,
    required String personName,
    required AttendanceSubject subject,
  }) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AttendanceHistoryScreen(
            personId: personId,
            personName: personName,
            subject: subject,
          ),
        ),
      );

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  AttendanceHistory? _history;
  String _periodLabel = '';
  int _threshold = 85;
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
      final year = await context.read<AcademicYearRepository>().getCurrent();
      if (!mounted) return;
      // The academic year is the window the school thinks in. Without one on
      // record, fall back to the last twelve months rather than showing
      // nothing.
      final now = DateTime.now();
      final from = year?.startDate ?? DateTime(now.year - 1, now.month, now.day);
      final to = year != null && year.endDate.isBefore(now) ? year.endDate : now;
      final label = year?.name ?? 'Last 12 months';

      AttendanceHistory history;
      if (widget.subject == AttendanceSubject.student) {
        final rows = await context
            .read<AttendanceRepository>()
            .getForStudentBetween(widget.personId, from, to);
        history = AttendanceHistory.fromRows(rows: rows, from: from, to: to);
      } else {
        final rows = await context
            .read<StaffAttendanceRepository>()
            .getBetween(from, to, staffId: widget.personId);
        history = AttendanceHistory.fromStaffRows(
          rows: [for (final r in rows) (date: r.date, status: r.status)],
          from: from,
          to: to,
        );
      }

      if (!mounted) return;
      // Read the repository before the next await, not after — the widget can
      // be gone by then and `context` would be dead.
      final settings = context.read<SchoolSettingsRepository>();
      var threshold = 85;
      try {
        threshold = (await settings.get()).attendanceWarningThreshold;
      } catch (_) {
        // The school's own mark is a nicety; the history is the point.
      }

      if (!mounted) return;
      setState(() {
        _history = history;
        _periodLabel = label;
        _threshold = threshold;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.personName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text('Attendance · $_periodLabel',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceMuted(context))),
          ],
        ),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final history = _history;
    if (_error || history == null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load attendance",
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (history.recorded == 0) {
      return EmptyState(
        icon: Icons.event_note_outlined,
        title: 'Nothing recorded yet',
        subtitle: 'Attendance for ${widget.personName} will appear here once a '
            'roll has been called in $_periodLabel.',
      );
    }

    final months = history.months.reversed.toList();
    final mute = AppColors.onSurfaceMuted(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          AttendanceSummaryCard(
            history: history,
            periodLabel: _periodLabel,
            warningThreshold: _threshold,
          ),
          const SizedBox(height: 18),
          const AbsenceCalendarLegend(),
          const SizedBox(height: 16),
          for (final month in months) ...[
            SoftSurface(
              depth: SoftDepth.one,
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              margin: const EdgeInsets.only(bottom: 12),
              child: AbsenceCalendarMonth(
                month: month,
                onDayTap: (date) => _showDay(date, month),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Days with no square are days the school recorded nothing — a '
            'holiday, or a roll nobody called. They are not counted as '
            'absences.',
            style: TextStyle(fontSize: 12, height: 1.4, color: mute),
          ),
        ],
      ),
    );
  }

  void _showDay(DateTime date, AttendanceMonth month) {
    final day = month.days.where((d) =>
        d.date.year == date.year && d.date.month == date.month && d.date.day == date.day);
    if (day.isEmpty) return;
    final record = day.first;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${record.date.day} ${month.label}',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    record.inSchool ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 20,
                    color: record.inSchool ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Text(record.statusLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: record.inSchool ? AppColors.success : AppColors.error,
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
