import 'package:flutter/material.dart';

class AppColors {
  // ── Logo brand ──────────────────────────────────────────────────
  static const Color midnight = Color(0xFF07111F);
  static const Color deepNavy = Color(0xFF0A1628);
  static const Color royalBlue = Color(0xFF1E4FD8);
  static const Color primaryBlue = Color(0xFF2F6BFF);
  static const Color skyBlue = Color(0xFF3EC6FF);
  static const Color ice = Color(0xFFEAF4FF);
  static const Color leafGreen = Color(0xFF22C55E);
  static const Color limeGreen = Color(0xFF7CFF6B);
  static const Color heart = Color(0xFFF43F5E);
  static const Color coralRed = heart;

  // Legacy aliases (mapped to logo palette)
  static const Color terracotta = heart;
  static const Color clay = Color(0xFF163A9E);
  static const Color deepPlum = midnight;
  static const Color forestTeal = leafGreen;
  static const Color sunGold = skyBlue;
  static const Color sage = Color(0xFF3D9A6A);
  static const Color peach = ice;
  static const Color surfaceWhite = Color(0xFFF7FBFF);

  // ── Neutrals ────────────────────────────────────────────────────
  static const Color charcoal = Color(0xFF102037);
  static const Color ink = Color(0xFF081018);
  static const Color offWhite = Color(0xFFF4F8FD);
  static const Color surface = Color(0xFFF7FBFF);
  static const Color surfaceMuted = Color(0xFFE7F0FA);
  static const Color surfaceDark = Color(0xFF121C2C);

  static const Color grey100 = Color(0xFFEEF4FB);
  static const Color grey200 = Color(0xFFD7E4F4);
  static const Color grey300 = Color(0xFFB7C9DE);
  static const Color grey400 = Color(0xFF8AA0BB);
  static const Color grey500 = Color(0xFF6B829C);
  static const Color grey600 = Color(0xFF4A6078);
  static const Color grey700 = Color(0xFF2C3D52);

  // ── Semantic ────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color successOnSoft = Color(0xFF166534);

  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color warningOnSoft = Color(0xFF92400E);

  static const Color error = Color(0xFFE11D48);
  static const Color errorSoft = Color(0xFFFFE4E6);
  static const Color errorOnSoft = Color(0xFF9F1239);

  static const Color info = Color(0xFF2563EB);
  static const Color infoSoft = Color(0xFFDBEAFE);
  static const Color infoOnSoft = Color(0xFF1E40AF);

  // Star points (teacher recognition)
  static const Color star = Color(0xFFF5A524);
  static const Color starDeep = Color(0xFFB45309);

  static const Color defaultAccent = primaryBlue;

  static const Color textOnSoftCard = Color(0xFF102037);
  static const Color textMutedOnSoftCard = Color(0xFF4A6078);

  static Color cardGlow(Color accent) => accent.withValues(alpha: 0.18);

  static LinearGradient pageGradient(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF050B14), Color(0xFF0C1A30), Color(0xFF071422)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF7FBFF), Color(0xFFEAF4FF), Color(0xFFF3FBF6)],
    );
  }

  static LinearGradient heroGradient(Color accent) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        midnight,
        Color.lerp(deepNavy, accent, 0.35)!,
        Color.lerp(royalBlue, skyBlue, 0.45)!,
      ],
    );
  }

  static LinearGradient brandSweep({double opacity = 1}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primaryBlue.withValues(alpha: opacity),
        skyBlue.withValues(alpha: opacity),
        leafGreen.withValues(alpha: opacity * 0.9),
      ],
    );
  }
}
