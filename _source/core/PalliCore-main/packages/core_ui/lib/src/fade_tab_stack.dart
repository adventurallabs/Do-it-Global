import 'package:flutter/material.dart';

/// Bottom-nav tabs that keep their state, built on first visit, with the
/// chosen tab fading and settling in.
///
/// Only the incoming tab animates: the outgoing one is hidden at once. Tab
/// bodies are transparent over the shared backdrop, so cross-fading two of
/// them would overlay one screen's content on the other's.
class FadeTabStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const FadeTabStack({super.key, required this.index, required this.children});

  @override
  State<FadeTabStack> createState() => _FadeTabStackState();
}

class _FadeTabStackState extends State<FadeTabStack> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<Offset> _rise = Tween(begin: const Offset(0, 0.018), end: Offset.zero).animate(_fade);
  late final Set<int> _opened = {widget.index};

  @override
  void didUpdateWidget(covariant FadeTabStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _opened.add(widget.index);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (_opened.contains(i))
            Offstage(
              key: ValueKey(i),
              offstage: i != widget.index,
              child: TickerMode(
                enabled: i == widget.index,
                // Same wrappers for every tab, selected or not, so switching
                // never rebuilds a tab's subtree from scratch.
                child: FadeTransition(
                  opacity: i == widget.index ? _fade : kAlwaysCompleteAnimation,
                  child: SlideTransition(
                    position: i == widget.index ? _rise : const AlwaysStoppedAnimation(Offset.zero),
                    child: widget.children[i],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
