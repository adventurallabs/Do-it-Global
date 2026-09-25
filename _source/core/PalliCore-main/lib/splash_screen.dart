import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:core_ui/core_ui.dart';

/// Flips true once the splash has been on screen long enough to finish its
/// entrance — merged into the router's `refreshListenable` alongside
/// [authStateNotifier] so it can hold the splash route open even when the
/// session check resolves instantly.
final ValueNotifier<bool> splashMinDurationNotifier = ValueNotifier(false);

/// How long the entrance takes; main.dart holds the route at least this long.
const Duration splashEntrance = Duration(milliseconds: 1250);

/// Branded loading screen shown at `/splash` while [LoginBloc] resolves
/// whether a session is already persisted. Purely presentational — the
/// go_router redirect (see router.dart) decides when to leave it.
///
/// Its first frame is identical to the OS launch splash (same canvas colour,
/// same 130dp badge, dead centre), so the hand-off is invisible; then the
/// badge lifts, the wordmark and tagline rise in, and a gold ring breathes.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _entrance =
      AnimationController(vsync: this, duration: splashEntrance);
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    // Drop the OS splash only after this widget has painted — the two frames
    // are identical, so there is no blink.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      if (!mounted) return;
      _entrance.forward().whenComplete(() => splashMinDurationNotifier.value = true);
      _pulse.repeat();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(BrandMark.image, context);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Animation<double> _curve(double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _entrance, curve: Interval(begin, end, curve: curve));

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final lift = _curve(0.0, 0.55);
    final word = _curve(0.30, 0.75);
    final tag = _curve(0.48, 0.95);
    final ring = _curve(0.35, 1.0, Curves.easeOut);
    const size = BrandMark.nativeSplashSize;

    // Transparent: the app-wide AdminBackdrop (canvas + rings) sits behind.
    // A plain canvas layer starts on top — matching the OS splash exactly —
    // and fades away so the rings the login screen uses drift in.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: Listenable.merge([_entrance, _pulse]),
        builder: (context, _) {
          final l = reduceMotion ? 1.0 : lift.value;
          final w = reduceMotion ? 1.0 : word.value;
          final t = reduceMotion ? 1.0 : tag.value;
          final p = _pulse.value;
          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: AdminLook.canvasOf(context).withValues(alpha: 1 - (reduceMotion ? 1.0 : ring.value)),
                  ),
                ),
              ),
              // badge: starts exactly where the OS drew it, then lifts 56px
              Center(
                child: Transform.translate(
                  offset: Offset(0, -56 * l),
                  child: SizedBox(
                    width: size * 1.9,
                    height: size * 1.9,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!reduceMotion)
                          Opacity(
                            opacity: ring.value * (1 - p) * 0.55,
                            child: Transform.scale(
                              scale: 0.85 + p * 0.55,
                              child: Container(
                                width: size * 1.15,
                                height: size * 1.15,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(size * 0.36),
                                  border: Border.all(color: AdminLook.gold, width: 1.4),
                                ),
                              ),
                            ),
                          ),
                        const BrandMark(size: size, heroTag: BrandMark.splashHeroTag),
                      ],
                    ),
                  ),
                ),
              ),
              // wordmark + tagline rise into the space the badge vacates
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: size + 70),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: w,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - w)),
                          child: Text(
                            'PalliCore',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.8,
                              color: AdminLook.inkOf(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - t)),
                          child: Column(
                            children: [
                              Container(
                                width: 28 + 20 * t,
                                height: 2,
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AdminLook.gold,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Text(
                                'A quieter way to run a school',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  letterSpacing: 0.3,
                                  color: AdminLook.muteOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
