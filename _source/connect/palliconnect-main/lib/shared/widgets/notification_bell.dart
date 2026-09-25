import 'package:flutter/material.dart';
import '../../core/localization/l10n_ext.dart';
import '../../core/navigation/app_routes.dart';
import '../../features/notifications/notifications_screen.dart';

class NotificationBell extends StatelessWidget {
  final int count;

  const NotificationBell({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.notifications,
      onPressed: () => AppRoutes.push(context, const NotificationsScreen()),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}
