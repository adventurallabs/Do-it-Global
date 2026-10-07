// Plays the splash intro at small and large phone sizes, plus the offline (retry) state. Fails on any
// build or layout exception.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/screens/splash.dart';
import 'package:nuvara/theme.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final size in const [Size(320, 568), Size(360, 740), Size(412, 915), Size(740, 360)]) {
    for (final offline in [false, true]) {
      testWidgets('splash ${size.width.toInt()}x${size.height.toInt()}${offline ? ' offline' : ''}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var retried = false;
        await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: SplashScreen(offline: offline, onRetry: () => retried = true, onSignOut: () {})));
        // Step through the intro (the breathing loop never settles, so pump by time).
        for (var ms = 0; ms <= SplashScreen.intro.inMilliseconds + 400; ms += 100) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        for (Object? e = tester.takeException(); e != null; e = tester.takeException()) {
          if (!'$e'.contains('GoogleFonts') && !'$e'.contains('google_fonts')) fail('$e');
        }
        expect(find.bySemanticsLabel('Nuvara'), findsWidgets);
        if (offline) {
          await tester.tap(find.text('Try again'));
          expect(retried, isTrue);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
