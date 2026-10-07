import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nuvara/router.dart';
import 'package:nuvara/store.dart';
import 'package:nuvara/theme.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient, AuthClientOptions;

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('login renders and switches roles at phone and desktop widths', (tester) async {
    final store = AppStore(client: SupabaseClient('http://localhost:54321', 'k', authOptions: const AuthClientOptions(autoRefreshToken: false)))..realtime = false;
    for (final size in const [Size(320, 640), Size(360, 740), Size(768, 1024), Size(1280, 800), Size(1920, 1080)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: buildRouter(store))));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.textContaining('Continue as'), findsNothing, reason: 'no one-tap preview accounts in the app');
      // Each role asks for its own sign-in ID.
      expect(find.text("Child's ID"), findsOneWidget);
      await tester.tap(find.text('Therapist'));
      await tester.pumpAndSettle();
      expect(find.text('Mobile number'), findsOneWidget);
      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('New admin? Create your account'), findsOneWidget);
      await tester.ensureVisible(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email and password.'), findsOneWidget);
      // On small phones the message sits over the buttons below; dismiss it like a user would.
      tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('New admin? Create your account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New admin? Create your account'));
      await tester.pumpAndSettle();
      expect(find.text('Create admin account'), findsWidgets);
      Navigator.of(tester.element(find.text('Create admin account').first)).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Parent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parent'));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });

  // Regression: the keyboard closed after a few characters because the form was rebuilt while typing
  // (store notifications, or the window resizing across the wide/phone breakpoint as the keyboard opened).
  testWidgets('typing keeps focus through store updates and window resizes', (tester) async {
    final store = AppStore(client: SupabaseClient('http://localhost:54321', 'k', authOptions: const AuthClientOptions(autoRefreshToken: false)))..realtime = false;
    tester.view.physicalSize = const Size(980, 700);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(ChangeNotifierProvider.value(value: store, child: MaterialApp.router(theme: buildTheme(), routerConfig: buildRouter(store))));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).first;
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, 'C0');
    EditableTextState editable() => tester.state<EditableTextState>(find.byType(EditableText).first);
    expect(editable().widget.focusNode.hasFocus, isTrue);
    // A store change while typing.
    store.touch();
    await tester.pump();
    expect(editable().widget.focusNode.hasFocus, isTrue, reason: 'store updates must not drop focus');
    // The keyboard opens and the window shrinks below the wide breakpoint.
    tester.view.physicalSize = const Size(940, 400);
    await tester.pumpAndSettle();
    expect(editable().widget.focusNode.hasFocus, isTrue, reason: 'switching to the phone layout must keep the field');
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(field, 'C001');
    expect(find.text('C001'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });
}
