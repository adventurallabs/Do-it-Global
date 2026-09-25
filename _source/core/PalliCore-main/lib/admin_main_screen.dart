import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_admin_ops/feature_admin_ops.dart';
import 'live_notification_bell.dart';
import 'school_identity_card.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(LoadDashboard());
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async => context.read<DashboardBloc>().add(LoadDashboard()),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SoftPageHeader(
                  title: "Today's school",
                  actions: [
                    LiveNotificationBell(
                      role: NotificationRecipientRole.admin,
                      recipientId: _adminId(),
                      route: '/admin/notifications',
                    ),
                    SoftIconButton(
                      icon: Icons.logout_rounded,
                      tooltip: 'Sign out',
                      elevated: false,
                      onTap: () async {
                        final bloc = context.read<LoginBloc>();
                        if (await confirmSignOut(context)) bloc.add(LogoutRequested());
                      },
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: NeoClockCard(
                  subtitle: '$greeting, Admin',
                  title: 'Stay on top of campus',
                ),
              ),
              ContainedSliver(
                child: BlocBuilder<DashboardBloc, DashboardState>(
                  builder: (context, state) {
                    if (state is DashboardLoaded) return FadeIn(child: _live(state.snapshot));
                    if (state is DashboardError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(state.message, style: const TextStyle(color: AppColors.error)),
                      );
                    }
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Text(
                    'Management',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _management[index];
                      // Cards settle in a beat apart, row by row.
                      return AnimatedListItem(
                        index: index,
                        staggerLimit: _management.length,
                        delay: const Duration(milliseconds: 30),
                        child: PremiumCard(
                          title: item.title,
                          subtitle: item.subtitle,
                          icon: item.icon,
                          iconColor: item.color,
                          onTap: () => context.go(item.route),
                        ),
                      );
                    },
                    childCount: _management.length,
                    addAutomaticKeepAlives: false,
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 148,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _adminId() {
    final s = authStateNotifier.value;
    return s is LoginSuccess ? s.user.id : '';
  }

  Widget _live(DashboardSnapshot snap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _kpi('Students', '${snap.studentCount}', Icons.school_outlined)),
              const SizedBox(width: 12),
              Expanded(
                child: _kpi(
                  snap.staffAttendance.statusLabel,
                  snap.staffAttendance.label,
                  Icons.badge_outlined,
                  onTap: () => context.go('/admin/attendance'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _kpi(
                  snap.attendance.statusLabel,
                  snap.attendance.rateLabel,
                  snap.attendance.notTakenYet
                      ? Icons.pending_actions_outlined
                      : Icons.verified_outlined,
                  // A rate with half the school missing from it is the thing
                  // that confused people; the breakdown is one tap away.
                  onTap: () => AttendanceInsightsScreen.open(context),
                  tint: snap.attendance.fullyMarked ? null : AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _kpi('Pending fees', _fees(snap.pendingFees), Icons.payments_outlined)),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Your school',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
          ),
          const SizedBox(height: 10),
          const SchoolIdentityCard(),
          const SizedBox(height: 20),
          const Text(
            'Needs attention',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
          ),
          const SizedBox(height: 10),
          if (snap.attention.isEmpty)
            Text('Nothing urgent right now.', style: TextStyle(color: AppColors.onSurfaceHint(context), fontSize: 14))
          else
            SoftSurface(
              depth: SoftDepth.one,
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < snap.attention.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      dense: true,
                      onTap: () => context.go(snap.attention[i].route),
                      leading: const Icon(Icons.circle, size: 8, color: AppColors.warning),
                      title: Text(snap.attention[i].label, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      trailing: Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceHint(context), size: 20),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Quick actions',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Attendance', '/admin/attendance'),
              _chip('Announcement', '/admin/announcements'),
              _chip('Add student', '/admin/directory?tab=students'),
              _chip('Record fee', '/admin/fees'),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, IconData icon, {VoidCallback? onTap, Color? tint}) {
    return SoftSurface(
      depth: SoftDepth.one,
      borderRadius: BorderRadius.circular(30),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AdminIconWell(icon: icon, color: tint ?? AdminLook.gold, size: 40),
              const Spacer(),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: 18, color: AdminLook.muteOf(context)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AdminLook.inkOf(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tint ?? AdminLook.muteOf(context),
              fontSize: 12,
              height: 1.25,
              fontWeight: tint == null ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String route) {
    return SoftSurface(
      depth: SoftDepth.two,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.go(route),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.onSurface(context))),
    );
  }

  String _fees(double value) {
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    return '₹${value.toStringAsFixed(0)}';
  }
}

class ContainedSliver extends StatelessWidget {
  final Widget child;
  const ContainedSliver({super.key, required this.child});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(child: child);
}

class _ManagementItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const _ManagementItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}

const _management = [
  _ManagementItem(title: 'Classrooms', subtitle: 'LKG to 12th · sections', icon: Icons.school_outlined, color: AppColors.classroomCard, route: '/admin/classrooms'),
  _ManagementItem(title: 'Staff', subtitle: 'Teaching & office', icon: Icons.badge_outlined, color: AppColors.teacherCard, route: '/admin/directory?tab=teachers'),
  _ManagementItem(title: 'Students', subtitle: 'Records & placement', icon: Icons.groups_outlined, color: AppColors.studentCard, route: '/admin/directory?tab=students'),
  _ManagementItem(title: 'Attendance', subtitle: 'Today & absences', icon: Icons.fact_check_outlined, color: AppColors.attendanceCard, route: '/admin/attendance'),
  _ManagementItem(title: 'Leave & cover', subtitle: 'Approve & substitute', icon: Icons.event_busy_outlined, color: AppColors.leaveCard, route: '/admin/leave'),
  _ManagementItem(title: 'Student leave', subtitle: 'Parent requests', icon: Icons.badge_outlined, color: AppColors.leaveCard, route: '/admin/student-leave'),
  _ManagementItem(title: 'Academic year', subtitle: 'Promote · retain', icon: Icons.timeline_outlined, color: AppColors.academicsCard, route: '/admin/academics'),
  _ManagementItem(title: 'Discontinued', subtitle: 'Left · 30-day archive', icon: Icons.person_off_outlined, color: AppColors.leaveCard, route: '/admin/discontinued'),
  _ManagementItem(title: 'Graduated', subtitle: 'Finished · archive', icon: Icons.workspace_premium_outlined, color: AppColors.academicsCard, route: '/admin/graduated'),
  _ManagementItem(title: 'Exams', subtitle: 'Timetables & publish', icon: Icons.quiz_outlined, color: AppColors.examCard, route: '/admin/exams'),
  _ManagementItem(title: 'Results', subtitle: 'Marks & grades by class', icon: Icons.fact_check_outlined, color: AppColors.academicsCard, route: '/admin/results'),
  _ManagementItem(title: 'Admissions', subtitle: 'Enquiry to record', icon: Icons.how_to_reg_outlined, color: AppColors.admissionCard, route: '/admin/admissions'),
  _ManagementItem(title: 'Announcements', subtitle: 'Staff & school', icon: Icons.campaign_outlined, color: AppColors.announcementCard, route: '/admin/announcements'),
  _ManagementItem(title: 'Events', subtitle: 'School calendar', icon: Icons.event_available_outlined, color: AppColors.eventCard, route: '/admin/events'),
  _ManagementItem(title: 'Fees', subtitle: 'Paid & pending', icon: Icons.payments_outlined, color: AppColors.feeCard, route: '/admin/fees'),
  _ManagementItem(title: 'Buses', subtitle: 'Fleet & routes', icon: Icons.directions_bus_outlined, color: AppColors.busCard, route: '/admin/bus-tracking'),
];
