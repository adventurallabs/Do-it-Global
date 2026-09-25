import 'package:flutter/material.dart';
import 'package:core_models/core_models.dart';

import 'app_colors.dart';
import 'admin_look.dart';

/// "14 of 30 submitted" with a bar — how far a set of mark sheets has got.
class SubmissionBar extends StatelessWidget {
  final int submitted;
  final int total;
  final String noun;

  const SubmissionBar({super.key, required this.submitted, required this.total, this.noun = 'subject sheets'});

  @override
  Widget build(BuildContext context) {
    final done = total > 0 && submitted >= total;
    final value = total == 0 ? 0.0 : (submitted / total).clamp(0.0, 1.0);
    final color = done ? AppColors.success : AppColors.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                total == 0 ? 'No $noun yet' : '$submitted of $total $noun submitted',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.onSurfaceMuted(context)),
              ),
            ),
            if (done) const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.14),
            ),
          ),
        ),
      ],
    );
  }
}

/// One standard's timetable state on an exam card.
class GradeStatusChip extends StatelessWidget {
  final ExamSchedule schedule;
  const GradeStatusChip({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (schedule) {
      ExamSchedule(isPublished: true, hasChanges: true) => ('Changes to share', AppColors.warning, Icons.sync_rounded),
      ExamSchedule(isPublished: true) => ('Published', AppColors.success, Icons.check_circle_rounded),
      ExamSchedule(paperCount: 0) => ('Not started', AppColors.onSurfaceHint(context), Icons.radio_button_unchecked_rounded),
      _ => ('Draft · ${schedule.paperCount}', AppColors.examCard, Icons.edit_note_rounded),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            GradeCatalog.label(schedule.gradeKey),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.onSurface(context)),
          ),
          Text(' · $label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// Where one section's marks for one subject stand.
enum SheetState { notStarted, draft, submitted }

SheetState sheetStateOf(ExamMarkSheet? sheet) {
  if (sheet == null) return SheetState.notStarted;
  if (sheet.isSubmitted) return SheetState.submitted;
  return sheet.enteredCount > 0 ? SheetState.draft : SheetState.notStarted;
}

class SheetStatusBadge extends StatelessWidget {
  final ExamMarkSheet? sheet;
  final int? rosterSize;
  const SheetStatusBadge({super.key, required this.sheet, this.rosterSize});

  @override
  Widget build(BuildContext context) {
    final state = sheetStateOf(sheet);
    final (label, color, icon) = switch (state) {
      SheetState.submitted => ('Submitted', AppColors.success, Icons.lock_rounded),
      SheetState.draft => (
          rosterSize == null ? 'Draft · ${sheet!.enteredCount}' : 'Draft · ${sheet!.enteredCount}/$rosterSize',
          AppColors.warning,
          Icons.edit_rounded,
        ),
      SheetState.notStarted => ('Not started', AppColors.onSurfaceHint(context), Icons.radio_button_unchecked_rounded),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// A short confirmation that floats over the screen and goes by itself —
/// "Marks saved" without a dialog to dismiss after every save.
Future<void> showSavedToast(BuildContext context, {required String title, String? subtitle}) async {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _SavedToast(title: title, subtitle: subtitle),
  );
  overlay.insert(entry);
  await Future<void>.delayed(const Duration(milliseconds: 1700));
  entry.remove();
}

class _SavedToast extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SavedToast({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Opacity(
            opacity: ((t - 0.85) / 0.15).clamp(0.0, 1.0),
            child: Transform.scale(scale: t, child: child),
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              decoration: BoxDecoration(
                color: const Color(0xF2303137),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF9BC59A), size: 38),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5, height: 1.35),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A yes/no with the consequence spelled out. Returns true on confirm.
Future<bool> confirmExamAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  IconData icon = Icons.help_outline_rounded,
  Color? color,
  List<String> bullets = const [],
}) async {
  final tint = color ?? AppColors.accent;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      icon: Icon(icon, color: tint, size: 32),
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(height: 1.4)),
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final b in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6, color: tint),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(b, style: const TextStyle(fontSize: 13.5, height: 1.35))),
                  ],
                ),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: tint),
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Reads what a teacher typed into a marks box: a number, "AB", or nothing.
class MarkEntry {
  final double? score;
  final bool absent;
  final String? error;

  const MarkEntry._({this.score, this.absent = false, this.error});

  static const empty = MarkEntry._();

  bool get isEmpty => score == null && !absent && error == null;
  bool get isValid => error == null && (score != null || absent);

  static MarkEntry parse(String raw, double max) {
    final text = raw.trim();
    if (text.isEmpty) return empty;
    final upper = text.toUpperCase();
    if (upper == 'AB' || upper == 'A') return const MarkEntry._(absent: true);
    final value = double.tryParse(text);
    if (value == null) return const MarkEntry._(error: 'Number or AB');
    if (value < 0) return const MarkEntry._(error: 'Below 0');
    if (value > max) return MarkEntry._(error: 'Max ${fmtMark(max)}');
    // Half marks are fine; anything finer is a typo.
    if ((value * 2) != (value * 2).roundToDouble()) return const MarkEntry._(error: 'Use .5 steps');
    return MarkEntry._(score: value);
  }

  static String textOf(Mark? mark) {
    if (mark == null) return '';
    if (mark.isAbsent) return 'AB';
    return fmtMark(mark.score);
  }
}

String fmtMark(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

Color outcomeColor(PaperOutcome outcome, BuildContext context) => switch (outcome) {
      PaperOutcome.pass => AppColors.success,
      PaperOutcome.fail => AppColors.error,
      PaperOutcome.absent => AppColors.warning,
      PaperOutcome.pending => AppColors.onSurfaceHint(context),
    };

/// One student's entry for one paper, read according to what the exam
/// records. The single place both the teacher's sheet and the admin's
/// correction screen decide "is this row complete, and what gets saved" —
/// the database re-checks the same rules.
class ResultInput {
  final double? score;
  final String? grade;
  final bool absent;
  final String? error;

  const ResultInput({this.score, this.grade, this.absent = false, this.error});

  static const empty = ResultInput();

  bool get isEmpty => score == null && grade == null && !absent && error == null;

  bool isComplete(ExamResultMode mode) =>
      error == null &&
      (absent || ((!mode.usesMarks || score != null) && (!mode.usesGrades || grade != null)));

  /// [markText] is ignored for a grades-only exam and [grade] for a
  /// marks-only one — a teacher can't slip the other kind in.
  static ResultInput read({
    required ExamResultMode mode,
    required String markText,
    required String? grade,
    required bool absentFlag,
    required double max,
    required List<GradeBand> scale,
  }) {
    final e = mode.usesMarks ? MarkEntry.parse(markText, max) : MarkEntry.empty;
    if (absentFlag || e.absent) return const ResultInput(absent: true);
    if (e.error != null) return ResultInput(error: e.error);
    final g = mode.usesGrades ? grade : null;
    if (g != null && GradeScale.band(scale, g) == null) {
      return const ResultInput(error: 'Not on the scale');
    }
    if (mode == ExamResultMode.marksAndGrades) {
      if (e.score == null && g == null) return empty;
      if (e.score == null) return ResultInput(grade: g, error: 'Enter the mark');
      if (g == null) return ResultInput(score: e.score, error: 'Pick a grade');
    }
    return ResultInput(score: e.score, grade: g);
  }

  /// Whether this entry is what [saved] already holds.
  bool matches(Mark? saved, ExamResultMode mode) {
    if (error != null) return false;
    if (isEmpty) return saved == null;
    if (saved == null) return false;
    if (absent) return saved.isAbsent;
    if (saved.isAbsent) return false;
    if (mode.usesMarks && saved.score != score) return false;
    if (mode.usesGrades && saved.grade != grade) return false;
    return true;
  }

  /// What goes in the marks box for a saved row.
  static String markTextOf(Mark? m, ExamResultMode mode) {
    if (m == null) return '';
    if (m.isAbsent) return mode.usesMarks ? 'AB' : '';
    return mode.usesMarks ? fmtMark(m.score) : '';
  }
}

/// "AB", "82", "B", "82 · B" — a saved row read back for display.
String resultText(Mark? m, ExamResultMode mode) {
  if (m == null) return '';
  if (m.isAbsent) return 'AB';
  return [
    if (mode.usesMarks) fmtMark(m.score),
    if (mode.usesGrades && m.grade != null) m.grade!,
  ].join(' · ');
}

/// A page's primary actions, pinned to the bottom. Goes in
/// `Scaffold.bottomNavigationBar` — not the body — so floating snackbars sit
/// above it instead of covering the buttons, and it rides up with the
/// keyboard so Save stays in reach while typing.
class StickyActionBar extends StatelessWidget {
  final Widget child;
  const StickyActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboard),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AdminLook.canvasOf(context),
          border: Border(top: BorderSide(color: AppColors.divider.withValues(alpha: 0.7))),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4))],
        ),
        child: SafeArea(top: false, child: child),
      ),
    );
  }
}
