import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../../core/auth/session_provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/localization/l10n_ext.dart';
import '../../shared/widgets/branded_logo.dart';
import '../auth/auth_gate.dart';
import '../../core/design_system/app_page_transitions.dart';

/// First Flutter frame is identical to the OS launch splash (flat page
/// colour, 130dp badge, dead centre) so the hand-off is invisible. Then the
/// app's own atmosphere fades in behind it, the badge lifts, the wordmark
/// rises, and — once data is ready — it cross-fades into Login / the app,
/// with the badge flying to its place on the login screen.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _entrance =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

  bool _dataReady = false;
  bool _entranceDone = false;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _preload();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      if (!mounted) return;
      _entrance.forward().whenComplete(() {
        _entranceDone = true;
        _maybeLeave();
      });
      _pulse.repeat();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(BrandedLogo.image, context);
  }

  Future<void> _preload() async {
    try {
      await ref.read(sessionProvider.notifier).bootstrap().timeout(const Duration(seconds: 6));
    } catch (_) {
      // Never trap the user here — AuthGate shows the real signed-out /
      // error / login state next.
    }
    _dataReady = true;
    _maybeLeave();
  }

  void _maybeLeave() {
    if (_left || !_dataReady || !_entranceDone || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const AuthGate(),
        transitionDuration: const Duration(milliseconds: 520),
        // Fade *through* the backdrop: a plain fade drew the transparent
        // next screen on top of the splash while both were visible.
        transitionsBuilder: fadeThroughTransition,
      ),
    );
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Animation<double> _curve(double a, double b, [Curve c = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _entrance, curve: Interval(a, b, curve: c));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    // exactly the native splash colour (flutter_native_splash.yaml)
    final nativeBg = isDark ? const Color(0xFF050B14) : const Color(0xFFF7FBFF);
    final atmosphere = _curve(0.20, 0.85, Curves.easeOut);
    final lift = _curve(0.0, 0.55);
    final word = _curve(0.30, 0.75);
    final tag = _curve(0.50, 0.95);
    const size = BrandedLogo.nativeSplashSize;

    return Scaffold(
      // transparent: the app-wide BrandAtmosphere is behind this screen
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: Listenable.merge([_entrance, _pulse]),
        builder: (context, _) {
          final l = reduceMotion ? 1.0 : lift.value;
          final w = reduceMotion ? 1.0 : word.value;
          final t = reduceMotion ? 1.0 : tag.value;
          final atm = reduceMotion ? 1.0 : atmosphere.value;
          final p = _pulse.value;
          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(child: ColoredBox(color: nativeBg.withValues(alpha: 1 - atm))),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, -56 * l),
                  child: SizedBox(
                    width: size * 2,
                    height: size * 2,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // soft brand glow behind the badge
                        Opacity(
                          opacity: atm,
                          child: Container(
                            width: size * 2,
                            height: size * 2,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                AppColors.primaryBlue.withValues(alpha: isDark ? 0.28 : 0.16),
                                AppColors.primaryBlue.withValues(alpha: 0),
                              ]),
                            ),
                          ),
                        ),
                        if (!reduceMotion)
                          Opacity(
                            opacity: atm * (1 - p) * 0.6,
                            child: Transform.scale(
                              scale: 0.86 + p * 0.5,
                              child: Container(
                                width: size * 1.15,
                                height: size * 1.15,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(size * 0.36),
                                  border: Border.all(color: AppColors.skyBlue, width: 1.4),
                                ),
                              ),
                            ),
                          ),
                        const BrandedLogo(size: size, heroTag: BrandedLogo.heroTagSplash),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: size + 74),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: w,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - w)),
                          child: const BrandWordmark(fontSize: 30),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - t)),
                          child: Column(
                            children: [
                              Container(
                                width: 28 + 20 * t,
                                height: 3,
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  gradient: AppColors.brandSweep(),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              Text(
                                context.l10n.appTagline,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  letterSpacing: 0.3,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
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
