// Parent flows offline: every tab for every child (switching via the shared selection), and the
// "Can't make it?" sheet, at phone and desktop widths. Fails on any build or layout exception.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/router.dart';
import 'package:nuvara/screens/messages.dart' show ChatScreen;
import 'package:nuvara/screens/parent/kit.dart';
import 'package:nuvara/theme.dart';
import 'package:provider/provider.dart';

import 'fixtures.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  const sizes = [Size(360, 740), Size(412, 915), Size(1100, 800)];

  Future<void> settle(WidgetTester t) => t.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));

  List<String> drain(WidgetTester t, String where) => [
    for (Object? e = t.takeException(); e != null; e = t.takeException())
      if (!'$e'.contains('GoogleFonts') && !'$e'.contains('google_fonts')) '$where\n$e',
  ];

  testWidgets('every parent tab renders for every child', (tester) async {
    final store = demoStore(Role.parent);
    final router = buildRouter(store);
    final failures = <String>[];
    for (final size in sizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp.router(theme: buildTheme(), routerConfig: router),
        ),
      );
      for (final c in store.children) {
        selectedChildId.value = c.id;
        for (final p in ['/parent', '/parent/schedule', '/parent/progress', '/parent/fees']) {
          router.go(p);
          await settle(tester);
          failures.addAll(drain(tester, '${size.width.toInt()}px ${c.code} $p'));
        }
      }
    }
    selectedChildId.value = null;
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });

  testWidgets('switching child on one tab carries to the others', (tester) async {
    final store = demoStore(Role.parent);
    final router = buildRouter(store);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp.router(theme: buildTheme(), routerConfig: router),
      ),
    );
    router.go('/parent/fees');
    await settle(tester);
    expect(find.text("Aarav's weekly fees"), findsOneWidget);
    // Aarav attended 9 of 10 speech sessions last week and has money due.
    expect(find.textContaining('Pay '), findsWidgets);
    await tester.tap(find.text('Anaya'));
    await settle(tester);
    expect(find.text("Anaya's weekly fees"), findsOneWidget);
    // Anaya's payment is waiting for the centre to verify it.
    expect(find.textContaining('being verified'), findsWidgets);
    router.go('/parent/schedule');
    await settle(tester);
    expect(find.text("Anaya's sessions, week by week"), findsOneWidget);
    // Anaya has an absence notice on every session in the fixture.
    expect(find.textContaining('Away · '), findsWidgets);
    selectedChildId.value = null;
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });

  testWidgets("can't-make-it sheet renders and enables once a reason is picked", (tester) async {
    final store = demoStore(Role.parent);
    final router = buildRouter(store);
    final failures = <String>[];
    for (final size in sizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp.router(theme: buildTheme(), routerConfig: router),
        ),
      );
      router.go('/parent');
      await settle(tester);
      final ctx = router.routerDelegate.navigatorKey.currentContext!;
      showAwaySheet(ctx, store.sessionById('x0-1')!, store.child('c1')!);
      await settle(tester);
      expect(find.text('Unwell'), findsOneWidget);
      final send = find.widgetWithText(FilledButton, 'Tell the centre');
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      await tester.tap(find.text('Family function'));
      await settle(tester);
      expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
      failures.addAll(drain(tester, '${size.width.toInt()}px sheet'));
      router.routerDelegate.navigatorKey.currentState!.popUntil((r) => r is! PopupRoute);
      await settle(tester);
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
    expect(failures, isEmpty, reason: failures.join('\n\n'));
  });

  testWidgets('home and fees open the chat with the centre', (tester) async {
    final store = demoStore(Role.parent);
    final router = buildRouter(store);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp.router(theme: buildTheme(), routerConfig: router),
      ),
    );
    selectedChildId.value = 'c1';
    router.go('/parent');
    await settle(tester);
    // Aarav's thread has a reply from the centre, shown on the card.
    expect(find.textContaining('we will keep the session gentle'), findsOneWidget);
    await tester.tap(find.textContaining('Message the centre'));
    await settle(tester);
    expect(find.byType(ChatScreen), findsOneWidget);
    router.go('/parent/fees');
    await settle(tester);
    await tester.scrollUntilVisible(find.textContaining('Question about fees?'), 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.textContaining('Question about fees?'));
    await settle(tester);
    await tester.tap(find.textContaining('Question about fees?'), warnIfMissed: false);
    await settle(tester);
    expect(find.byType(ChatScreen), findsOneWidget);
    selectedChildId.value = null;
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });
}
