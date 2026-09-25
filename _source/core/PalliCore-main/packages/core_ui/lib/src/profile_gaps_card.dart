import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'neo_widgets.dart';

/// What is still missing from a person's file, and who can answer it.
///
/// The same card on the admin's profile screen and — with different wording —
/// in the parent app, because both read the one list in
/// [StudentProfileGaps]. Two lists would have disagreed within a month.
class ProfileGapsCard extends StatelessWidget {
  final List<ProfileGap> gaps;

  /// "Still needed" reads right to the office; a parent should be asked, not
  /// audited.
  final bool addressedToFamily;

  /// Shown when the file is complete. Null hides the card entirely.
  final String? completeMessage;

  final VoidCallback? onAction;
  final String actionLabel;

  const ProfileGapsCard({
    super.key,
    required this.gaps,
    this.addressedToFamily = false,
    this.completeMessage,
    this.onAction,
    this.actionLabel = 'Fill these in',
  });

  @override
  Widget build(BuildContext context) {
    final mute = AppColors.onSurfaceMuted(context);

    if (gaps.isEmpty) {
      if (completeMessage == null) return const SizedBox.shrink();
      return SoftSurface(
        depth: SoftDepth.one,
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, size: 18, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(completeMessage!,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.success)),
            ),
          ],
        ),
      );
    }

    final critical = gaps.where((g) => g.isCritical).toList();
    final rest = gaps.where((g) => !g.isCritical).toList();
    final tint = critical.isEmpty ? AppColors.warning : AppColors.error;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                critical.isEmpty
                    ? Icons.pending_actions_outlined
                    : Icons.error_outline_rounded,
                size: 19,
                color: tint,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  addressedToFamily
                      ? 'The school still needs ${gaps.length} detail${gaps.length == 1 ? '' : 's'}'
                      : 'Incomplete file · ${gaps.length} detail${gaps.length == 1 ? '' : 's'} missing',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Critical first — a blood group missing is not the same size of
          // problem as a missing photo, and the list should not pretend it is.
          for (final gap in [...critical, ...rest])
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      gap.isCritical
                          ? Icons.priority_high_rounded
                          : Icons.circle_outlined,
                      size: gap.isCritical ? 15 : 9,
                      color: gap.isCritical ? AppColors.error : mute,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gap.label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: gap.isCritical
                                ? AppColors.error
                                : AppColors.onSurface(context),
                          ),
                        ),
                        if (addressedToFamily) ...[
                          const SizedBox(height: 1),
                          Text(gap.ask,
                              style: TextStyle(fontSize: 11.5, height: 1.3, color: mute)),
                        ] else if (gap.owner == GapOwner.office) ...[
                          const SizedBox(height: 1),
                          Text('The office has to fill this in.',
                              style: TextStyle(fontSize: 11, color: mute)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (onAction != null) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.edit_note_rounded, size: 19),
                label: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small "n missing" chip for a directory row, so an incomplete file is
/// visible before anyone opens it.
class ProfileGapsBadge extends StatelessWidget {
  final int count;
  final int criticalCount;

  const ProfileGapsBadge({super.key, required this.count, this.criticalCount = 0});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final tint = criticalCount > 0 ? AppColors.error : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            criticalCount > 0 ? Icons.priority_high_rounded : Icons.pending_outlined,
            size: 12,
            color: tint,
          ),
          const SizedBox(width: 4),
          Text('$count missing',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: tint)),
        ],
      ),
    );
  }
}
