import 'dart:async';

import 'package:feature_library/feature_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';

class NotificationCenterScreen extends StatefulWidget {
  final NotificationRecipientRole role;
  final String recipientId;

  const NotificationCenterScreen({
    super.key,
    required this.role,
    required this.recipientId,
  });

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;
  StreamSubscription<dynamic>? _sub;

  NotificationRepository get _repo => context.read<NotificationRepository>();

  @override
  void initState() {
    super.initState();
    _load();
    _sub = _repo.watch(widget.role, widget.recipientId).listen((items) {
      if (mounted && items.isNotEmpty) setState(() => _items = items);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _repo.forRecipient(widget.role, widget.recipientId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.isRead && n.kind != NotificationKind.message).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                await _repo.markAllRead(widget.role, widget.recipientId);
                await _load();
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'All caught up',
                  subtitle: 'Leave requests, messages and alerts will appear here.',
                )
              : RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final n = _items[index];
                      return SoftSurface(
                        depth: SoftDepth.one,
                        borderRadius: BorderRadius.circular(16),
                        padding: const EdgeInsets.all(14),
                        onTap: () => _open(n),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(_icon(n.kind),
                                size: 20,
                                color: n.isImportant ? AppColors.error : AppColors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.title,
                                      style: TextStyle(
                                        fontWeight:
                                            n.isRead ? FontWeight.w500 : FontWeight.w700,
                                        fontSize: 14,
                                      )),
                                  if (n.body.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(n.body,
                                        style: TextStyle(
                                            color: AppColors.onSurfaceMuted(context),
                                            fontSize: 12)),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(_ago(n.createdAt),
                                      style: TextStyle(
                                          color: AppColors.onSurfaceHint(context),
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                            if (!n.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 4, left: 6),
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      await _repo.markRead(n.id);
      await _load();
    }
    if (!mounted) return;
    final link = n.deepLink;
    if (link.startsWith('library') && widget.role == NotificationRecipientRole.teacher) {
      await BorrowedBooksScreen.open(context, teacherId: widget.recipientId);
      return;
    }
    String? destination;
    if (link.startsWith('leave')) {
      destination = widget.role == NotificationRecipientRole.admin
          ? '/admin/student-leave'
          : '/teacher/student-leave';
    } else if (link.startsWith('thread') && widget.role != NotificationRecipientRole.admin) {
      destination = '/teacher/messages';
    } else if (link.startsWith('announcement')) {
      destination = widget.role == NotificationRecipientRole.admin
          ? '/admin/announcements'
          : '/teacher';
    } else if (link.startsWith('cover') && widget.role == NotificationRecipientRole.teacher) {
      destination = '/teacher/cover-requests';
    } else if (link.startsWith('exam:')) {
      destination = widget.role == NotificationRecipientRole.admin ? '/admin/exams' : '/teacher/exams';
    } else if (link.startsWith('result:')) {
      destination = widget.role == NotificationRecipientRole.admin ? '/admin/results' : '/teacher/results';
    }
    if (destination == null) return;
    // This screen was reached via context.push from the bell, which awaits
    // a pop to know to refresh its count — context.go() alone would replace
    // the location without ever resolving that future, so pop first.
    if (context.canPop()) context.pop();
    context.go(destination);
  }

  IconData _icon(NotificationKind kind) => switch (kind) {
        NotificationKind.homework => Icons.assignment_outlined,
        NotificationKind.marks => Icons.grading_outlined,
        NotificationKind.attendance => Icons.fact_check_outlined,
        NotificationKind.fees => Icons.payments_outlined,
        NotificationKind.announcement => Icons.campaign_outlined,
        NotificationKind.message => Icons.chat_bubble_outline_rounded,
        NotificationKind.leave => Icons.event_busy_outlined,
        NotificationKind.activity => Icons.emoji_events_outlined,
        NotificationKind.event => Icons.event_available_outlined,
        NotificationKind.diary => Icons.menu_book_outlined,
        NotificationKind.coverRequest => Icons.swap_horiz_rounded,
        NotificationKind.exam => Icons.event_note_outlined,
        NotificationKind.libraryLoan => Icons.local_library_outlined,
        NotificationKind.school => Icons.school_outlined,
      };

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
