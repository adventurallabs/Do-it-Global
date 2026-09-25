import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'neo_widgets.dart';

/// A month of one person's attendance, as a calendar.
///
/// Same rule as the other attendance charts: colour is never the only channel.
/// The app's success green and error red are ΔE 4.6 apart under protanopia, so
/// an absent day also carries a ring and a dot, a present day is a plain tint,
/// and a day with no record at all is left blank rather than being coloured as
/// anything. A reader who cannot see the difference in hue can still see which
/// squares are marked.
class AbsenceCalendarMonth extends StatelessWidget {
  final AttendanceMonth month;

  /// Called with the tapped day, when the caller wants a detail sheet.
  final void Function(DateTime date)? onDayTap;

  const AbsenceCalendarMonth({super.key, required this.month, this.onDayTap});

  static const _weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first, which is how a school week reads.
    final leadingBlanks = first.weekday - 1;
    final absent = month.absentDayNumbers;
    final present = month.presentDayNumbers;
    final mute = AppColors.onSurfaceMuted(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(month.label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
            if (month.absent > 0)
              Text('${month.absent} absent',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error))
            else if (month.recorded > 0)
              const Text('Full attendance',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success))
            else
              Text('Nothing recorded', style: TextStyle(fontSize: 12, color: mute)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final initial in _weekdayInitials)
              Expanded(
                child: Center(
                  child: Text(initial,
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: mute)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = index - leadingBlanks + 1;
            final isAbsent = absent.contains(day);
            final isPresent = present.contains(day);
            return _DayCell(
              day: day,
              absent: isAbsent,
              present: isPresent,
              onTap: onDayTap == null || (!isAbsent && !isPresent)
                  ? null
                  : () => onDayTap!(DateTime(month.year, month.month, day)),
            );
          },
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool absent;
  final bool present;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.absent,
    required this.present,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final recorded = absent || present;
    final fill = absent
        ? AppColors.error.withValues(alpha: 0.16)
        : present
            ? AppColors.success.withValues(alpha: 0.14)
            : Colors.transparent;
    final ink = absent
        ? AppColors.error
        : present
            ? AppColors.onSurface(context)
            : AppColors.onSurfaceHint(context);

    return Semantics(
      label: '$day ${absent ? 'absent' : present ? 'present' : 'no record'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8),
            // The second channel: absent days are ringed, so they stand out
            // without relying on red being distinguishable from green.
            border: absent
                ? Border.all(color: AppColors.error, width: 1.4)
                : recorded
                    ? Border.all(color: AppColors.success.withValues(alpha: 0.35), width: 1)
                    : Border.all(color: AppColors.divider.withValues(alpha: 0.5), width: 1),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: absent ? FontWeight.w800 : FontWeight.w500,
                    color: ink,
                  )),
              if (absent)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                      color: AppColors.error, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The key that makes the calendar readable without colour vision.
class AbsenceCalendarLegend extends StatelessWidget {
  const AbsenceCalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    Widget item(Widget swatch, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch,
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11.5, color: mute)),
          ],
        );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item(
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.16),
              border: Border.all(color: AppColors.error, width: 1.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          'Absent',
        ),
        item(
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.14),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          'Present',
        ),
        item(
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          'No record — holiday, or no roll called',
        ),
      ],
    );
  }
}

/// The compact summary that sits on a profile: the rate, the caveat, and the
/// things a single percentage cannot say.
class AttendanceSummaryCard extends StatelessWidget {
  final AttendanceHistory history;
  final int warningThreshold;
  final String periodLabel;
  final VoidCallback? onOpen;

  const AttendanceSummaryCard({
    super.key,
    required this.history,
    required this.periodLabel,
    this.warningThreshold = 85,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);
    final low = history.isBelow(warningThreshold);
    final ongoing = history.currentAbsenceRun;
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ATTENDANCE',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: mute)),
              const Spacer(),
              Text(periodLabel, style: TextStyle(fontSize: 11, color: mute)),
              if (onOpen != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 18, color: mute),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(history.rateLabel,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: low ? AppColors.error : AppColors.onSurface(context),
                  )),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  history.recorded == 0
                      ? 'nothing recorded yet'
                      : 'of ${history.recorded} recorded day${history.recorded == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: mute),
                ),
              ),
            ],
          ),
          if (history.recorded > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                _Stat(label: 'Absent', value: '${history.absent}'),
                if (history.longestAbsenceRun > 1)
                  _Stat(
                      label: 'Longest run',
                      value: '${history.longestAbsenceRun} days'),
                if (ongoing > 0)
                  _Stat(
                    label: 'Away now',
                    value: '$ongoing day${ongoing == 1 ? '' : 's'}',
                    tint: AppColors.error,
                  ),
              ],
            ),
          ],
          if (low) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Below the school\'s $warningThreshold% mark.',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? tint;
  const _Stat({required this.label, required this.value, this.tint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: tint ?? AppColors.onSurface(context))),
        Text(label,
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted(context))),
      ],
    );
  }
}
