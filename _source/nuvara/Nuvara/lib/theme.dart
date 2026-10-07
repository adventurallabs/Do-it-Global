import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Nuvara's palette, from the logo: deep navy for trust and calm, the mark's warm orange for energy and the
/// few things that need attention, and its sky blue for highlights. Status colours stay distinct from the brand.
class C {
  static const canvas = Color(0xFFF5F6FB);
  static const surface = Colors.white;
  static const ink = Color(0xFF0D0E2C);
  static const muted = Color(0xFF62667F);
  static const line = Color(0xFFE5E7F1);
  static const sand = Color(0xFFEDEFF6);

  /// Navy, from the wordmark (#010039), light to dark.
  static const brand50 = Color(0xFFEFF0FA);
  static const brand100 = Color(0xFFDDE0F5);
  static const brand200 = Color(0xFFBAC0EA);
  static const brand300 = Color(0xFF8F98D8);
  static const brand400 = Color(0xFF5E68BE);
  static const brand600 = Color(0xFF262C82);
  static const brand700 = Color(0xFF161A66);
  static const brand800 = Color(0xFF0B0E50);
  static const brand900 = Color(0xFF010039);

  /// The mark's orange (#EA501E).
  static const clay50 = Color(0xFFFFF2EC);
  static const clay100 = Color(0xFFFFDFD0);
  static const clay500 = Color(0xFFEA501E);
  static const clay600 = Color(0xFFC93F12);

  /// The mark's sky blue (#36A9E0).
  static const sky = Color(0xFF36A9E0);
  static const skyBg = Color(0xFFE6F5FC);

  static const green = Color(0xFF107443);
  static const greenBg = Color(0xFFE6F6EE);
  static const amber = Color(0xFFA35A00);
  static const amberBg = Color(0xFFFFF4E0);
  static const red = Color(0xFFC0263D);
  static const redBg = Color(0xFFFDECEF);
  static const blue = Color(0xFF1772B5);
  static const blueBg = Color(0xFFE7F3FC);
  static const violet = Color(0xFF6B3FA0);
  static const violetBg = Color(0xFFF2ECFA);

  /// Shadows are tinted with the navy, never grey.
  static const shadow = Color(0xFF010039);
}

/// The navy-to-indigo gradient behind every hero panel.
const heroGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.brand900, Color(0xFF1B1F7A)]);

/// Headings and big numbers: Archivo, a heavy grotesque that matches the Nuvara wordmark. Light weights
/// passed in are lifted so headings always read as the brand. Body text is Plus Jakarta Sans.
// Every label in the app asks for its style through these two, often hundreds of times per frame on busy
// screens (the timetable grid, long lists). Building a GoogleFonts style also checks whether the font file is
// loaded, so the finished styles are kept and reused: the same arguments always give the same style.
final _styles = <(bool, double, FontWeight, Color, double?), TextStyle>{};

TextStyle _cached((bool, double, FontWeight, Color, double?) key, TextStyle Function() make) {
  final hit = _styles[key];
  if (hit != null) return hit;
  // Colours computed on the fly (alpha blends) could grow this without end; a few thousand styles is plenty.
  if (_styles.length > 4000) _styles.clear();
  return _styles[key] = make();
}

TextStyle display(double size, {FontWeight weight = FontWeight.w500, Color color = C.ink, double? height}) {
  final w = weight.value <= 400 ? FontWeight.w600 : (weight.value <= 500 ? FontWeight.w700 : FontWeight.w800);
  return _cached((true, size, w, color, height), () => GoogleFonts.archivo(fontSize: size, fontWeight: w, color: color, height: height ?? 1.15, letterSpacing: size >= 24 ? -0.6 : -0.2));
}

TextStyle body(double size, {FontWeight weight = FontWeight.w400, Color color = C.ink, double? height}) =>
    _cached((false, size, weight, color, height), () => GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color, height: height));

const tnum = [FontFeature.tabularFigures()];

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.brand900, brightness: Brightness.light).copyWith(
      primary: C.brand800,
      onPrimary: Colors.white,
      secondary: C.clay500,
      surface: C.surface,
      onSurface: C.ink,
      outline: C.line,
      error: C.red,
    ),
    scaffoldBackgroundColor: C.canvas,
    splashFactory: InkSparkle.splashFactory,
  );
  final text = base.textTheme.apply(fontFamily: GoogleFonts.plusJakartaSans().fontFamily, bodyColor: C.ink, displayColor: C.ink);
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  final label = body(14, weight: FontWeight.w600);

  return base.copyWith(
    textTheme: text,
    dividerTheme: const DividerThemeData(color: C.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: C.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: C.ink,
      titleTextStyle: body(15, weight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      hintStyle: body(14, color: C.muted),
      border: border(C.line),
      enabledBorder: border(const Color(0xFF8F94AD)),
      focusedBorder: border(C.brand600, 1.6),
      errorBorder: border(C.red),
      focusedErrorBorder: border(C.red, 1.6),
      errorStyle: body(11.5, weight: FontWeight.w600, color: C.red),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.brand800,
        foregroundColor: Colors.white,
        disabledBackgroundColor: C.sand,
        shape: shape,
        textStyle: label,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        minimumSize: const Size(0, 46),
        elevation: 0,
      ).copyWith(overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.08))),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: C.ink, backgroundColor: Colors.white, side: const BorderSide(color: C.line), shape: shape, textStyle: label, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), minimumSize: const Size(0, 44)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: C.brand700, shape: shape, textStyle: label, minimumSize: const Size(0, 40)),
    ),
    dialogTheme: DialogThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: C.brand900, contentTextStyle: body(14, weight: FontWeight.w500, color: Colors.white), shape: shape, elevation: 6, insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16)),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.clay500, linearTrackColor: C.sand),
    floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: C.brand800, foregroundColor: Colors.white, elevation: 3, highlightElevation: 6, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: C.clay50,
      height: 70,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => body(11.5, weight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600, color: s.contains(WidgetState.selected) ? C.brand900 : C.muted)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? C.clay500 : C.muted)),
    ),
    sliderTheme: base.sliderTheme.copyWith(activeTrackColor: C.brand600, thumbColor: C.brand700, inactiveTrackColor: C.sand, overlayColor: C.brand100),
    datePickerTheme: const DatePickerThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
    timePickerTheme: const TimePickerThemeData(backgroundColor: Colors.white),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : C.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.brand700 : C.sand),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.brand700 : C.line),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: Color(0xFFC5C9DB), width: 1.6),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.brand700 : Colors.white),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    }),
    popupMenuTheme: PopupMenuThemeData(color: Colors.white, surfaceTintColor: Colors.transparent, shape: shape),
  );
}
