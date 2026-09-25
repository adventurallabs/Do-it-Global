import 'package:flutter/material.dart';

/// PalliCore visual system — neumorphic soft UI.
///
/// Same clay color for canvas and raised surfaces. Depth comes from
/// dual shadows (white highlight top-left, gray shadow bottom-right)
/// plus a slight lighting gradient across each face.
///
/// Depth hierarchy:
/// - L0 background: flat clay
/// - L1 normal surfaces: cards, statistics
/// - L2 interactive controls: buttons, pills, selected nav
/// - L3 hero: home dashboard panel, analog clock bezel
class AppColors {
  AppColors._();

  // Clay — background and surfaces share this so only shadows create depth.
  static const Color background = Color(0xFFEDEBE7);
  static const Color surface = Color(0xFFEDEBE7);
  static const Color surfaceMuted = Color(0xFFE4E2DC);

  // Text — light defaults. Prefer onSurface* so dark mode stays readable.
  static const Color textPrimary = Color(0xFF303137);
  static const Color textSecondary = Color(0xFF70727A);
  static const Color textHint = Color(0xFF9A9CA3);

  static const Color _darkInk = Color(0xFFF6F1EA);
  static const Color _darkMute = Color(0xFFC9C2B6);
  static const Color _darkHint = Color(0xFFB7B0A2);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color onSurface(BuildContext context) =>
      _isDark(context) ? _darkInk : textPrimary;

  static Color onSurfaceMuted(BuildContext context) =>
      _isDark(context) ? _darkMute : textSecondary;

  static Color onSurfaceHint(BuildContext context) =>
      _isDark(context) ? _darkHint : textHint;

  // Brand accent — use sparingly
  static const Color accent = Color(0xFF8B7355);
  static const Color accentAlt = Color(0xFF303137);

  // Compat aliases used across the app
  static const Color neoBase = surface;
  static const Color neoDarkShadow = Color(0xFFBEBEBE);
  static const Color neoLightShadow = Color(0xFFFFFFFF);
  static const Color primaryDark = background;
  static const Color primaryMid = Color(0xFFE4E2DC);
  static const Color primaryLight = Color(0xFFD8DBD4);
  static const Color surfaceLight = surfaceMuted;
  static const Color surfaceCard = surface;
  static const Color surfaceElevated = Color(0xFFEDEBE7);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF2F0EC), background, Color(0xFFE4E2DC)],
  );

  /// Raised face — light hits the upper-left curve.
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7F5F2), Color(0xFFEDEBE7), Color(0xFFE2E0DA)],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFAF8F5), Color(0xFFEDEBE7), Color(0xFFDCD9D3)],
    stops: [0.0, 0.42, 1.0],
  );

  /// Recessed well — opposite lighting, sunken into the clay.
  static const LinearGradient insetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC9C4BC), Color(0xFFE4E2DC), Color(0xFFF6F5F2)],
    stops: [0.0, 0.42, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB89A6E), Color(0xFF7A6548)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB8574A), Color(0xFF8E3B32)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6B8F71), Color(0xFF4A6B50)],
  );

  static const Color currentPeriod = Color(0xFF8B7355);
  static const Color upcomingPeriod = Color(0xFF5E7A5A);
  static const Color endedPeriod = Color(0xFF8A8690);
  static const Color missedPeriod = Color(0xFFB8574A);
  static const Color temporaryPeriod = Color(0xFFC48A3A);

  static const Color classroomCard = Color(0xFF8B7355);
  static const Color teacherCard = Color(0xFF5B4A3A);
  static const Color studentCard = Color(0xFF5E7A5A);
  static const Color announcementCard = Color(0xFFC48A3A);
  static const Color busCard = Color(0xFF7A5A48);
  static const Color eventCard = Color(0xFF6A5A8C);
  static const Color feeCard = Color(0xFF3F6B6A);
  static const Color attendanceCard = Color(0xFF4E6B5A);
  static const Color leaveCard = Color(0xFF8A5A4A);
  static const Color academicsCard = Color(0xFF6B5A3A);
  static const Color examCard = Color(0xFF4A5A7A);
  static const Color admissionCard = Color(0xFF5A6B4A);

  static const Color periodCell = Color(0xFF8B7355);
  static const Color breakCell = Color(0xFF5E7A5A);
  static const Color lunchCell = Color(0xFFC48A3A);
  static const Color emptyCell = Color(0xFFE3E1DB);

  static const Color divider = Color(0xFFD8D5CE);
  static const Color error = Color(0xFFB8574A);
  static const Color success = Color(0xFF5E7A5A);
  static const Color warning = Color(0xFFC48A3A);
  static const Color shimmer = Color(0xFFDCD9D3);

  /// Level 1 — extruded cards. Classic neo: 10 / 10 / 20 #bebebe + white.
  static List<BoxShadow> get depth1 => const [
        BoxShadow(
          color: Color(0xFFBEBEBE),
          offset: Offset(10, 10),
          blurRadius: 20,
        ),
        BoxShadow(
          color: Color(0xFFFFFFFF),
          offset: Offset(-10, -10),
          blurRadius: 20,
        ),
      ];

  /// Level 2 — tighter extruded controls that feel pressable.
  static List<BoxShadow> get depth2 => const [
        BoxShadow(
          color: Color(0xFFB8B8B8),
          offset: Offset(8, 8),
          blurRadius: 16,
        ),
        BoxShadow(
          color: Color(0xFFFFFFFF),
          offset: Offset(-8, -8),
          blurRadius: 16,
        ),
      ];

  /// Level 3 — floating hero objects.
  static List<BoxShadow> get depth3 => const [
        BoxShadow(
          color: Color(0xFFB0B0B0),
          offset: Offset(16, 16),
          blurRadius: 28,
        ),
        BoxShadow(
          color: Color(0xFFFFFFFF),
          offset: Offset(-14, -14),
          blurRadius: 24,
        ),
      ];

  /// Recessed well — used with [insetGradient], not as a float shadow.
  static List<BoxShadow> get depthInset => const [];

  static Gradient highlightFor(SoftDepth depth) {
    switch (depth) {
      case SoftDepth.none:
      case SoftDepth.one:
        return cardGradient;
      case SoftDepth.two:
        return cardGradient;
      case SoftDepth.three:
        return heroGradient;
    }
  }

  // Legacy aliases → map to hierarchy
  static List<BoxShadow> get softShadow => depth1;
  static List<BoxShadow> neoConvex({double intensity = 1, double distance = 8, double blur = 20}) => depth2;
  static List<BoxShadow> neoConvexSoft() => depth1;
  static List<BoxShadow> neoConvexTight() => depth2;
  static List<BoxShadow> neoConcaveHint({double intensity = 1}) => depthInset;
}

enum SoftDepth { none, one, two, three }
