import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'core/design_system/app_theme.dart';
import 'core/design_system/app_colors.dart';
import 'core/network/supabase_service.dart';
import 'core/auth/session_provider.dart';
import 'core/localization/locale_provider.dart';
import 'features/splash/splash_screen.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env not bundled — SupabaseService falls back to the demo catalogue.
  }
  try {
    await SupabaseService.initialize()
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    // UI can run without a live backend during design / offline.
  }

  runApp(
    const ProviderScope(
      child: PalliConnectApp(),
    ),
  );
}

class PalliConnectApp extends ConsumerWidget {
  const PalliConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = ref.watch(currentSchoolProvider);
    final locale = ref.watch(localeProvider);
    final schoolAccent = school != null
        ? parseSchoolAccent(school.primaryColorHex, AppColors.defaultAccent)
        : AppColors.defaultAccent;

    return MaterialApp(
      title: 'PalliConnect',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.generate(
        schoolAccent: schoolAccent,
        brightness: Brightness.light,
      ),
      darkTheme: AppTheme.generate(
        schoolAccent: schoolAccent,
        brightness: Brightness.dark,
      ),
      builder: (context, child) {
        // Pages paint the atmosphere themselves (AppPageTransitionsBuilder);
        // this solid fill only guards the frame before the first page.
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return MediaQuery(
          // Clock times read as 12-hour in both apps, whatever the phone's
          // own 24-hour setting says.
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: ColoredBox(
            color: isDark ? AppColors.ink : AppColors.offWhite,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
