import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:core_models/core_models.dart';

import 'app_colors.dart';
import 'exam_widgets.dart' show fmtMark;

/// What was picked for one student.
class GradeChoice {
  final String? grade;
  final bool absent;

  const GradeChoice.grade(String this.grade) : absent = false;
  const GradeChoice.absent()
      : grade = null,
        absent = true;
  const GradeChoice.cleared()
      : grade = null,
        absent = false;

  bool get isCleared => grade == null && !absent;
}

/// Picks a grade from the exam's scale — the only way a grade gets entered,
/// so a teacher can never type one that isn't on the scale.
Future<GradeChoice?> showGradePicker(
  BuildContext context, {
  required List<GradeBand> bands,
  required String title,
  String? subtitle,
  String? current,
  bool currentAbsent = false,
  String? suggested,
  bool allowAbsent = true,
}) {
  return showModalBottomSheet<GradeChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      final mute = AppColors.onSurfaceMuted(sheet);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 13, color: mute)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final b in bands)
                    _GradeButton(
                      band: b,
                      selected: !currentAbsent && current == b.label,
                      suggested: suggested == b.label,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(sheet, GradeChoice.grade(b.label));
                      },
                    ),
                ],
              ),
              if (suggested != null) ...[
                const SizedBox(height: 10),
                Text('Suggested from the mark: $suggested', style: TextStyle(fontSize: 12, color: mute)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (allowAbsent)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(sheet, const GradeChoice.absent()),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          foregroundColor: AppColors.warning,
                          backgroundColor: currentAbsent ? AppColors.warning.withValues(alpha: 0.12) : null,
                        ),
                        icon: const Icon(Icons.event_busy_outlined, size: 18),
                        label: const Text('Absent (AB)'),
                      ),
                    ),
                  if (allowAbsent) const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      onPressed: current == null && !currentAbsent
                          ? null
                          : () => Navigator.pop(sheet, const GradeChoice.cleared()),
                      style: TextButton.styleFrom(minimumSize: const Size(0, 46)),
                      child: const Text('Clear'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _GradeButton extends StatelessWidget {
  final GradeBand band;
  final bool selected;
  final bool suggested;
  final VoidCallback onTap;

  const _GradeButton({required this.band, required this.selected, required this.suggested, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = band.pass ? AppColors.accent : AppColors.error;
    return Material(
      color: selected ? color : color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: suggested && !selected ? color : Colors.transparent, width: 1.6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                band.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.onSurface(context),
                ),
              ),
              if (band.min != null)
                Text(
                  '${fmtMark(band.min!)}%+',
                  style: TextStyle(fontSize: 10, color: selected ? Colors.white70 : AppColors.onSurfaceHint(context)),
                )
              else if (!band.pass)
                Text('fail', style: TextStyle(fontSize: 10, color: selected ? Colors.white70 : AppColors.error)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The grade in a row: tap to pick. Shows AB, a failing grade in red, or an
/// empty prompt.
class GradeCell extends StatelessWidget {
  final String? grade;
  final bool absent;
  final bool failing;
  final bool missing;
  final bool enabled;
  final VoidCallback? onTap;
  final double width;

  const GradeCell({
    super.key,
    required this.grade,
    this.absent = false,
    this.failing = false,
    this.missing = false,
    this.enabled = true,
    this.onTap,
    this.width = 76,
  });

  @override
  Widget build(BuildContext context) {
    final empty = grade == null && !absent;
    final color = absent
        ? AppColors.warning
        : failing
            ? AppColors.error
            : missing
                ? AppColors.error
                : AppColors.accent;
    return SizedBox(
      width: width,
      height: 44,
      child: Material(
        color: empty ? Theme.of(context).colorScheme.surface : color.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: empty ? (missing ? AppColors.error : AppColors.divider) : color.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Center(
            child: empty
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Grade',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.onSurfaceHint(context))),
                      Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.onSurfaceHint(context)),
                    ],
                  )
                : Text(
                    absent ? 'AB' : grade!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
                  ),
          ),
        ),
      ),
    );
  }
}
