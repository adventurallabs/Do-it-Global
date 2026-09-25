import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

import 'attendance_history_screen.dart';

/// The attendance a profile shows at a glance: the year's rate, the months
/// they were away, and the way through to the full history.
///
/// It loads its own data rather than being handed it, so dropping it onto a
/// profile screen costs one line and no plumbing through the bloc.
class AttendanceProfileSection extends StatefulWidget {
  final String personId;
  final String personName;
  final AttendanceSubject subject;

  const AttendanceProfileSection({
    super.key,
    required this.personId,
    required this.personName,
    required this.subject,
  });

  @override
  State<AttendanceProfileSection> createState() => _AttendanceProfileSectionState();
}

class _AttendanceProfileSectionState extends State<AttendanceProfileSection> {
  AttendanceHistory? _history;
  String _periodLabel = '';
  int _threshold = 85;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AttendanceProfileSection old) {
    super.didUpdateWidget(old);
    if (old.personId != widget.personId) _load();
  }

  Future<void> _load() async {
    try {
      final year = await context.read<AcademicYearRepository>().getCurrent();
      if (!mounted) return;
      final now = DateTime.now();
      final from = year?.startDate ?? DateTime(now.year - 1, now.month, now.day);
      final to = year != null && year.endDate.isBefore(now) ? year.endDate : now;

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
        _periodLabel = year?.name ?? 'Last 12 months';
        _threshold = threshold;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open() => AttendanceHistoryScreen.open(
        context,
        personId: widget.personId,
        personName: widget.personName,
        subject: widget.subject,
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final history = _history;
    if (history == null) return const SizedBox.shrink();

    // The last three months with anything in them — a year of calendars on a
    // profile is a wall, and the full history is one tap away.
    final months = history.months.reversed.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AttendanceSummaryCard(
          history: history,
          periodLabel: _periodLabel,
          warningThreshold: _threshold,
          onOpen: _open,
        ),
        if (months.isNotEmpty) ...[
          const SizedBox(height: 12),
          const AbsenceCalendarLegend(),
          const SizedBox(height: 12),
          for (final month in months)
            SoftSurface(
              depth: SoftDepth.one,
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              margin: const EdgeInsets.only(bottom: 10),
              child: AbsenceCalendarMonth(month: month),
            ),
          if (history.months.length > months.length)
            Center(
              child: TextButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text('See all of $_periodLabel'),
              ),
            ),
        ],
      ],
    );
  }
}
