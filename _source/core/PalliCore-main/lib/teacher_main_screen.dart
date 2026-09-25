import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_announcements/feature_announcements.dart';
import 'package:feature_teacher_dashboard/feature_teacher_dashboard.dart';
import 'package:feature_teacher_tools/feature_teacher_tools.dart';
import 'live_notification_bell.dart';

class TeacherMainScreen extends StatefulWidget {
  const TeacherMainScreen({super.key});

  @override
  State<TeacherMainScreen> createState() => _TeacherMainScreenState();
}

class _TeacherMainScreenState extends State<TeacherMainScreen> {
  int _selectedIndex = 0;
  int _unreadMessages = 0;
  StreamSubscription<dynamic>? _messagesSub;
  String? _subscribedTeacherId;

  void _subscribeMessages(String teacherId) {
    if (teacherId.isEmpty || _subscribedTeacherId == teacherId) return;
    _subscribedTeacherId = teacherId;
    _messagesSub?.cancel();
    _messagesSub = context.read<MessageRepository>().watchThreads(teacherId).listen((threads) {
      if (!mounted) return;
      setState(() => _unreadMessages = threads.fold(0, (sum, t) => sum + t.teacherUnread));
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginState = authStateNotifier.value;
    final teacherId = loginState is LoginSuccess ? loginState.user.id : '';
    _subscribeMessages(teacherId);
    var teacherName = 'Teacher';
    if (loginState is LoginSuccess) {
      final name = loginState.user.name?.trim();
      if (name != null && name.isNotEmpty) teacherName = name;
    }
    final pages = [
      TeacherDashboardScreen(
        teacherId: teacherId,
        teacherName: teacherName,
        headerActions: [
          SoftIconButton(
            icon: Icons.event_busy_outlined,
            tooltip: 'Student leave requests',
            elevated: false,
            onTap: () => context.push('/teacher/student-leave'),
          ),
          LiveNotificationBell(
            role: NotificationRecipientRole.teacher,
            recipientId: teacherId,
            route: '/teacher/notifications',
          ),
        ],
      ),
      TeacherToolsScreen(teacherId: teacherId),
      TeacherMessagesScreen(teacherId: teacherId),
      AnnouncementScreen(isAdmin: false, teacherId: teacherId),
    ];

    return Scaffold(
      body: FadeTabStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NeoBottomNav(
        index: _selectedIndex,
        onChanged: (i) => setState(() {
          _selectedIndex = i;
        }),
        items: [
          const NeoNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Home',
          ),
          const NeoNavItem(
            icon: Icons.class_outlined,
            selectedIcon: Icons.class_rounded,
            label: 'Classes',
          ),
          NeoNavItem(
            icon: Icons.forum_outlined,
            selectedIcon: Icons.forum_rounded,
            label: 'Messages',
            badgeCount: _unreadMessages,
          ),
          const NeoNavItem(
            icon: Icons.campaign_outlined,
            selectedIcon: Icons.campaign_rounded,
            label: 'Announcements',
          ),
        ],
      ),
    );
  }
}
