import 'package:flutter/material.dart';
import 'package:core_models/core_models.dart';

import 'app_colors.dart';
import 'admin_look.dart';
import 'neo_widgets.dart';

/// One standard's exam timetable, read as a table: date, subject, time,
/// marks. Used by the admin while building it and by teachers reading it, so
/// both see the same layout.
class ExamTimetableTable extends StatelessWidget {
  final List<ExamPaper> papers;
  final ValueChanged<ExamPaper>? onTap;

  /// Subjects to flag (lower-cased) — a teacher's own papers.
  final Set<String> highlightSubjects;
  final String highlightLabel;

  /// Paper ids to animate in — the one the admin just added.
  final String? freshPaperId;

  /// A grades-only exam has no marks column worth showing.
  final ExamResultMode mode;

  const ExamTimetableTable({
    super.key,
    required this.papers,
    this.onTap,
    this.highlightSubjects = const {},
    this.highlightLabel = 'Yours',
    this.freshPaperId,
    this.mode = ExamResultMode.marks,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...papers]..sort(ExamPaper.compare);
    final muted = AppColors.onSurfaceHint(context);
    final header = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
      color: muted,
    );
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                SizedBox(width: _dateW, child: Text('DATE', style: header)),
                Expanded(child: Text('SUBJECT', style: header)),
                SizedBox(width: _timeW, child: Text('TIME', style: header)),
                SizedBox(
                  width: _marksW,
                  child: Text(mode.usesMarks ? 'MARKS' : 'RESULT', style: header, textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.divider.withValues(alpha: 0.6)),
            _Row(
              key: ValueKey(sorted[i].id),
              paper: sorted[i],
              onTap: onTap == null ? null : () => onTap!(sorted[i]),
              highlight: highlightSubjects.contains(sorted[i].subject.trim().toLowerCase()),
              highlightLabel: highlightLabel,
              mode: mode,
              fresh: sorted[i].id == freshPaperId,
              // Two papers the same day: show the date once.
              repeatDate: i > 0 && sorted[i - 1].isOn(sorted[i].examDate),
            ),
          ],
        ],
      ),
    );
  }

  static const double _dateW = 58;
  static const double _timeW = 84;
  static const double _marksW = 52;
}

class _Row extends StatelessWidget {
  final ExamPaper paper;
  final VoidCallback? onTap;
  final bool highlight;
  final String highlightLabel;
  final bool fresh;
  final bool repeatDate;
  final ExamResultMode mode;

  const _Row({
    super.key,
    required this.paper,
    this.onTap,
    required this.highlight,
    required this.highlightLabel,
    required this.fresh,
    required this.repeatDate,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final phase = paper.phase();
    final today = paper.isOn(DateTime.now());
    final done = phase == ExamPhase.past;
    final ink = AppColors.onSurface(context);
    final mute = AppColors.onSurfaceMuted(context);
    final hint = AppColors.onSurfaceHint(context);
    final tint = today ? AppColors.accent.withValues(alpha: 0.09) : Colors.transparent;

    Widget row = Container(
      color: tint,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ExamTimetableTable._dateW,
            child: repeatDate
                ? Text('same day', style: TextStyle(fontSize: 10.5, color: hint, fontStyle: FontStyle.italic))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${paper.examDate.day}',
                        style: TextStyle(
                          fontSize: 20,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: done ? hint : ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${ExamDates.month(paper.examDate)} · ${ExamDates.weekday(paper.examDate)}',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: mute),
                      ),
                    ],
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      paper.subject,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: done ? mute : ink,
                        decoration: done ? TextDecoration.none : null,
                      ),
                    ),
                    if (today) _Tag(label: 'TODAY', color: AppColors.accent),
                    if (highlight) _Tag(label: highlightLabel.toUpperCase(), color: AdminLook.gold),
                  ],
                ),
                if (paper.syllabus.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    paper.syllabus.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: hint, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: ExamTimetableTable._timeW,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                '${ExamDates.display(paper.startTime)}\n${ExamDates.display(paper.endTime)}',
                style: TextStyle(fontSize: 11.5, height: 1.45, fontWeight: FontWeight.w600, color: mute),
              ),
            ),
          ),
          SizedBox(
            width: ExamTimetableTable._marksW,
            child: mode.usesMarks
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _num(paper.maxMarks),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: done ? mute : ink),
                      ),
                      Text('pass ${_num(paper.passMarks)}', style: TextStyle(fontSize: 10.5, color: hint)),
                    ],
                  )
                : Align(
                    alignment: Alignment.topRight,
                    child: Text('Grade', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: mute)),
                  ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      row = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, child: row),
      );
    }
    if (fresh) {
      row = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: child),
        ),
        child: row,
      );
    }
    return row;
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: color),
      ),
    );
  }
}

/// Colour + label for a phase — the same pill on every exam list.
class ExamPhasePill extends StatelessWidget {
  final ExamPhase phase;
  const ExamPhasePill({super.key, required this.phase});

  static Color colorOf(ExamPhase phase) => switch (phase) {
        ExamPhase.upcoming => AppColors.examCard,
        ExamPhase.ongoing => AppColors.warning,
        ExamPhase.past => AppColors.success,
      };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(phase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            phase.label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// Full details of one paper — syllabus in full, which the table truncates.
Future<void> showExamPaperDetails(
  BuildContext context,
  ExamPaper paper, {
  String? heading,
  ExamResultMode mode = ExamResultMode.marks,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      final mute = AppColors.onSurfaceMuted(sheet);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (heading != null)
                Text(heading, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mute)),
              Text(paper.subject, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _detail(sheet, Icons.event_rounded, ExamDates.long(paper.examDate)),
              _detail(sheet, Icons.schedule_rounded, paper.timeLabel),
              _detail(
                sheet,
                Icons.grading_rounded,
                mode.usesMarks
                    ? 'Out of ${_Row._num(paper.maxMarks)} · pass mark ${_Row._num(paper.passMarks)}'
                    : 'Graded — no marks',
              ),
              const SizedBox(height: 12),
              Text('SYLLABUS',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: mute)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.4),
                child: SingleChildScrollView(
                  child: Text(
                    paper.syllabus.trim().isEmpty ? 'No syllabus added.' : paper.syllabus.trim(),
                    style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.onSurface(sheet)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _detail(BuildContext context, IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
      ],
    ),
  );
}
