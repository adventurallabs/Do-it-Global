import 'package:flutter/material.dart';

/// The PalliCore badge, from one file shared by every screen that shows it
/// (splash, login, ...). The image is trimmed to the badge itself, so
/// [size] is the badge's real on-screen size — no invisible padding.
///
/// The OS launch splash draws this same badge at [nativeSplashSize], centred,
/// so the Flutter splash can start pixel-identical to it.
class BrandMark extends StatelessWidget {
  final double size;

  /// Pass the same tag on two screens to fly the badge between them.
  final Object? heroTag;

  const BrandMark({super.key, this.size = 96, this.heroTag});

  static const double nativeSplashSize = 130;
  static const AssetImage image = AssetImage('assets/brand/logo.png', package: 'core_ui');
  static const Object splashHeroTag = 'palli-brand-mark';

  @override
  Widget build(BuildContext context) {
    final mark = Image(
      image: image,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      semanticLabel: 'PalliCore',
    );
    return heroTag == null ? mark : Hero(tag: heroTag!, child: mark);
  }
}
