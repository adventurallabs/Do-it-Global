import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/localization/l10n_ext.dart';
import '../models/app_notification.dart';

class NotificationItemCard extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;

  const NotificationItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (item.kind) {
      NotificationKind.homework => Icons.menu_book_outlined,
      NotificationKind.marks => Icons.insights_outlined,
      NotificationKind.attendance => Icons.event_available_outlined,
      NotificationKind.fees => Icons.account_balance_wallet_outlined,
      NotificationKind.announcement => Icons.campaign_outlined,
      NotificationKind.activity => Icons.emoji_events_outlined,
      NotificationKind.star => Icons.star_rounded,
      NotificationKind.growth => Icons.spa_outlined,
      NotificationKind.libraryBook => Icons.local_library_outlined,
      NotificationKind.school => Icons.school_outlined,
    };

    final color = switch (item.kind) {
      NotificationKind.star => AppColors.star,
      _ when item.important => AppColors.warning,
      _ => theme.colorScheme.primary,
    };

    return Semantics(
      label: item.read ? null : 'Unread',
      child: ListTile(
        onTap: onTap,
        tileColor: item.read ? null : theme.colorScheme.primary.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        subtitle: item.body.isEmpty
            ? null
            : Text(item.body, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat.jm(Localizations.localeOf(context).toString()).format(item.createdAt),
              style: theme.textTheme.labelSmall,
            ),
            if (!item.read) ...[
              const SizedBox(height: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String notificationSectionLabel(BuildContext context, DateTime date) {
  final l10n = context.l10n;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  if (d == today) return l10n.todayLabel;
  if (d == today.subtract(const Duration(days: 1))) return l10n.yesterday;
  return DateFormat.MMMd().format(date);
}
