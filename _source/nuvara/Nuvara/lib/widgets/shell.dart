import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'brand.dart';
import 'ui.dart' show wideBreakpoint;

class NavItem {
  final String path, label;
  final IconData icon, activeIcon;

  /// Shows the unread-messages count on this tab.
  final bool unreadBadge;

  /// Shows how many sessions the family still has to confirm (parent Schedule).
  final bool confirmBadge;
  const NavItem(this.path, this.label, this.icon, this.activeIcon, {this.unreadBadge = false, this.confirmBadge = false});
}

/// The app tile: the Nuvara mark on navy, as on the launcher icon. [light] for dark backgrounds.
class Logo extends StatelessWidget {
  final bool light;
  final double size;
  const Logo({super.key, this.light = false, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: light ? Colors.white.withValues(alpha: 0.08) : C.brand900,
          borderRadius: BorderRadius.circular(size * 0.3),
          border: light ? Border.all(color: Colors.white.withValues(alpha: 0.14)) : null,
          boxShadow: light ? null : [BoxShadow(color: C.shadow.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: NuvaraMark(size: size * 0.62),
      );
}

const roleTabs = {
  Role.admin: [
    NavItem('/admin', 'Home', Icons.home_outlined, Icons.home_rounded),
    NavItem('/admin/timetable', 'Timetable', Icons.calendar_view_week_outlined, Icons.calendar_view_week_rounded),
    NavItem('/admin/children', 'Children', Icons.child_care_outlined, Icons.child_care_rounded),
    NavItem('/admin/fees', 'Fees', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
    NavItem('/admin/messages', 'Messages', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, unreadBadge: true),
  ],
  Role.therapist: [
    NavItem('/therapist', 'Today', Icons.today_outlined, Icons.today_rounded),
    NavItem('/therapist/week', 'Week', Icons.calendar_view_week_outlined, Icons.calendar_view_week_rounded),
    NavItem('/therapist/children', 'Children', Icons.child_care_outlined, Icons.child_care_rounded),
    NavItem('/therapist/messages', 'Messages', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, unreadBadge: true),
  ],
  Role.parent: [
    NavItem('/parent', 'Home', Icons.home_outlined, Icons.home_rounded),
    NavItem('/parent/schedule', 'Schedule', Icons.calendar_month_outlined, Icons.calendar_month_rounded, confirmBadge: true),
    NavItem('/parent/progress', 'Progress', Icons.insights_outlined, Icons.insights_rounded),
    NavItem('/parent/fees', 'Fees', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
    NavItem('/parent/messages', 'Messages', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, unreadBadge: true),
  ],
};

/// Role frame: the tab's page plus navigation that fits the screen. Phones get a bottom bar, tablets a
/// side rail, and laptops/desktops a rail with labels.
class Shell extends StatelessWidget {
  final Role role;
  final StatefulNavigationShell shell;
  const Shell({super.key, required this.role, required this.shell});

  /// From this width the bottom bar becomes a side rail (the same width at which sheets become dialogs).
  static const railBreakpoint = wideBreakpoint;

  /// Below this height (a phone on its side) the rail can't fit its tabs; keep the bottom bar.
  static const railMinHeight = 480.0;

  /// From this width the rail shows its labels beside the icons.
  static const extendedBreakpoint = 1200.0;

  // Tapping the current tab again returns it to its first screen.
  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final tabs = roleTabs[role]!;
    final unread = context.select<AppStore, int>((s) => s.unreadMessages);
    final toConfirm = context.select<AppStore, int>((s) => s.toConfirm);
    final switching = context.select<AppStore, bool>((s) => s.switching);
    // While a parent moves to another child's login the data is being replaced; cover it.
    final page = Stack(children: [
      shell,
      if (switching)
        Positioned.fill(
          child: ColoredBox(
            color: C.canvas.withValues(alpha: 0.92),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 14),
                Text('Switching account…', style: body(14, weight: FontWeight.w600, color: C.muted)),
              ]),
            ),
          ),
        ),
    ]);
    Widget icon(NavItem t, bool active) {
      final n = t.unreadBadge ? unread : (t.confirmBadge ? toConfirm : 0);
      return Badge(isLabelVisible: n > 0, label: Text('$n'), backgroundColor: t.confirmBadge ? C.amber : C.clay600, child: Icon(active ? t.activeIcon : t.icon));
    }

    // Each tab keeps its own stack with a single page (detail screens open above the shell), so Android's
    // back button on any tab but the first would close the app. Go back to the first tab instead; only
    // back from there leaves.
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: _frame(context, tabs, page, icon),
    );
  }

  Widget _frame(BuildContext context, List<NavItem> tabs, Widget page, Widget Function(NavItem, bool) icon) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= railBreakpoint && MediaQuery.sizeOf(context).height >= railMinHeight) {
      final extended = width >= extendedBreakpoint;
      return Scaffold(
        body: Row(children: [
          DecoratedBox(
            decoration: const BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: C.line))),
            child: SafeArea(
              right: false,
              // Scrolls rather than overflows when large text or a short window leaves too little height.
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        extended: extended,
                        minExtendedWidth: 232,
                        backgroundColor: Colors.white,
                        selectedIndex: shell.currentIndex,
                        onDestinationSelected: _go,
                        labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                        indicatorColor: C.brand100,
                        selectedIconTheme: const IconThemeData(color: C.brand800, size: 22),
                        unselectedIconTheme: const IconThemeData(color: C.muted, size: 22),
                        selectedLabelTextStyle: body(13, weight: FontWeight.w700, color: C.brand800),
                        unselectedLabelTextStyle: body(13, weight: FontWeight.w600, color: C.muted),
                        leading: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
                          child: extended
                              ? SizedBox(
                                  width: 200,
                                  child: Row(children: [
                                    const Logo(size: 36),
                                    const SizedBox(width: 10),
                                    const Expanded(child: Align(alignment: Alignment.centerLeft, child: FittedBox(child: NuvaraWordmark(height: 15, inline: true)))),
                                  ]),
                                )
                              : const Logo(size: 36),
                        ),
                        destinations: [
                          for (final t in tabs) NavigationRailDestination(icon: icon(t, false), selectedIcon: icon(t, true), label: Text(t.label)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: SafeArea(left: false, bottom: false, child: page)),
        ]),
      );
    }

    return Scaffold(
      body: SafeArea(bottom: false, child: page),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: C.line)),
          boxShadow: [BoxShadow(color: Color(0x0F010039), blurRadius: 18, offset: Offset(0, -4))],
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          destinations: [
            for (final t in tabs) NavigationDestination(icon: icon(t, false), selectedIcon: icon(t, true), label: t.label),
          ],
        ),
      ),
    );
  }
}

/// Keeps every tab alive (each keeps its scroll position, search and filters) but only the visible one
/// runs: hidden tabs' animations are paused, so they cost no frames. Switching tabs fades the new one in.
class TabStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const TabStack({super.key, required this.index, required this.children});

  @override
  State<TabStack> createState() => _TabStackState();
}

class _TabStackState extends State<TabStack> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1);
  late final _curve = CurvedAnimation(parent: _fade, curve: Curves.easeOut);

  @override
  void didUpdateWidget(TabStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _fade.forward(from: 0.35);
  }

  @override
  void dispose() {
    _curve.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IndexedStack(
        index: widget.index,
        sizing: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            TickerMode(
              enabled: i == widget.index,
              child: HeroMode(
                enabled: i == widget.index,
                // Same widgets for every tab, visible or not, so switching never rebuilds a tab from scratch.
                child: FadeTransition(opacity: i == widget.index ? _curve : kAlwaysCompleteAnimation, child: widget.children[i]),
              ),
            ),
        ],
      );
}
