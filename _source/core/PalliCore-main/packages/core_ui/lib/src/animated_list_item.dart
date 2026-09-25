import 'package:flutter/material.dart';

/// One-shot list entrance: each of the first rows fades and rises into place
/// a beat after the one above it. Rows past the first few (and every row
/// once it has played) render plain, so long lists scroll at full speed.
///
/// The old version gave later rows a longer duration instead of a later
/// start — every row began moving at once, the bottom ones just slower, and
/// without a fade they visibly dragged across the rows above.
class AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Rows at or past this index render without the entrance.
  final int staggerLimit;

  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.delay = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 360),
    this.staggerLimit = 8,
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _curve;

  bool get _animates => widget.index < widget.staggerLimit;

  @override
  void initState() {
    super.initState();
    if (!_animates) return;
    final lead = widget.delay * widget.index;
    final total = lead + widget.duration;
    final start = lead.inMicroseconds / total.inMicroseconds;
    _controller = AnimationController(vsync: this, duration: total)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() {
            _controller?.dispose();
            _controller = null;
          });
        }
      })
      ..forward();
    _curve = CurvedAnimation(parent: _controller!, curve: Interval(start, 1, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = RepaintBoundary(child: widget.child);
    final curve = _curve;
    if (_controller == null || curve == null) return child;
    return FadeTransition(
      opacity: curve,
      child: AnimatedBuilder(
        animation: curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 14 * (1 - curve.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}

/// Content that replaces a spinner fades and rises in, instead of popping.
class FadeIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  const FadeIn({super.key, required this.child, this.duration = const Duration(milliseconds: 340)});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
