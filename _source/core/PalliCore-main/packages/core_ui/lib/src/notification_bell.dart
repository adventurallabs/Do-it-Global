import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Bell icon with an unread count badge. Wire [onTap] to the notification centre.
class NotificationBell extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  final Color? iconColor;

  const NotificationBell({
    super.key,
    required this.count,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          icon: Icon(
            count > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
            color: iconColor ?? AppColors.onSurface(context),
          ),
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.background, width: 1.5),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
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
    );
  }
}
