import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static const List<String> tamilFallback = ['Noto Sans Tamil'];

  static TextStyle _display(Color color) => GoogleFonts.fraunces(
        color: color,
        textStyle: const TextStyle(fontFamilyFallback: tamilFallback),
      );

  static TextStyle _ui(Color color) => GoogleFonts.outfit(
        color: color,
        textStyle: const TextStyle(fontFamilyFallback: tamilFallback),
      );

  static TextTheme textTheme({required Color onSurface, required Color muted}) {
    final display = _display(onSurface);
    final ui = _ui(onSurface);

    return TextTheme(
      displaySmall: display.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
        height: 1.12,
      ),
      headlineLarge: display.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.15,
      ),
      headlineMedium: display.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.2,
      ),
      headlineSmall: display.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.25,
      ),
      titleLarge: ui.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.3,
      ),
      titleMedium: ui.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      titleSmall: ui.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.35,
      ),
      bodyLarge: ui.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodyMedium: ui.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: muted,
      ),
      bodySmall: ui.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: muted,
      ),
      labelLarge: ui.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      labelMedium: ui.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: muted,
      ),
      labelSmall: ui.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: muted,
      ),
    );
  }

  static TextStyle get headingLarge => GoogleFonts.fraunces(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        textStyle: const TextStyle(fontFamilyFallback: tamilFallback),
      );

  static TextStyle get headingMedium => GoogleFonts.fraunces(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        textStyle: const TextStyle(fontFamilyFallback: tamilFallback),
      );

  static TextStyle get headingSmall => GoogleFonts.fraunces(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        textStyle: const TextStyle(fontFamilyFallback: tamilFallback),
      );

  static TextStyle get bodyLarge => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        textStyle: const TextStyle(fontFamilyFallback: tamilFallback),
      );

  static TextStyle get bodyMedium => GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        textStyle: const TextStyle(fontFamilyFallback: tamilFallback),
      );

  static TextStyle get bodySmall => GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        textStyle: const TextStyle(fontFamilyFallback: tamilFallback),
      );

  static TextStyle get labelMedium => GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        textStyle: const TextStyle(fontFamilyFallback: tamilFallback),
      );
}
