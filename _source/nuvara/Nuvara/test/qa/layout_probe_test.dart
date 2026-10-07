// QA layout probe: hunts for content hidden under the system navigation bar, FABs, the bottom
// NavigationBar or the keyboard; overflow at large text sizes; small / unlabelled tap targets; and
// SnackBars hidden behind sheets.
//
// Findings are printed with a [LAYOUT] prefix. By default the probe only reports; run with
// `flutter test test/qa/layout_probe_test.dart --dart-define=QA_STRICT=true` to make findings fail.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/models.dart';
import 'package:nuvara/router.dart';
import 'package:nuvara/screens/admin/fees.dart';
import 'package:nuvara/screens/admin/sessions.dart';
import 'package:nuvara/screens/admin/therapies.dart';
import 'package:nuvara/screens/admin/timetable.dart';
import 'package:nuvara/screens/parent/kit.dart';
import 'package:nuvara/screens/parent/reschedule.dart';
import 'package:nuvara/store.dart';
import 'package:nuvara/theme.dart';
import 'package:nuvara/util.dart';
import 'package:nuvara/widgets/account.dart';
import 'package:nuvara/widgets/credentials.dart';
import 'package:nuvara/widgets/ui.dart';
import 'package:provider/provider.dart';

import '../fixtures.dart';

const strict = bool.fromEnvironment('QA_STRICT');
const askNoteProbe = bool.fromEnvironment('QA_ASKNOTE');
const navInset = 48.0; // 3-button Android navigation bar, edge-to-edge.

void report(String probe, List<String> findings) {
  final unique = findings.toSet().toList();
  // ignore: avoid_print
  print('[LAYOUT] $probe: ${unique.isEmpty ? 'OK' : '${unique.length} finding(s)'}');
  for (final f in unique) {
    // ignore: avoid_print
    print('[LAYOUT]   - $f');
  }
  if (strict) expect(unique, isEmpty, reason: unique.join('\n'));
}

Future<GoRouter> boot(WidgetTester tester, AppStore store, Size size, {double inset = 0, double keyboard = 0, double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = FakeViewPadding(bottom: inset);
  // As on Android: while the keyboard is up it covers the navigation bar, so padding.bottom drops to 0.
  tester.view.padding = FakeViewPadding(bottom: keyboard > 0 ? 0 : inset);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  _hook();
  final router = buildRouter(store);
  await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
  await settle(tester);
  return router;
}

Future<void> teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  tester.view.reset();
  tester.platformDispatcher.clearTextScaleFactorTestValue();
  _unhook();
  _sites.clear();
}

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));

/// Layout exceptions thrown since the last call, as "message @ widget location".
/// Error-causing widget locations in lib/ captured from FlutterError details since the last [errors] call.
final _sites = <String>[];
void Function(FlutterErrorDetails)? _orig;
void _hook() {
  if (_orig != null) return;
  _orig = FlutterError.onError;
  FlutterError.onError = (d) {
    final m = RegExp(r'(\w+):file:///[^\s]*?/lib/([^\s]+)').firstMatch(d.toString());
    if (m != null) _sites.add("${m.group(1)} lib/${m.group(2)}");
    _orig!(d);
  };
}

void _unhook() {
  if (_orig == null) return;
  FlutterError.onError = _orig;
  _orig = null;
}

List<String> errors(WidgetTester tester, String where) {
  final out = <String>[];
  final sites = _sites.toSet().join(", ");
  _sites.clear();
  for (Object? e = tester.takeException(); e != null; e = tester.takeException()) {
    final msg = '$e';
    if (msg.contains('GoogleFonts') || msg.contains('google_fonts')) continue;
    final first = msg.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => msg).trim();
    out.add('$where: $first${sites.isEmpty ? '' : '  [at $sites]'}');
  }
  return out;
}

Rect globalRect(RenderBox b) => MatrixUtils.transformRect(b.getTransformTo(null), Offset.zero & b.size);

/// The part of [box] actually visible after clipping by every enclosing scroll viewport.
Rect? visibleRect(RenderBox box) {
  var r = globalRect(box);
  RenderObject? p = box.parent;
  while (p != null) {
    if (p is RenderBox && p is RenderAbstractViewport) {
      r = r.intersect(globalRect(p));
      if (r.width <= 0 || r.height <= 0) return null;
    }
    p = p.parent;
  }
  return r;
}

/// Scrolls every vertical list inside [scope] to its far end (the bottom of a normal list, the top of a reversed one).
Future<void> scrollToEnd(WidgetTester tester, Finder scope) async {
  for (var pass = 0; pass < 4; pass++) {
    for (final e in find.descendant(of: scope, matching: find.byType(Scrollable)).evaluate()) {
      final s = (e as StatefulElement).state as ScrollableState;
      final pos = s.position;
      if (!pos.hasContentDimensions) continue;
      if (s.axisDirection == AxisDirection.down) pos.jumpTo(pos.maxScrollExtent);
      if (s.axisDirection == AxisDirection.up) pos.jumpTo(pos.minScrollExtent);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }
}

String textOf(Element e) {
  final t = (e.widget as RichText).text.toPlainText().replaceAll('\n', ' ');
  if (t.runes.length == 1 && t.runes.first >= 0xE000) return '<icon>';
  return t.length > 40 ? '${t.substring(0, 40)}…' : t;
}

/// Visible text inside [scope] that sits under the system navigation bar, a FAB or the bottom NavigationBar.
List<String> hiddenText(WidgetTester tester, String where, Finder scope, Size size, double inset, {bool pageChrome = true}) {
  final obstacles = <(String, Rect)>[
    if (inset > 0) ('system nav bar', Rect.fromLTWH(0, size.height - inset, size.width, inset)),
    if (pageChrome) ...[
      for (final e in find.byType(FloatingActionButton).evaluate()) ('FAB', globalRect(e.renderObject! as RenderBox)),
      for (final e in find.byType(NavigationBar).evaluate()) ('NavigationBar', globalRect(e.renderObject! as RenderBox)),
    ],
  ];
  final own = <Element>{
    for (final f in [find.byType(FloatingActionButton), find.byType(NavigationBar)]) ...find.descendant(of: f, matching: find.byType(RichText)).evaluate(),
  };
  final out = <String>[];
  for (final e in find.descendant(of: scope, matching: find.byType(RichText)).evaluate()) {
    if (own.contains(e)) continue;
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.hasSize || ro.size.isEmpty) continue;
    final r = visibleRect(ro);
    if (r == null) continue;
    for (final (name, o) in obstacles) {
      final i = r.intersect(o);
      if (i.width > 1 && i.height > 2) {
        out.add('$where: "${textOf(e)}" is under the $name (text bottom ${r.bottom.toInt()}, $name top ${o.top.toInt()})');
        break;
      }
    }
  }
  return out;
}

const adminPages = [
  '/admin', '/admin/timetable', '/admin/children', '/admin/children/c1', '/admin/children/new', '/admin/children/c1/edit', '/admin/therapists', '/admin/therapists/t1',
  '/admin/therapists/new', '/admin/fees', '/admin/fees/c1', '/admin/fees/upi', '/admin/fees/verify', '/admin/requests', '/admin/therapies', '/admin/reports', '/admin/messages',
  '/admin/messages/parents', '/admin/messages/c1', '/password',
];
const therapistPages = ['/therapist', '/therapist/week', '/therapist/children', '/therapist/children/c1', '/therapist/messages', '/therapist/sessions/x0-2'];
const parentPages = ['/parent', '/parent/schedule', '/parent/progress', '/parent/fees', '/parent/messages', '/parent/messages/c1'];

Map<Role, List<String>> pagesByRole(String monday) => {
      Role.admin: [...adminPages, '/admin/timetable/$monday', '/admin/timetable/$monday?view=day'],
      Role.therapist: therapistPages,
      Role.parent: parentPages,
    };

Map<String, Future<void> Function(BuildContext, AppStore)> adminSheets(String monday) => {
      'slot sheet': (c, s) => showSlotSheet(c, 's0-a'),
      'session sheet': (c, s) => showSessionSheet(c, 'x0-1'),
      'new session form': (c, s) => showSessionForm(c, date: monday, start: '09:30', end: '10:15'),
      'edit session form': (c, s) => showSessionForm(c, date: monday, start: '09:30', end: '10:15', sessionId: 'x0-1'),
      'new slot form': (c, s) => showSlotForm(c, monday: monday),
      'week picker': (c, s) => showWeekPicker(c, initial: monday),
      'therapy sheet': (c, s) => showTherapySheet(c, therapy: s.therapies.first),
      'payment sheet': (c, s) => showPaymentSheet(c, s.child('c1')!, s.bill('c1', addDays(monday, -7))!),
      'collect sheet': (c, s) => showCollectSheet(c, s.child('c1')!),
      'upi sheet': (c, s) => showUpiSheet(c, account: s.upiAccounts.first),
      'account sheet': (c, s) => showAccountSheet(c),
      'login details dialog': (c, s) => showLoginDetails(c, title: 'Login created', message: 'Share these with the family.', loginLabel: "Child's ID", loginId: 'C001', password: 'Nuvara@1234'),
    };

Map<String, Future<void> Function(BuildContext, AppStore)> parentSheets(String monday) => {
      'reschedule sheet': (c, s) => showRescheduleSheet(c, s.sessionsOfChild('c1', monday).first, s.child('c1')!),
      'away sheet': (c, s) => showAwaySheet(c, s.sessionsOfChild('c1', monday).first, s.child('c1')!),
      'account sheet': (c, s) => showAccountSheet(c),
      'add child sheet': (c, s) => showSheet(c, builder: (_) => const AddChildSheet()),
    };

Finder sheetScope() => find.byWidgetPredicate((w) => w is BottomSheet || w is Dialog);

Future<BuildContext> rootContext(WidgetTester tester, GoRouter router, String path) async {
  router.go(path);
  await settle(tester);
  return router.routerDelegate.navigatorKey.currentContext!;
}

Future<void> closeAll(WidgetTester tester, GoRouter router) async {
  router.routerDelegate.navigatorKey.currentState!.popUntil((r) => r is! PopupRoute);
  await settle(tester);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final monday = weekStart(todayISO());

  // ---------------------------------------------------------------------------------------------
  // 1. Every page, scrolled to the end, with a 48px navigation bar: is any text left under the
  //    system bar, a FAB or the bottom NavigationBar?
  for (final size in const [Size(360, 740), Size(412, 915), Size(800, 1280), Size(1280, 800)]) {
    testWidgets('pages clear the nav bar / FAB / NavigationBar at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      final findings = <String>[];
      for (final MapEntry(key: role, value: pages) in pagesByRole(monday).entries) {
        final store = demoStore(role);
        final router = await boot(tester, store, size, inset: navInset);
        for (final p in pages) {
          router.go(p);
          await settle(tester);
          await scrollToEnd(tester, find.byType(Navigator).first);
          findings
            ..addAll(hiddenText(tester, p, find.byType(Navigator).first, size, navInset))
            ..addAll(errors(tester, p));
        }
        await teardown(tester);
      }
      report('pages @${size.width.toInt()}x${size.height.toInt()} inset $navInset', findings);
    });
  }

  // ---------------------------------------------------------------------------------------------
  // 2. Every sheet / dialog, scrolled to the end, with a 48px navigation bar.
  for (final size in const [Size(360, 640), Size(412, 915), Size(1280, 800)]) {
    testWidgets('sheets clear the nav bar at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      final findings = <String>[];
      Future<void> run(Role role, Map<String, Future<void> Function(BuildContext, AppStore)> sheets) async {
        final store = demoStore(role);
        final router = await boot(tester, store, size, inset: navInset);
        for (final e in sheets.entries) {
          final ctx = await rootContext(tester, router, role.home);
          e.value(ctx, store);
          await settle(tester);
          await scrollToEnd(tester, sheetScope());
          findings
            ..addAll(hiddenText(tester, e.key, sheetScope(), size, navInset, pageChrome: false))
            ..addAll(errors(tester, e.key));
          await closeAll(tester, router);
        }
        // The pickers opened from the session form (the reported bug).
        if (role == Role.admin) {
          for (final (label, field) in const [('therapist picker', 'Select a therapist'), ('children picker', 'Select children')]) {
            final ctx = await rootContext(tester, router, role.home);
            showSessionForm(ctx, date: monday, start: '09:30', end: '10:15');
            await settle(tester);
            await tester.ensureVisible(find.text(field));
            await tester.tap(find.text(field));
            await settle(tester);
            await scrollToEnd(tester, sheetScope().last);
            findings
              ..addAll(hiddenText(tester, label, sheetScope().last, size, navInset, pageChrome: false))
              ..addAll(errors(tester, label));
            await closeAll(tester, router);
          }
        }
        await teardown(tester);
      }

      await run(Role.admin, adminSheets(monday));
      await run(Role.parent, parentSheets(monday));
      report('sheets @${size.width.toInt()}x${size.height.toInt()} inset $navInset', findings);
    });
  }

  // ---------------------------------------------------------------------------------------------
  // 3. Keyboard: with a 320px keyboard up, is each focused field (and the chat composer) above it?
  testWidgets('keyboard never covers the focused field', (tester) async {
    const size = Size(360, 740), kb = 320.0;
    final findings = <String>[];
    Future<void> checkFields(String where) async {
      final fields = find.byType(EditableText).evaluate().toList();
      for (var i = 0; i < fields.length; i++) {
        final f = find.byType(EditableText).at(i);
        if (i >= find.byType(EditableText).evaluate().length) break;
        final label = (f.evaluate().first.widget as EditableText).controller.text;
        await tester.showKeyboard(f);
        await settle(tester);
        final focused = find.byWidgetPredicate((w) => w is EditableText && w.focusNode.hasFocus).evaluate();
        if (focused.isEmpty) continue;
        final box = focused.first.renderObject! as RenderBox;
        final r = visibleRect(box);
        final full = globalRect(box);
        if (r == null || r.height < full.height * 0.8 || full.bottom > size.height - kb + 1) {
          findings.add('$where: field #$i ("$label") not fully visible above the keyboard (field ${full.top.toInt()}-${full.bottom.toInt()}, keyboard top ${(size.height - kb).toInt()})');
        }
      }
      findings.addAll(errors(tester, where));
    }

    // Pages with forms or a composer.
    for (final (role, pages) in [
      (Role.admin, ['/admin/children/new', '/admin/therapists/new', '/admin/messages/c1', '/password', '/admin/children']),
      (Role.parent, ['/parent/messages', '/parent/messages/c1']),
      (Role.therapist, ['/therapist/messages', '/therapist/sessions/x0-2']),
    ]) {
      final store = demoStore(role);
      final router = await boot(tester, store, size, inset: navInset, keyboard: kb);
      for (final p in pages) {
        router.go(p);
        await settle(tester);
        await checkFields(p);
      }
      // Sheets with text fields.
      if (role == Role.admin) {
        for (final name in ['new session form', 'upi sheet', 'payment sheet', 'therapy sheet']) {
          final ctx = await rootContext(tester, router, '/admin');
          adminSheets(monday)[name]!(ctx, store);
          await settle(tester);
          await checkFields(name);
          // The sheet's primary action (last button in the footer) should stay reachable above the keyboard.
          final buttons = find.descendant(of: find.byWidgetPredicate((w) => w is BottomSheet || w is Dialog || w is AlertDialog), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
          if (buttons.evaluate().isNotEmpty) {
            final r = globalRect(buttons.last.evaluate().first.renderObject! as RenderBox);
            if (r.bottom > size.height - kb + 1) findings.add('$name: primary action is behind the keyboard (button bottom ${r.bottom.toInt()}, keyboard top ${(size.height - kb).toInt()})');
          }
          await closeAll(tester, router);
        }
      }
      if (role == Role.parent) {
        final ctx = await rootContext(tester, router, '/parent');
        parentSheets(monday)['away sheet']!(ctx, store);
        await settle(tester);
        await checkFields('away sheet');
        await closeAll(tester, router);
      }
      await teardown(tester);
    }

    // Login and the admin sign-up sheet.
    final store = demoStore(Role.admin)..role = null;
    final router = await boot(tester, store, size, inset: navInset, keyboard: kb);
    router.go('/login');
    await settle(tester);
    await checkFields('/login');
    await tester.tap(find.text('Admin'));
    await settle(tester);
    await tester.ensureVisible(find.text('New admin? Create your account'));
    await tester.tap(find.text('New admin? Create your account'));
    await settle(tester);
    await checkFields('admin sign-up sheet');
    await teardown(tester);
    report('keyboard 320px @360x740', findings);
  });

  // ---------------------------------------------------------------------------------------------
  // 4. Large text: overflow at 1.3x and 2.0x on a small phone, pages and sheets.
  for (final scale in const [1.3, 2.0]) {
    testWidgets('text scale ${scale}x on 360x740', (tester) async {
      const size = Size(360, 740);
      final findings = <String>[];
      for (final MapEntry(key: role, value: pages) in pagesByRole(monday).entries) {
        final store = demoStore(role);
        final router = await boot(tester, store, size, inset: navInset, scale: scale);
        for (final p in pages) {
          router.go(p);
          await settle(tester);
          findings.addAll(errors(tester, p));
        }
        final sheets = role == Role.admin ? adminSheets(monday) : (role == Role.parent ? parentSheets(monday) : <String, Future<void> Function(BuildContext, AppStore)>{'account sheet': (c, s) => showAccountSheet(c)});
        for (final e in sheets.entries) {
          final ctx = await rootContext(tester, router, role.home);
          e.value(ctx, store);
          await settle(tester);
          await scrollToEnd(tester, sheetScope());
          findings.addAll(errors(tester, '${role.name} ${e.key}'));
          await closeAll(tester, router);
        }
        await teardown(tester);
      }
      report('text scale ${scale}x', findings);
    });
  }

  // ---------------------------------------------------------------------------------------------
  // 5. Wide dialogs on a short landscape window (phone landscape is >= 900 wide, so showSheet uses a dialog).
  testWidgets('dialogs on short landscape windows', (tester) async {
    final findings = <String>[];
    for (final (size, scale) in const [(Size(844, 390), 1.0), (Size(915, 412), 1.0), (Size(915, 412), 1.3), (Size(1024, 600), 2.0)]) {
      final store = demoStore(Role.admin);
      final router = await boot(tester, store, size, scale: scale);
      for (final e in adminSheets(monday).entries) {
        final ctx = await rootContext(tester, router, '/admin');
        e.value(ctx, store);
        await settle(tester);
        final where = '${e.key} @${size.width.toInt()}x${size.height.toInt()} ${scale}x';
        findings.addAll(errors(tester, where));
        // Header + footer must leave room for the body to show something.
        final scrolls = find.descendant(of: sheetScope(), matching: find.byType(Scrollable)).evaluate().map((x) => (x.renderObject as RenderBox?)?.size.height ?? 0).where((h) => h > 0);
        if (scrolls.isNotEmpty) {
          final tallest = scrolls.reduce((a, b) => a > b ? a : b);
          if (tallest < 120) findings.add('$where: body scroll area only ${tallest.toInt()}px tall');
        }
        await closeAll(tester, router);
      }
      await teardown(tester);
    }
    report('wide dialogs on short windows', findings);
  });

  // ---------------------------------------------------------------------------------------------
  // 6. Extra blank space: SheetBody inside a centred dialog still adds the system bottom inset.
  testWidgets('dialog on a tablet with a nav bar does not pad for the nav bar', (tester) async {
    const size = Size(1280, 800);
    final findings = <String>[];
    final heights = <String, List<double>>{};
    for (final inset in const [0.0, navInset]) {
      final store = demoStore(Role.admin);
      final router = await boot(tester, store, size, inset: inset);
      for (final name in ['therapy sheet', 'week picker', 'account sheet', 'upi sheet']) {
        final ctx = await rootContext(tester, router, '/admin');
        adminSheets(monday)[name]!(ctx, store);
        await settle(tester);
        final m = find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first;
        heights.putIfAbsent(name, () => []).add(globalRect(m.evaluate().first.renderObject! as RenderBox).height);
        await closeAll(tester, router);
      }
      await teardown(tester);
    }
    for (final MapEntry(key: name, value: h) in heights.entries) {
      final extra = h[1] - h[0];
      if (extra > 1) findings.add('$name: the centred dialog grows ${extra.toInt()}px taller (${h[0].toInt()} -> ${h[1].toInt()}) when the device reports a ${navInset.toInt()}px nav bar, which a centred dialog never touches');
    }
    report('dialog bottom inset', findings);
  });

  // ---------------------------------------------------------------------------------------------
  // 7. SnackBars raised from inside a sheet: are they visible?
  testWidgets('a toast raised from a sheet is visible', (tester) async {
    const size = Size(412, 915);
    final findings = <String>[];
    final store = demoStore(Role.admin)..role = null;
    final router = await boot(tester, store, size, inset: navInset);
    router.go('/login');
    await settle(tester);
    await tester.tap(find.text('Admin'));
    await settle(tester);
    await tester.ensureVisible(find.text('New admin? Create your account'));
    await tester.tap(find.text('New admin? Create your account'));
    await settle(tester);
    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final snack = find.byType(SnackBar);
    if (snack.evaluate().isEmpty) {
      findings.add('no SnackBar raised');
    } else {
      final r = globalRect(snack.evaluate().first.renderObject! as RenderBox);
      final sheet = globalRect(find.byType(BottomSheet).evaluate().first.renderObject! as RenderBox);
      final hit = tester.hitTestOnBinding(r.center);
      final inSnack = {for (final e in find.descendant(of: snack, matching: find.byWidgetPredicate((_) => true)).evaluate()) e.renderObject};
      final reached = hit.path.any((h) => inSnack.contains(h.target));
      if (!reached && r.overlaps(sheet)) {
        findings.add('admin sign-up: "Please fix the highlighted fields." SnackBar (y ${r.top.toInt()}-${r.bottom.toInt()}) is painted under the modal sheet (y ${sheet.top.toInt()}-${sheet.bottom.toInt()}); a tap at its centre hits the sheet');
      }
    }
    findings.addAll(errors(tester, 'snackbar'));
    await teardown(tester);
    report('toast from a sheet', findings);
  });

  // ---------------------------------------------------------------------------------------------
  // 8. Accessibility guidelines on every page: 48x48 tap targets, labelled tap targets, text contrast.
  testWidgets('tap targets and labels', (tester) async {
    const size = Size(412, 915);
    final findings = <String>[];
    final handle = tester.ensureSemantics();
    for (final MapEntry(key: role, value: pages) in pagesByRole(monday).entries) {
      final store = demoStore(role);
      final router = await boot(tester, store, size);
      for (final p in pages) {
        router.go(p);
        await settle(tester);
        for (final g in [androidTapTargetGuideline, labeledTapTargetGuideline]) {
          final ev = await g.evaluate(tester);
          if (!ev.passed) {
            for (final line in ev.reason!.split('\n').where((l) => l.trim().isNotEmpty)) {
              findings.add('$p [${g.description.split(' ').take(3).join(' ')}] ${line.length > 220 ? '${line.substring(0, 220)}…' : line}');
            }
          }
        }
        errors(tester, p);
      }
      await teardown(tester);
    }
    handle.dispose();
    report('tap targets (48x48) and labels @412x915', findings);
  });

  testWidgets('text contrast', (tester) async {
    const size = Size(412, 915);
    final findings = <String>[];
    final handle = tester.ensureSemantics();
    for (final MapEntry(key: role, value: pages) in pagesByRole(monday).entries) {
      final store = demoStore(role);
      final router = await boot(tester, store, size);
      for (final p in pages) {
        router.go(p);
        await settle(tester);
        final ev = await textContrastGuideline.evaluate(tester);
        if (!ev.passed) {
          for (final line in ev.reason!.split('\n').where((l) => l.trim().isNotEmpty)) {
            findings.add('$p ${line.length > 200 ? '${line.substring(0, 200)}…' : line}');
          }
        }
        errors(tester, p);
      }
      await teardown(tester);
    }
    handle.dispose();
    report('text contrast (WCAG AA) @412x915', findings);
  });

  // ---------------------------------------------------------------------------------------------
  // Self-check: the detector must flag the therapist picker when the app is NOT told about the nav bar.
  testWidgets('probe self-check: detector catches an unpadded list', (tester) async {
    const size = Size(412, 915);
    final store = demoStore(Role.admin);
    final router = await boot(tester, store, size); // no inset reported to the app
    final ctx = await rootContext(tester, router, '/admin');
    showSessionForm(ctx, date: monday, start: '09:30', end: '10:15');
    await settle(tester);
    await tester.tap(find.text('Select a therapist'));
    await settle(tester);
    await scrollToEnd(tester, sheetScope().last);
    final f = hiddenText(tester, 'self-check', sheetScope().last, size, navInset, pageChrome: false);
    // ignore: avoid_print
    print('[LAYOUT] self-check flagged ${f.length} text(s) under a 48px bar when the app ignores it: ${f.take(2).join(' | ')}');
    expect(f, isNotEmpty);
    await teardown(tester);
  });

  // ---------------------------------------------------------------------------------------------
  // 8a. Icon-only controls that only become tappable after input: chat send, password eye in sign-up.
  testWidgets('icon-only controls are labelled', (tester) async {
    const size = Size(412, 915);
    final findings = <String>[];
    final handle = tester.ensureSemantics();
    final store = demoStore(Role.parent);
    final router = await boot(tester, store, size);
    router.go('/parent/messages/c1');
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Hello');
    await settle(tester);
    final send = find.byIcon(Icons.send_rounded);
    final node = tester.getSemantics(send);
    if ((node.label).trim().isEmpty && (node.tooltip).trim().isEmpty) findings.add('chat composer send button (messages.dart _Composer) has no semantic label or tooltip: "${node.label}"');
    final ev = await labeledTapTargetGuideline.evaluate(tester);
    if (!ev.passed) findings.add('/parent/messages/c1 with text typed: ${ev.reason!.split('\n').first}');
    await teardown(tester);

    final s2 = demoStore(Role.admin)..role = null;
    final r2 = await boot(tester, s2, size);
    r2.go('/login');
    await settle(tester);
    await tester.tap(find.text('Admin'));
    await settle(tester);
    await tester.ensureVisible(find.text('New admin? Create your account'));
    await tester.tap(find.text('New admin? Create your account'));
    await settle(tester);
    for (final e in find.descendant(of: find.byType(BottomSheet), matching: find.byType(IconButton)).evaluate()) {
      final b = e.widget as IconButton;
      if (b.tooltip == null) findings.add('admin sign-up sheet: IconButton ${(b.icon as Icon).icon} has no tooltip/semantic label');
    }
    await teardown(tester);
    handle.dispose();
    report('icon-only labels', findings);
  });

  // ---------------------------------------------------------------------------------------------
  // 8b. askNote dialog: closing it must not touch its disposed controller.
  testWidgets('askNote dialog closes cleanly', (tester) async {
    final findings = <String>[];
    final store = demoStore(Role.admin);
    final router = await boot(tester, store, const Size(412, 915), inset: navInset);
    final ctx = await rootContext(tester, router, '/admin');
    askNote(ctx, title: 'Reject payment', hint: 'Reason', action: 'Reject', message: 'Tell the family why.');
    await settle(tester);
    findings.addAll(errors(tester, 'askNote open'));
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    findings.addAll(errors(tester, 'askNote close (Cancel)'));
    await teardown(tester);
    report('askNote dialog', findings);
  }, skip: !strict && !askNoteProbe); // Known bug (fails by throwing): run with --dart-define=QA_ASKNOTE=true.

  // ---------------------------------------------------------------------------------------------
  // 9. Theme token contrast table (WCAG AA 4.5:1 for body text, 3:1 for >=18.66px bold / 24px).
  test('theme token contrast', () {
    double ratio(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
    }

    Color over(Color fg, Color bg) => Color.alphaBlend(fg, bg);
    final pairs = <String, (Color, Color, double)>{
      'muted on canvas': (C.muted, C.canvas, 4.5),
      'muted on white': (C.muted, Colors.white, 4.5),
      'muted on sand (Segmented, chips)': (C.muted, C.sand, 4.5),
      'amber on amberBg (StatusChip)': (C.amber, C.amberBg, 4.5),
      'green on greenBg': (C.green, C.greenBg, 4.5),
      'red on redBg': (C.red, C.redBg, 4.5),
      'blue on blueBg': (C.blue, C.blueBg, 4.5),
      'violet on violetBg': (C.violet, C.violetBg, 4.5),
      'white on clay500 (accent btn)': (Colors.white, C.clay500, 4.5),
      'clay500 text on white': (C.clay500, Colors.white, 4.5),
      'white on amber (badge)': (Colors.white, C.amber, 4.5),
      'brand200 on brand700 (chat time)': (C.brand200, C.brand700, 4.5),
      'brand200 on brand900 (hero sub)': (C.brand200, C.brand900, 4.5),
      'brand300 on brand900 (hero footnote)': (C.brand300, C.brand900, 4.5),
      'brand300 on hero end 1B1F7A': (C.brand300, const Color(0xFF1B1F7A), 4.5),
      'sky on white': (C.sky, Colors.white, 4.5),
      'sky on hero (matters)': (C.sky, C.brand900, 3),
      'brand100 on brand800 (day choice primary EEE)': (C.brand100, C.brand700, 4.5),
      'muted on sand-disabled button': (C.muted, C.sand, 4.5),
      'IdBadge ink72 on sand': (over(C.ink.withValues(alpha: 0.72), C.sand), C.sand, 4.5),
      'white on white14 over brand900 (light IdBadge)': (Colors.white, over(Colors.white.withValues(alpha: 0.14), C.brand900), 4.5),
      'brand400 on white': (C.brand400, Colors.white, 4.5),
      'muted on clay50 (nav indicator)': (C.muted, C.clay50, 4.5),
      'C.line border vs white (3:1 non-text)': (C.line, Colors.white, 3),
      'input border C.line vs white (3:1 non-text, WCAG 1.4.11)': (C.line, Colors.white, 3),
      'disabled filled btn: muted? on sand': (const Color(0xFF6A6E88), C.sand, 4.5),
    };
    final findings = <String>[];
    for (final MapEntry(key: name, value: (fg, bg, min)) in pairs.entries) {
      final r = ratio(fg, bg);
      // ignore: avoid_print
      print('[LAYOUT]   contrast $name: ${r.toStringAsFixed(2)}');
      if (r < min) findings.add('$name: ${r.toStringAsFixed(2)}:1 < $min:1');
    }
    report('theme contrast', findings);
  });
}
