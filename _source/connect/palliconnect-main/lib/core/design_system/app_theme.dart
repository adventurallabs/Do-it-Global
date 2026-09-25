import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';
import 'app_page_transitions.dart';

class AppTheme {
  static ThemeData generate({
    required Color schoolAccent,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final onSurface = isDark ? const Color(0xFFEAF2FF) : AppColors.charcoal;
    final muted = isDark ? AppColors.grey400 : AppColors.grey600;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surface;
    final cardBorder = isDark
        ? AppColors.skyBlue.withValues(alpha: 0.18)
        : AppColors.primaryBlue.withValues(alpha: 0.10);
    final primary = AppColors.primaryBlue;
    final secondary = AppColors.leafGreen;

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      secondary: secondary,
      tertiary: schoolAccent,
      surface: surface,
    ).copyWith(
      onSurface: onSurface,
      error: AppColors.error,
      primaryContainer: isDark ? const Color(0xFF163A7A) : AppColors.ice,
      secondaryContainer: isDark ? const Color(0xFF163A2A) : AppColors.successSoft,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primary,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      pageTransitionsTheme: appPageTransitions,
      textTheme: AppTypography.textTheme(onSurface: onSurface, muted: muted),
      cardTheme: CardThemeData(
        color: surface.withValues(alpha: isDark ? 0.72 : 0.82),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: cardBorder, width: 1),
        ),
        shadowColor: AppColors.primaryBlue.withValues(alpha: 0.12),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: onSurface,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: AppTypography.headingSmall.copyWith(color: onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: (isDark ? AppColors.surfaceDark : Colors.white)
            .withValues(alpha: 0.78),
        elevation: 0,
        height: 72,
        indicatorColor: Colors.transparent,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryBlue, size: 24);
          }
          return IconThemeData(color: muted, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlue,
              letterSpacing: 0.2,
            );
          }
          return AppTypography.labelMedium.copyWith(color: muted);
        }),
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primary,
        unselectedItemColor: muted,
        selectedLabelStyle: AppTypography.labelMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        unselectedLabelStyle: AppTypography.labelMedium,
      ),
      dividerColor: cardBorder,
      dividerTheme: DividerThemeData(
        color: cardBorder,
        thickness: 1,
        space: 24,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.midnight,
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: onSurface,
      ),
      iconTheme: IconThemeData(color: muted, size: 24),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return muted;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceDark.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.7),
        hintStyle: AppTypography.bodyMedium.copyWith(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.4),
        ),
      ),
    );
  }
}
