import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/router.dart';
import 'package:nuvara/theme.dart';
import 'package:nuvara/widgets/ui.dart';
import 'package:provider/provider.dart';

import 'fixtures.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  late BuildContext page;
  Future<void> host(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: Builder(builder: (c) {
        page = c;
        return const SizedBox.expand();
      })),
    ));
  }

  Widget sheet({List<Widget>? footer, double height = 300}) => SheetBody(
        title: 'Request another slot',
        footer: footer ?? [btn('Cancel', onPressed: () {}), ActionButton('Send request', onPressed: () async => throw Exception('Already asked'))],
        child: SizedBox(height: height),
      );

  for (final size in const [Size(360, 740), Size(1280, 800)]) {
    testWidgets('an error raised in a sheet shows above it at ${size.width}', (tester) async {
      await host(tester, size);
      showSheet(page, builder: (_) => sheet());
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(SheetBody));
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(find.text('Already asked'), findsOneWidget);
      final bar = tester.getRect(find.byType(SnackBar));
      expect(tester.getRect(find.byType(SheetBody)), before, reason: 'the sheet keeps its size');
      if (size.width < 900) expect(bar.overlaps(before), isFalse, reason: 'snackbar $bar under the sheet $before');
      // A tap on the SnackBar stays on it; the sheet's buttons and barrier still take taps everywhere else.
      final inSnack = {for (final e in find.descendant(of: find.byType(SnackBar), matching: find.byWidgetPredicate((_) => true)).evaluate()) e.renderObject};
      expect(tester.hitTestOnBinding(bar.center).path.any((h) => inSnack.contains(h.target)), isTrue);
      await tester.tap(find.text('Cancel'));
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(SheetBody), findsNothing, reason: 'the barrier still closes the sheet');
    });
  }

  testWidgets('a tall sheet shows its SnackBar over its foot', (tester) async {
    await host(tester, const Size(360, 640));
    showSheet(page, builder: (_) => sheet(height: 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(SnackBar));
    expect(bar.bottom, lessThanOrEqualTo(640));
    expect(bar.top, greaterThan(400));
  });

  testWidgets('a message raised as the sheet closes shows on the page', (tester) async {
    await host(tester, const Size(360, 740));
    showSheet(page, builder: (c) => sheet(footer: [
          ActionButton('Save', onPressed: () async {
            Navigator.pop(c);
            return 'Saved';
          }),
        ]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(SheetBody), findsNothing);
    expect(find.text('Saved'), findsOneWidget);
    // toast() from the closed sheet's context lands on the page too.
    showSheet(page, builder: (c) => sheet(footer: [
          btn('Done', onPressed: () {
            Navigator.pop(c);
            toast(c, 'Done it');
          }),
        ]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Done it'), findsOneWidget);
  });

  for (final width in const [320.0, 360.0, 412.0]) {
    testWidgets('two-button footer labels fit at $width', (tester) async {
      await host(tester, Size(width, 740));
      showSheet(page, builder: (_) => sheet(footer: [btn("No, I didn't pay", onPressed: () {}), ActionButton('Yes, I paid', icon: Icons.check_rounded, onPressed: () async => null)]));
      await tester.pumpAndSettle();
      for (final label in ["No, I didn't pay", 'Yes, I paid']) {
        final p = tester.renderObject<RenderParagraph>(find.descendant(of: find.text(label), matching: find.byType(RichText)).first);
        expect(p.didExceedMaxLines, isFalse, reason: '"$label" cut off at $width');
      }
      final no = tester.getRect(find.text("No, I didn't pay")), yes = tester.getRect(find.text('Yes, I paid'));
      // The primary stays right of, or below, the other button.
      expect(yes.left > no.right || yes.top > no.bottom, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('short labels share the footer equally', (tester) async {
    await host(tester, const Size(412, 740));
    showSheet(page, builder: (_) => sheet(footer: [btn('Cancel', onPressed: () {}), btn('Save', kind: 'filled', onPressed: () {})]));
    await tester.pumpAndSettle();
    final a = tester.getSize(find.byType(OutlinedButton)), b = tester.getSize(find.byType(FilledButton));
    expect(a.width, b.width);
    expect(tester.getRect(find.byType(OutlinedButton)).top, tester.getRect(find.byType(FilledButton)).top);
  });

  testWidgets('segmented control and toggle pills are 44px touch targets', (tester) async {
    await host(tester, const Size(360, 740));
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: Column(children: [
          Segmented<int>(value: 0, options: [seg(0, 'Week'), seg(1, 'Month')], onChanged: (_) {}),
          Wrap(children: [TogglePill('OT', active: true, onTap: () {}), TogglePill('Speech', active: false, onTap: () {})]),
        ]),
      ),
    ));
    final segment = find.ancestor(of: find.text('Week'), matching: find.byType(AnimatedContainer)).first;
    expect(tester.getSize(segment).height, 44);
    for (final t in ['OT', 'Speech']) {
      expect(tester.getSize(find.ancestor(of: find.text(t), matching: find.byType(AnimatedContainer)).first).height, greaterThanOrEqualTo(44));
    }
    expect(tester.getSemantics(find.text('OT')), isSemantics(isButton: true, isSelected: true));
  });

  // A phone on its side is wide but short: a side rail can't fit five tabs there, so it keeps the bottom bar.
  for (final (size, rail) in const [(Size(844, 390), false), (Size(1280, 800), true), (Size(900, 500), true)]) {
    testWidgets('shell navigation at ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = demoStore(Role.parent);
      final router = buildRouter(store);
      await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
      router.go('/parent');
      await tester.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      expect(find.byType(NavigationRail), rail ? findsOneWidget : findsNothing);
      expect(find.byType(NavigationBar), rail ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
