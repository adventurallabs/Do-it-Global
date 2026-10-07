import 'dart:async';

import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'assessment/api.dart';
import 'config.dart';
import 'errors.dart';
import 'models.dart' show Role;
import 'offline.dart';
import 'router.dart';
import 'screens/splash.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets/offline_banner.dart';
import 'widgets/ui.dart' show onNetworkError;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorReporter.install();
  // Archivo and Plus Jakarta Sans are bundled in assets/google_fonts: no downloads, no text reflow.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final f in ['Archivo', 'PlusJakartaSans']) {
      yield LicenseEntryWithLineBreaks([f], await rootBundle.loadString('assets/google_fonts/OFL-$f.txt'));
    }
  });
  runApp(const Boot());
}

/// Shows the splash while Supabase starts, a saved session loads and the fonts arrive, then fades to the app.
class Boot extends StatefulWidget {
  const Boot({super.key});

  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  AppStore? store;
  bool ready = false, offline = false, retrying = false;

  /// Why the app couldn't start (shown on the splash instead of waiting forever).
  String? problem;

  /// Loading a saved session gives up after this, so a dead network shows "Try again" instead of endless dots.
  static const restoreTimeout = Duration(seconds: 20);

  /// With data saved on this device, wait only this long before showing it (the live load carries on).
  static const savedTimeout = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final intro = Future<void>.delayed(SplashScreen.intro);
    if (missingConfig != null) {
      debugPrint(missingConfig);
      await intro;
      return _fail('This build is missing its server settings.');
    }
    try {
      await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
    } catch (e) {
      debugPrint('Supabase failed to start: $e');
      await intro;
      return _fail("Couldn't start the app. Check your internet connection.", canRetry: true);
    }
    store ??= AppStore();
    // A save that fails for lack of network also turns on the offline banner and the automatic retries.
    onNetworkError = store!.noteNetworkError;
    await Future.wait([
      intro,
      _restore(),
      // The fonts are bundled; load the common weights during the splash so the first screen draws in them.
      GoogleFonts.pendingFonts([
        display(16),
        display(16, weight: FontWeight.w400),
        display(16, weight: FontWeight.w700),
        body(14),
        body(14, weight: FontWeight.w500),
        body(14, weight: FontWeight.w600),
        body(14, weight: FontWeight.w700),
        body(14, weight: FontWeight.w800),
      ]).timeout(const Duration(seconds: 4), onTimeout: () => []).catchError((_) => <void>[]),
    ]);
    _finish();
  }

  /// A saved session skips the login screen.
  Future<void> _restore() async {
    final s = store!;
    final user = Supabase.instance.client.auth.currentUser;
    if (Supabase.instance.client.auth.currentSession == null || user == null) return;
    s.restoring = true;
    final saved = await OfflineCache.read(user.id) != null;
    try {
      await s.bootstrap(keepSession: true).timeout(saved ? savedTimeout : restoreTimeout);
    } catch (e) {
      // Timed out: show what's saved on this device (if anything) while the live load finishes or retries.
      // With nothing saved, [_finish] sees no role yet and offers to retry.
      debugPrint('Restoring the saved session failed: $e');
      if (saved) await s.openSaved();
    } finally {
      s.restoring = false;
    }
  }

  void _fail(String message, {bool canRetry = false}) {
    if (!mounted) return;
    setState(() {
      problem = message;
      offline = canRetry;
      retrying = false;
    });
  }

  void _finish() {
    if (!mounted) return;
    problem = null;
    // Still holding a session but couldn't load it: offer to retry rather than dropping to the login screen.
    final stuck = store!.role == null && Supabase.instance.client.auth.currentSession != null;
    setState(() {
      offline = stuck;
      retrying = false;
      ready = !stuck;
    });
  }

  Future<void> _retry() async {
    setState(() => retrying = true);
    // Supabase never started: run the whole boot again.
    if (store == null) return _start();
    await _restore();
    _finish();
  }

  Future<void> _signOut() async {
    await store!.signOut().catchError((_) {});
    store!.error = null;
    _finish();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOut,
      child: ready
          ? NuvaraApp(store!, key: const ValueKey('app'))
          : MaterialApp(
              key: const ValueKey('splash'),
              title: 'Nuvara',
              debugShowCheckedModeBanner: false,
              theme: buildTheme(),
              home: SplashScreen(
                offline: offline || problem != null,
                message: problem,
                retrying: retrying,
                onRetry: problem == null || offline ? _retry : null,
                onSignOut: store == null ? null : _signOut,
              ),
            ),
    ),
  );
}

class NuvaraApp extends StatefulWidget {
  final AppStore store;
  const NuvaraApp(this.store, {super.key});

  @override
  State<NuvaraApp> createState() => _NuvaraAppState();
}

class _NuvaraAppState extends State<NuvaraApp> with WidgetsBindingObserver {
  late final _router = buildRouter(widget.store);

  /// The login whose kept assessment changes were last sent while online (null: not yet / offline since).
  String? _synced;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_syncAssessments);
    _syncAssessments();
  }

  @override
  void dispose() {
    widget.store.removeListener(_syncAssessments);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Each time a login is (back) online, send any assessment changes this device kept after a failed save.
  void _syncAssessments() {
    final s = widget.store;
    if (s.offline || !s.ready || s.role == null || s.role == Role.parent) {
      if (s.offline || s.role == null) _synced = null;
      return;
    }
    if (_synced == s.userId) return;
    _synced = s.userId;
    s.syncPendingAssessments().catchError((_) => 0);
  }

  // Coming back to the app is the likeliest moment the network is back: try at once rather than waiting.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.store.offline) widget.store.reconnect();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: widget.store,
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      // Light screens: dark status-bar icons and a white navigation bar to match the bottom tabs.
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.white, systemNavigationBarIconBrightness: Brightness.dark),
      child: MaterialApp.router(
        title: 'Nuvara',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: _router,
        // Above every screen: says when the app is showing saved data because the server can't be reached.
        builder: (context, child) => OfflineFrame(child: child ?? const SizedBox.shrink()),
      ),
    ),
  );
}
