import 'package:flutter/cupertino.dart';

import 'admin_look.dart';

/// Every pushed page, with its own backdrop and a slide that fully covers
/// the page beneath.
///
/// The theme keeps scaffolds transparent so the ringed backdrop shows
/// through them. That backdrop used to be painted once, behind the whole
/// Navigator — so every route was see-through, and the default fade-upwards
/// transition drew the new page's content straight over the old one ("the
/// layout appears on top of the previous page"). Painting the backdrop per
/// route makes each page opaque; the Cupertino slide then moves the new page
/// in over the old one, which recedes with a parallax and a soft edge
/// shadow, and supports swipe-back on every platform.
class PremiumPageTransitionsBuilder extends PageTransitionsBuilder {
  const PremiumPageTransitionsBuilder();

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
      OpaquePage(child: child),
    );
  }
}

/// The app backdrop, painted inside a single route so the route is opaque.
class OpaquePage extends StatelessWidget {
  final Widget child;
  const OpaquePage({super.key, required this.child});

  @override
  Widget build(BuildContext context) => AdminBackdrop(child: child);
}

/// Entry screens (splash → login → home) replace each other rather than
/// stack, so they "fade through": the backdrop covers the old screen at
/// once, and only the new content fades and settles in. The two screens'
/// content is never on screen together.
Widget fadeThroughTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final fadeIn = CurvedAnimation(parent: animation, curve: const Interval(0.15, 1, curve: Curves.easeOutCubic));
  return OpaquePage(
    child: FadeTransition(
      opacity: fadeIn,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.975, end: 1).animate(fadeIn),
        child: child,
      ),
    ),
  );
}
