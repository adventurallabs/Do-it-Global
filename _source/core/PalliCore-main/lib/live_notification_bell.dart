import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

/// [NotificationBell] wired to [NotificationRepository]; refreshes its count
/// when the route it navigates to is popped.
class LiveNotificationBell extends StatefulWidget {
  final NotificationRecipientRole role;
  final String recipientId;
  final String route;
  final Color? iconColor;

  const LiveNotificationBell({
    super.key,
    required this.role,
    required this.recipientId,
    required this.route,
    this.iconColor,
  });

  @override
  State<LiveNotificationBell> createState() => _LiveNotificationBellState();
}

class _LiveNotificationBellState extends State<LiveNotificationBell> {
  int _count = 0;
  StreamSubscription<dynamic>? _sub;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(LiveNotificationBell old) {
    super.didUpdateWidget(old);
    // A second sign-in on the same phone can reuse this State. Subscribing
    // only in initState left the bell counting the previous user's unread
    // notifications, under the new user's name.
    if (old.recipientId != widget.recipientId || old.role != widget.role) {
      _count = 0;
      _listen();
    }
  }

  void _listen() {
    _sub?.cancel();
    _sub = null;
    _refresh();
    if (widget.recipientId.isEmpty) return;
    _sub = context
        .read<NotificationRepository>()
        .watch(widget.role, widget.recipientId)
        .listen((items) {
      if (mounted) {
        setState(() => _count =
            items.where((n) => !n.isRead && n.kind != NotificationKind.message).length);
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (widget.recipientId.isEmpty) return;
    try {
      final count = await context
          .read<NotificationRepository>()
          .unreadCount(widget.role, widget.recipientId);
      if (mounted) setState(() => _count = count);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return NotificationBell(
      count: _count,
      iconColor: widget.iconColor,
      onTap: () async {
        await context.push(widget.route);
        _refresh();
      },
    );
  }
}
