import 'package:flutter/material.dart';

/// Palette for the admin PremiumSurface material.
abstract final class PremiumColors {
  static const Color canvas = Color(0xFFFDFBF7);
  static const Color surfaceHi = Color(0xFFFDFCF9);
  static const Color surfaceMid = Color(0xFFF7F6F2);
  static const Color surfaceLo = Color(0xFFF1EFE9);
  static const Color goldHi = Color(0xFFF8E7B0);
  static const Color gold = Color(0xFFE8C36A);
  static const Color goldMid = Color(0xFFC79A45);
  static const Color goldLo = Color(0xFFC99532);
  static const Color goldFade = Color(0xFFF8F4E8);
  static const Color ink = Color(0xFF141414);
  static const Color mute = Color(0xFF8A8680);
  static const Color arc = Color(0xFFD9CDB8);

  static const LinearGradient surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceHi, surfaceMid, surfaceLo],
    stops: [0.0, 0.45, 1.0],
  );

  /// Metallic rim — brighter at the lit corners, bronze in the shade.
  static const LinearGradient goldEdge = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      goldHi,
      gold,
      goldFade,
      goldLo,
      gold,
    ],
    stops: [0.0, 0.18, 0.48, 0.82, 1.0],
  );

  /// Bevel ring sitting just inside the gold.
  static const LinearGradient innerHighlight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xF2FFFFFF),
      Color(0x00FFFFFF),
      Color(0x33C4B49A),
    ],
    stops: [0.0, 0.16, 0.42, 1.0],
  );
}
