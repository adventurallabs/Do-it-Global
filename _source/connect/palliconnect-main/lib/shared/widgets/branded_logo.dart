import 'package:flutter/material.dart';
import '../../core/design_system/app_colors.dart';

/// The PalliConnect badge, from one trimmed file used by every screen that
/// shows it, so [size] is the badge's real on-screen size (no invisible
/// padding). The OS launch splash draws this same badge at
/// [nativeSplashSize], centred — the Flutter splash starts identical to it.
class BrandedLogo extends StatelessWidget {
  final double size;

  /// Same tag on two screens flies the badge between them.
  final Object? heroTag;

  const BrandedLogo({super.key, this.size = 100, this.heroTag});

  static const double nativeSplashSize = 130;
  static const AssetImage image = AssetImage('assets/icon/splash_logo.png');
  static const Object heroTagSplash = 'palli-connect-mark';

  @override
  Widget build(BuildContext context) {
    final mark = Image(
      image: image,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      semanticLabel: 'PalliConnect',
    );
    return heroTag == null ? mark : Hero(tag: heroTag!, child: mark);
  }
}

/// "PalliConnect" in the display face, filled with the app's brand sweep
/// (blue -> sky -> green) — the same gradient the in-app accents use.
class BrandWordmark extends StatelessWidget {
  final double fontSize;
  const BrandWordmark({super.key, this.fontSize = 28});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          height: 1.1,
          color: Colors.white, // masked by the gradient below
        );
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: dark
            ? const [AppColors.skyBlue, Color(0xFF8FD8FF), AppColors.leafGreen]
            : const [AppColors.royalBlue, AppColors.primaryBlue, AppColors.skyBlue],
      ).createShader(bounds),
      child: Text('PalliConnect', style: style),
    );
  }
}
