import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/ui.dart' show confirm;

/// Shown while the app starts. On deep navy, the Nuvara "u" springs up from the ground, lands with a
/// squash, the two sky-blue dots drop onto it one after the other with a ripple of light, and the wordmark
/// and tagline settle in beneath. Soft orange and sky light drifts behind. [Boot] keeps it up until the
/// intro has played and the saved session (if any) has loaded.
class SplashScreen extends StatefulWidget {
  /// The saved session couldn't load because the server wasn't reachable.
  final bool offline;
  final bool retrying;

  /// Shown instead of the default "couldn't reach the server" text when [offline].
  final String? message;

  /// Buttons are hidden when their callback is null.
  final VoidCallback? onRetry, onSignOut;

  const SplashScreen({super.key, this.offline = false, this.retrying = false, this.message, this.onRetry, this.onSignOut});

  static const intro = Duration(milliseconds: 2600);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final _intro = AnimationController(vsync: this, duration: SplashScreen.intro)..forward();
  late final _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200))..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _idle.dispose();
    super.dispose();
  }

  /// The intro's progress mapped onto [from]..[to], eased.
  double _phase(double from, double to, [Curve curve = Curves.easeOutCubic]) => curve.transform(((_intro.value - from) / (to - from)).clamp(0.0, 1.0));

  /// A landing: a quick squash that springs back, as [t] goes 0 → 1.
  static double _land(double t) => t <= 0 || t >= 1 ? 0 : -math.sin(t * math.pi * 2.5) * math.exp(-4 * t);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mark = math.min(190.0, math.min(size.shortestSide * 0.44, size.height * 0.27));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: C.brand900),
      child: Scaffold(
        backgroundColor: C.brand900,
        body: AnimatedBuilder(
          animation: Listenable.merge([_intro, _idle]),
          builder: (context, _) {
            final bloom = _phase(0, 0.35);
            final loop = _idle.value * 2 * math.pi;
            final rise = _phase(0.08, 0.36, Curves.easeOutBack);
            final leftDot = _phase(0.34, 0.58, Curves.bounceOut);
            final rightDot = _phase(0.44, 0.68, Curves.bounceOut);
            // Squash on landing, again (smaller) as each dot lands, then a gentle breath.
            final squash = 0.9 * _land(_phase(0.30, 0.56, Curves.linear)) +
                0.35 * _land(_phase(0.50, 0.70, Curves.linear)) +
                0.35 * _land(_phase(0.60, 0.80, Curves.linear)) +
                (_intro.isCompleted ? 0.08 * math.sin(loop * 2) : 0);
            final ripple = _phase(0.58, 0.95, Curves.easeOutQuart);
            final word = _phase(0.62, 0.86);
            final tagline = _phase(0.76, 1);
            final bob = _intro.isCompleted ? -0.025 * (0.5 + 0.5 * math.sin(loop * 2)) : 0.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Light: the native launch screen's flat navy blooms into a gradient with drifting glows.
                Opacity(opacity: bloom, child: const DecoratedBox(decoration: BoxDecoration(gradient: heroGradient))),
                Positioned(
                  top: -size.width * 0.55 + math.sin(loop) * 18,
                  right: -size.width * 0.5 + math.cos(loop) * 14,
                  child: _glow(C.sky.withValues(alpha: 0.22 * bloom), size.width * 1.35),
                ),
                Positioned(
                  bottom: -size.width * 0.6 - math.sin(loop) * 16,
                  left: -size.width * 0.5 + math.cos(loop) * 12,
                  child: _glow(C.clay500.withValues(alpha: 0.20 * bloom), size.width * 1.3),
                ),
                IgnorePointer(child: CustomPaint(painter: _Motes(t: _idle.value, opacity: bloom))),
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 5),
                      SizedBox(
                        width: mark * 2,
                        height: mark * 1.25,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // A ring of light ripples out as the second dot lands.
                            if (ripple > 0 && ripple < 1)
                              Container(
                                width: mark * (0.8 + ripple * 1.1),
                                height: mark * (0.8 + ripple * 1.1),
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.sky.withValues(alpha: 0.45 * (1 - ripple)), width: 1.6)),
                              ),
                            // Soft halo behind the mark.
                            Container(
                              width: mark * 1.5,
                              height: mark * 1.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.10 * bloom), Colors.white.withValues(alpha: 0)]),
                              ),
                            ),
                            SizedBox(
                              width: mark * markAspect,
                              height: mark,
                              child: CustomPaint(
                                painter: NuvaraMarkPainter(rise: rise, squash: squash, leftDot: leftDot, rightDot: rightDot, bob: bob, shadow: true),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: mark * 0.12),
                      Opacity(
                        opacity: word,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - word)),
                          child: Transform.scale(scale: 0.94 + 0.06 * word, child: NuvaraWordmark(height: math.min(30, mark * 0.17), light: true, inline: true)),
                        ),
                      ),
                      const Spacer(flex: 4),
                      ConstrainedBox(constraints: const BoxConstraints(minHeight: 70), child: _footer(tagline)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Leaving forgets this login on the device: say so first, since the password is needed to come back.
  Future<void> _useAnotherLogin() async {
    final ok = await confirm(
      context,
      title: 'Use another login?',
      message: "This device will forget this login. To come back to it you'll need its password, and only the centre can reset a forgotten one.${widget.onRetry == null ? '' : "\n\nIf you're just offline, tap Try again instead."}",
      action: 'Use another login',
    );
    if (ok) widget.onSignOut?.call();
  }

  Widget _footer(double tagline) {
    if (widget.offline) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.message ?? "Couldn't reach the server. Check your internet connection.",
              textAlign: TextAlign.center,
              style: body(13.5, color: C.brand100, height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.onSignOut != null)
                  TextButton(onPressed: _useAnotherLogin, style: TextButton.styleFrom(foregroundColor: C.brand200), child: const Text('Use another login')),
                if (widget.onRetry != null)
                  FilledButton(
                    onPressed: widget.retrying ? null : widget.onRetry,
                    style: FilledButton.styleFrom(backgroundColor: C.clay600, foregroundColor: Colors.white, disabledBackgroundColor: C.clay600.withValues(alpha: 0.5)),
                    child: widget.retrying ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Try again'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: tagline,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - tagline)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text.rich(
                textAlign: TextAlign.center,
                TextSpan(children: [
                  const TextSpan(text: 'Every step forward '),
                  TextSpan(text: 'matters', style: body(14.5, weight: FontWeight.w700, color: C.sky)),
                ]),
                style: body(14.5, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.82)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Still loading after the intro (slow network): three dots in the brand colours take turns.
        AnimatedOpacity(opacity: _intro.isCompleted ? 1 : 0, duration: const Duration(milliseconds: 300), child: _Dots(_idle.value)),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _glow(Color c, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)])),
        ),
      );
}

/// Tiny points of orange and sky light rising slowly, for depth.
class _Motes extends CustomPainter {
  final double t, opacity;
  const _Motes({required this.t, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final rnd = math.Random(7);
    for (var i = 0; i < 22; i++) {
      final x = rnd.nextDouble() * size.width;
      final speed = 0.3 + rnd.nextDouble() * 0.7;
      final y = (rnd.nextDouble() - t * speed) % 1.0 * size.height;
      final r = 1.0 + rnd.nextDouble() * 2.2;
      final twinkle = 0.5 + 0.5 * math.sin((t * 6 + i) * math.pi);
      final c = i.isEven ? C.sky : C.clay500;
      canvas.drawCircle(Offset(x + math.sin((t + i) * 2 * math.pi) * 6, y), r, Paint()..color = c.withValues(alpha: (0.10 + 0.25 * twinkle) * opacity));
    }
  }

  @override
  bool shouldRepaint(_Motes o) => o.t != t || o.opacity != opacity;
}

class _Dots extends StatelessWidget {
  final double t;
  const _Dots(this.t);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Builder(builder: (_) {
              final wave = 0.5 + 0.5 * math.sin((t * 8 - i / 3) * 2 * math.pi);
              return Transform.translate(
                offset: Offset(0, -4 * wave),
                child: Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: (i == 1 ? C.clay500 : C.sky).withValues(alpha: 0.45 + 0.55 * wave)),
                ),
              );
            }),
        ],
      );
}
