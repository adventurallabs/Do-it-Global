import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/features/feature_registry.dart';
import '../../../core/localization/l10n_ext.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../shared/widgets/premium_card.dart';
import '../../bus_tracking/bus_tracking_screen.dart';
import '../../school_life/events_screen.dart';
import '../../school_life/school_life_providers.dart';
import '../../school_life/timetable_screen.dart';

/// Day-to-day school logistics a parent reaches for from Today:
/// timetable, events and the school bus. Each is feature-gated.
class SchoolLifeShortcuts extends ConsumerWidget {
  const SchoolLifeShortcuts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final registry = ref.watch(featureRegistryProvider);
    final unseenEvents = ref.watch(unseenEventCountProvider);

    final items = <Widget>[
      if (registry.isEnabled('timetable'))
        _Shortcut(
          icon: Icons.calendar_view_week_rounded,
          label: l10n.timetable,
          color: AppColors.primaryBlue,
          onTap: () => AppRoutes.push(context, const TimetableScreen()),
        ),
      if (registry.isEnabled('events'))
        _Shortcut(
          icon: Icons.celebration_rounded,
          label: l10n.events,
          color: AppColors.heart,
          badge: unseenEvents,
          onTap: () => AppRoutes.push(context, const EventsScreen()),
        ),
      if (registry.isEnabled('bus_tracking'))
        _Shortcut(
          icon: Icons.directions_bus_rounded,
          label: l10n.schoolBus,
          color: AppColors.leafGreen,
          onTap: () => AppRoutes.push(context, const BusTrackingScreen()),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(child: items[i]),
        ],
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badge;

  const _Shortcut({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: badge > 0 ? '$label, ${context.l10n.newCount(badge)}' : label,
      child: PremiumCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (badge > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}
