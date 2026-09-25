import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/localization/l10n_ext.dart';
import '../../shared/models/bus_tracking.dart';
import '../../shared/widgets/premium_card.dart';
import 'bus_tracking_providers.dart';

/// A fix older than this means the bus isn't on a trip right now.
const _liveWindow = Duration(minutes: 15);

class BusTrackingScreen extends ConsumerWidget {
  const BusTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final assignmentAsync = ref.watch(studentBusAssignmentProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabBusTracking)),
      body: SafeArea(
        child: assignmentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Message(
            icon: Icons.wifi_off_rounded,
            title: "Couldn't load the bus details",
            body: 'Check your internet connection and try again.',
            action: FilledButton.icon(
              onPressed: () => ref.invalidate(studentBusAssignmentProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.tryAgain),
            ),
          ),
          data: (assignment) {
            if (assignment == null) {
              return const _Message(
                icon: Icons.directions_bus_outlined,
                title: 'No bus assigned yet',
                body: "The school hasn't added your child to a bus route. "
                    'If your child uses the school bus, please contact the school office.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(studentBusAssignmentProvider);
                await ref.read(studentBusAssignmentProvider.future).catchError((_) => null);
              },
              child: _BusRouteView(assignment: assignment),
            );
          },
        ),
      ),
    );
  }
}

/// Calm, centred message used for the empty and error states — never a
/// full-screen red error.
class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const _Message({required this.icon, required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _BusRouteView extends ConsumerWidget {
  final StudentBusAssignment assignment;
  const _BusRouteView({required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final location = ref.watch(busLocationProvider).valueOrNull;
    final stops = [...assignment.route.stops]..sort((a, b) => a.sequence.compareTo(b.sequence));
    final live = location != null && DateTime.now().difference(location.recordedAt) < _liveWindow;

    int? nearest;
    if (location != null && stops.isNotEmpty) {
      var best = double.infinity;
      for (var i = 0; i < stops.length; i++) {
        final d = stops[i].location.distanceTo(location.location);
        if (d < best) {
          best = d;
          nearest = i;
        }
      }
    }
    final childIndex = stops.indexWhere((s) => s.id == assignment.stopId);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
      children: [
        _StatusCard(
          location: location,
          live: live,
          nearStop: nearest == null ? null : stops[nearest].name,
          stopsAway: nearest == null || childIndex < 0 ? null : childIndex - nearest,
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Route', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(assignment.route.routeName, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              if (stops.isEmpty)
                Text(
                  'The school has not added the stops for this route yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              else
                for (var i = 0; i < stops.length; i++)
                  _StopRow(
                    stop: stops[i],
                    isFirst: i == 0,
                    isLast: i == stops.length - 1,
                    isChildStop: i == childIndex,
                    busHere: i == nearest,
                    live: live,
                    passed: live && nearest != null && i < nearest,
                  ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumCard(
          child: Column(
            children: [
              _DetailRow(icon: Icons.directions_bus_rounded, label: 'Vehicle', value: assignment.bus.busNumber),
              if (assignment.bus.driverName.isNotEmpty) ...[
                const Divider(height: AppSpacing.lg),
                _DetailRow(icon: Icons.person_outline_rounded, label: 'Driver', value: assignment.bus.driverName),
              ],
              if (assignment.bus.driverContact.isNotEmpty) ...[
                const Divider(height: AppSpacing.lg),
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Driver phone',
                  value: assignment.bus.driverContact,
                  selectable: true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final BusLocation? location;
  final bool live;
  final String? nearStop;
  final int? stopsAway;

  const _StatusCard({required this.location, required this.live, this.nearStop, this.stopsAway});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final color = live ? AppColors.success : muted;

    final String title;
    final String subtitle;
    if (location == null) {
      title = 'Waiting for the bus';
      subtitle = 'The live position will show here once the bus starts its trip.';
    } else if (live) {
      title = nearStop == null ? 'Bus is on the way' : 'Near $nearStop';
      subtitle = switch (stopsAway) {
        null => 'Updated ${_relativeTime(location!.recordedAt)}',
        0 => 'At or close to your stop · updated ${_relativeTime(location!.recordedAt)}',
        < 0 => 'Has passed your stop · updated ${_relativeTime(location!.recordedAt)}',
        1 => '1 stop before yours · updated ${_relativeTime(location!.recordedAt)}',
        _ => '$stopsAway stops before yours · updated ${_relativeTime(location!.recordedAt)}',
      };
    } else {
      title = 'Bus is not on a trip now';
      subtitle = 'Last seen ${nearStop == null ? '' : 'near $nearStop '}${_relativeTime(location!.recordedAt)}';
    }

    return PremiumCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(Icons.directions_bus_rounded, color: color, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (live) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text('LIVE',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: AppColors.success, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                      const SizedBox(width: 8),
                    ],
                    if (live && location?.speedKmph != null)
                      Text('${location!.speedKmph!.round()} km/h',
                          style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                  ],
                ),
                if (live) const SizedBox(height: 2),
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final BusStop stop;
  final bool isFirst;
  final bool isLast;
  final bool isChildStop;
  final bool busHere;
  final bool live;
  final bool passed;

  const _StopRow({
    required this.stop,
    required this.isFirst,
    required this.isLast,
    required this.isChildStop,
    required this.busHere,
    required this.live,
    required this.passed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final line = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35);
    final dotColor = isChildStop ? primary : (passed ? AppColors.success : line);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Expanded(child: Container(width: 2, color: isFirst ? Colors.transparent : line)),
                Container(
                  width: isChildStop ? 16 : 12,
                  height: isChildStop ? 16 : 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : line)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    stop.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isChildStop ? FontWeight.w700 : FontWeight.w500,
                      color: passed ? theme.colorScheme.onSurfaceVariant : null,
                    ),
                  ),
                  if (isChildStop) _Pill(label: 'Your stop', color: primary),
                  if (busHere)
                    _Pill(
                      label: live ? 'Bus is here' : 'Last seen here',
                      color: live ? AppColors.success : theme.colorScheme.onSurfaceVariant,
                      icon: Icons.directions_bus_rounded,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Pill({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool selectable;

  const _DetailRow({required this.icon, required this.label, required this.value, this.selectable = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: selectable
                ? SelectableText(value, style: valueStyle, textAlign: TextAlign.right)
                : Text(value, style: valueStyle, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays == 1) return 'yesterday';
  return '${diff.inDays} days ago';
}
