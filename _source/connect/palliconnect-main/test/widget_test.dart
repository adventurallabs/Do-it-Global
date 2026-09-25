import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palliconnect/core/design_system/app_theme.dart';
import 'package:palliconnect/core/design_system/app_colors.dart';
import 'package:palliconnect/core/design_system/brand_atmosphere.dart';
import 'package:palliconnect/features/auth/auth_gate.dart';
import 'package:palliconnect/l10n/app_localizations.dart';

void main() {
  testWidgets('AuthGate shows the login screen when signed out', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.generate(
            schoolAccent: AppColors.defaultAccent,
            brightness: Brightness.light,
          ),
          builder: (context, child) => BrandAtmosphere(child: child ?? const SizedBox.shrink()),
          home: const AuthGate(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No session (Supabase isn't initialised in this test) -> real login UI,
    // never demo/placeholder data.
    expect(find.text('Parent login'), findsOneWidget);
    expect(find.text('Register number'), findsOneWidget);
  });
}
