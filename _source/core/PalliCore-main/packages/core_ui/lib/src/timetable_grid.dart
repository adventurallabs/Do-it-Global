import 'package:flutter/material.dart';
import 'package:core_models/core_models.dart';
import 'app_colors.dart';
import 'neo_widgets.dart';

class TimetableGrid extends StatelessWidget {
  final List<Period> periods;
  final String dayStartTime;
  final String dayEndTime;
  final int intervalCount;
  final Map<String, String> staffNames;
  /// The small line under a cell's subject. Defaults to the staff name; a
  /// teacher reading their *own* week wants the class there instead, since
  /// every period in it is theirs.
  final String Function(Period period)? subtitleOf;
  /// [slotMinutes] is how long the blank week says this row runs, so filling
  /// an empty cell starts from the right length instead of a fixed default.
  final void Function(String day, String startTime, Period? period, int slotMinutes)? onCellTap;
  final bool readOnly;
  /// Periods that overlap another one — drawn with a red outline.
  final Set<String> clashIds;
  /// Tapping a clashing cell calls this instead of [onCellTap], so the admin
  /// lands on a screen that explains the clash rather than a single period.
  final void Function(String day)? onClashTap;
  /// Periods whose teacher is standing in front of another class at that
  /// hour — the cell reads fine on its own, so it is called out in amber.
  final Set<String> staffClashIds;
  /// Room below the grid so a floating action button can't sit on the last
  /// row of cells.
  final double bottomPadding;

  const TimetableGrid({
    super.key,
    required this.periods,
    required this.dayStartTime,
    required this.dayEndTime,
    this.intervalCount = 8,
    this.staffNames = const {},
    this.subtitleOf,
    this.onCellTap,
    this.readOnly = false,
    this.clashIds = const {},
    this.onClashTap,
    this.staffClashIds = const {},
    this.bottomPadding = 0,
  });

  static const _allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  /// Mon–Sat always; Sunday only when something is scheduled on it.
  List<String> get _days => [
        ..._allDays.take(6),
        if (periods.any((p) => p.dayOfWeek == 'Sunday' && !p.isTemporary)) 'Sunday',
      ];

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    final days = _days;
    return SoftSurface(
      depth: SoftDepth.one,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      borderRadius: BorderRadius.circular(22),
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomPadding),
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(108),
              columnWidths: const {0: FixedColumnWidth(86)},
              children: [
                TableRow(
                  children: [
                    _header(context, 'Period'),
                    ...days.map((d) => _header(context, d.substring(0, 3))),
                  ],
                ),
                if (rows.isEmpty)
                  TableRow(
                    children: [
                      _dayCell(context, '—'),
                      ...List.generate(days.length, (_) => _emptyHint(context)),
                    ],
                  )
                else
                  ...rows.map((row) {
                    return TableRow(
                      children: [
                        _rowHeader(context, row),
                        ...days.map((day) {
                          final period = _periodAt(day, row.startTime);
                          final sameSlot = _regularAt(day, row.startTime);
                          return _cell(context, day, row.startTime, period,
                              extra: sameSlot.length - 1, slotMinutes: row.durationMinutes);
                        }),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_PeriodRow> _rows() {
    final byStart = <String, _PeriodRow>{};
    // The blank week first, straight from the timetable's own settings, so a
    // timetable with nothing on it opens as a full grid of cells to tap
    // rather than an empty page you have to insert rows into one at a time.
    // Read-only viewers (a teacher's week, a parent's timetable) get only
    // what is really scheduled — blank rows would be noise to them.
    if (!readOnly) {
      for (final slot in Schedule.slotPlan(
        dayStart: dayStartTime,
        dayEnd: dayEndTime,
        count: intervalCount,
      )) {
        byStart[slot.startTime] =
            _PeriodRow(startTime: slot.startTime, durationMinutes: slot.durationMinutes, label: '');
      }
    }
    for (final period in periods) {
      if (period.isTemporary) continue;
      // A real period always defines its own row; only the first one at a
      // given time does, so a double-booked slot keeps one row (the cell
      // marks the clash).
      final existing = byStart[period.startTime];
      if (existing != null && !existing.isSlot) continue;
      byStart[period.startTime] = _PeriodRow(
        startTime: period.startTime,
        durationMinutes: period.durationMinutes,
        label: period.name,
      );
    }
    final rows = byStart.values.toList()
      ..sort((a, b) => Schedule.minutesOf(a.startTime).compareTo(Schedule.minutesOf(b.startTime)));
    return rows;
  }

  Period? _periodAt(String day, String startTime) {
    Period? regular;
    Period? temporary;
    for (final period in periods) {
      if (period.dayOfWeek != day || period.startTime != startTime) continue;
      if (period.isTemporary && _isToday(period.date)) {
        temporary = period;
      } else if (!period.isTemporary) {
        regular = period;
      }
    }
    return temporary ?? regular;
  }

  /// Every regular period starting in this slot — more than one means the
  /// same slot was filled twice, which the single-cell view would hide.
  List<Period> _regularAt(String day, String startTime) => [
        for (final p in periods)
          if (!p.isTemporary && p.dayOfWeek == day && p.startTime == startTime) p,
      ];

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Widget _cell(BuildContext context, String day, String startTime, Period? period,
      {int extra = 0, int slotMinutes = 45}) {
    final clashing = period != null && (extra > 0 || clashIds.contains(period.id));
    final staffBusy = period != null && !clashing && staffClashIds.contains(period.id);
    final name = period?.name.toLowerCase() ?? '';
    final isBreak = name.contains('break');
    final isLunch = name.contains('lunch');
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = period == null
        ? (dark ? Colors.white.withValues(alpha: 0.05) : AppColors.surfaceLight)
        : isLunch
            ? AppColors.lunchCell.withValues(alpha: 0.12)
            : isBreak
                ? AppColors.breakCell.withValues(alpha: 0.12)
                : period.isTemporary
                    ? AppColors.temporaryPeriod.withValues(alpha: 0.12)
                    : AppColors.periodCell.withValues(alpha: 0.12);
    final textColor = period == null
        ? AppColors.onSurfaceHint(context)
        : isLunch
            ? AppColors.lunchCell
            : isBreak
                ? AppColors.breakCell
                : period.isTemporary
                    ? AppColors.temporaryPeriod
                    : AppColors.onSurface(context);
    final staff = period == null
        ? ''
        : subtitleOf?.call(period) ?? staffNames[period.staffId] ?? '';

    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: clashing
                ? const BorderSide(color: AppColors.error, width: 1.5)
                : staffBusy
                    ? const BorderSide(color: AppColors.warning, width: 1.5)
                    : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: readOnly
                ? null
                : clashing && onClashTap != null
                    ? () => onClashTap!(day)
                    : () => onCellTap?.call(day, startTime, period, slotMinutes),
            child: SizedBox(
              height: 78,
              child: Center(
                child: period == null
                    ? Icon(readOnly ? Icons.remove : Icons.add, color: AppColors.onSurfaceHint(context), size: 18)
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              period.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            if (staff.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(staff, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 10)),
                            ],
                            if (period.isTemporary)
                              Text('Today', style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.w700)),
                            if (clashing || staffBusy) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      size: 11, color: clashing ? AppColors.error : AppColors.warning),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      clashing ? (extra > 0 ? '+$extra more' : 'Clash') : 'Staff busy',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: clashing ? AppColors.error : AppColors.warning,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyHint(BuildContext context) => TableCell(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            height: 78,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );

  Widget _header(BuildContext context, String text) => TableCell(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.onSurfaceMuted(context), fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _rowHeader(BuildContext context, _PeriodRow row) => TableCell(
        child: SizedBox(
          height: 86,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_format12(row.startTime), style: TextStyle(color: AppColors.onSurface(context), fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 2),
                Text('${row.durationMinutes} min', style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 10)),
              ],
            ),
          ),
        ),
      );

  Widget _dayCell(BuildContext context, String text) => TableCell(
        child: SizedBox(
          height: 80,
          child: Center(child: Text(text, style: TextStyle(color: AppColors.onSurface(context), fontWeight: FontWeight.w700))),
        ),
      );

  String _format12(String value) {
    final parts = value.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $suffix';
  }
}

class _PeriodRow {
  final String startTime;
  final int durationMinutes;
  final String label;

  const _PeriodRow({required this.startTime, required this.durationMinutes, required this.label});

  /// An empty slot from the blank week — no period has claimed this time yet,
  /// so a real one may still take the row over.
  bool get isSlot => label.isEmpty;
}
