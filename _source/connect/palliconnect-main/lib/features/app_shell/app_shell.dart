import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/session_provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_page_transitions.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/features/feature_registry.dart';
import '../../core/localization/l10n_ext.dart';
import '../diary/diary_screen.dart';
import '../messages/message_screen.dart';
import '../messages/message_store.dart';
import '../profile/profile_screen.dart';
import '../progress/progress_screen.dart';
import '../today/today_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final registry = ref.watch(featureRegistryProvider);
    ref.watch(currentStudentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadMessages = ref.watch(unreadMessageCountProvider);

    final List<(NavigationDestination, Widget, String)> tabs = [
      (
        NavigationDestination(
          icon: const Icon(Icons.wb_sunny_outlined),
          selectedIcon: const Icon(Icons.wb_sunny_rounded),
          label: l10n.tabToday,
        ),
        const TodayScreen(),
        'today'
      ),
      if (registry.isEnabled('digital_diary'))
        (
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book_rounded),
            label: l10n.tabDiary,
          ),
          const DiaryScreen(),
          'digital_diary'
        ),
      (
        NavigationDestination(
          icon: _BadgedIcon(icon: Icons.chat_bubble_outline_rounded, count: unreadMessages),
          selectedIcon: _BadgedIcon(icon: Icons.chat_bubble_rounded, count: unreadMessages),
          label: l10n.tabMessages,
        ),
        MessageScreen(onBack: () => setState(() => _index = 0)),
        'messages'
      ),
      (
        NavigationDestination(
          icon: const Icon(Icons.insights_outlined),
          selectedIcon: const Icon(Icons.insights_rounded),
          label: l10n.tabProgress,
        ),
        const ProgressScreen(),
        'progress'
      ),
      (
        NavigationDestination(
          icon: const Icon(Icons.person_outline_rounded),
          selectedIcon: const Icon(Icons.person_rounded),
          label: l10n.tabProfile,
        ),
        const ProfileScreen(),
        'profile'
      ),
    ];

    if (_index >= tabs.length) _index = 0;

    final isMessages = tabs[_index].$3 == 'messages';

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _index = 0);
      },
      child: Scaffold(
      extendBody: true,
      body: FadeIndexedStack(
        key: ValueKey(ref.watch(currentStudentProvider)?.id ?? 'none'),
        index: _index,
        children: tabs.map((t) => t.$2).toList(),
      ),
      bottomNavigationBar: isMessages ? null : Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(
                  color: AppColors.skyBlue.withValues(alpha: isDark ? 0.22 : 0.35),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isDark ? AppColors.surfaceDark : Colors.white).withValues(alpha: 0.82),
                    (isDark ? AppColors.deepNavy : AppColors.ice).withValues(alpha: 0.72),
                  ],
                ),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) {
                  setState(() => _index = i);
                  if (tabs[i].$3 == 'messages') {
                    ref.read(messageProvider.notifier).markRead();
                  }
                },
                destinations: [
                  for (var i = 0; i < tabs.length; i++)
                    NavigationDestination(
                      icon: tabs[i].$1.icon,
                      selectedIcon: _SelectedNavIcon(icon: tabs[i].$1.selectedIcon ?? tabs[i].$1.icon),
                      label: tabs[i].$1.label,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _SelectedNavIcon extends StatelessWidget {
  final Widget icon;

  const _SelectedNavIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: AppColors.brandSweep(opacity: 0.18),
      ),
      child: IconTheme(
        data: const IconThemeData(color: AppColors.primaryBlue, size: 22),
        child: icon,
      ),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  final IconData icon;
  final int count;

  const _BadgedIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 15),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}
