import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'brand_atmosphere.dart';

/// Every pushed page with its own backdrop, sliding in over the one beneath.
///
/// Scaffolds are transparent so the brand atmosphere shows through them. It
/// used to be painted once behind the Navigator, which made every route
/// see-through — a new page drew over the old one mid-transition. Painting it
/// per route makes each page opaque; the Cupertino slide then covers the old
/// page completely (it recedes with a parallax and an edge shadow) and adds
/// swipe-back.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 340);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return CupertinoRouteTransitionMixin.buildPageTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      BrandAtmosphere(child: child),
    );
  }
}

const appPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: AppPageTransitionsBuilder(),
    TargetPlatform.iOS: AppPageTransitionsBuilder(),
    TargetPlatform.windows: AppPageTransitionsBuilder(),
    TargetPlatform.macOS: AppPageTransitionsBuilder(),
    TargetPlatform.linux: AppPageTransitionsBuilder(),
  },
);

/// For screens that *replace* each other (splash → sign-in → app): the
/// backdrop covers the old screen at once and only the new content fades
/// and settles in, so two screens' content is never on screen together.
Widget fadeThroughTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final fadeIn = CurvedAnimation(parent: animation, curve: const Interval(0.15, 1, curve: Curves.easeOutCubic));
  return BrandAtmosphere(
    child: FadeTransition(
      opacity: fadeIn,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.975, end: 1).animate(fadeIn),
        child: child,
      ),
    ),
  );
}

/// Swaps whole screens in place (sign-in ↔ app ↔ error) with a fade
/// *through*: the old one is gone before the new one appears.
class FadeThroughSwitcher extends StatelessWidget {
  final Widget child;
  const FadeThroughSwitcher({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: const Interval(0.45, 1, curve: Curves.easeOutCubic),
      switchOutCurve: const Interval(0.55, 1, curve: Curves.easeIn),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Bottom-nav tabs that keep their state, with the chosen tab fading and
/// settling in. Only the incoming tab animates — the outgoing one is hidden
/// at once, so two transparent tabs are never drawn over each other.
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const FadeIndexedStack({super.key, required this.index, required this.children});

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<Offset> _rise = Tween(begin: const Offset(0, 0.018), end: Offset.zero).animate(_fade);

  @override
  void didUpdateWidget(covariant FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      sizing: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          TickerMode(
            enabled: i == widget.index,
            // Same wrappers for every tab, so switching never rebuilds one.
            child: FadeTransition(
              opacity: i == widget.index ? _fade : kAlwaysCompleteAnimation,
              child: SlideTransition(
                position: i == widget.index ? _rise : const AlwaysStoppedAnimation(Offset.zero),
                child: widget.children[i],
              ),
            ),
          ),
      ],
    );
  }
}
