import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import 'package:supabase_flutter/supabase_flutter.dart' as sb show Session;

import 'assessment/api.dart';
import 'assessment/model.dart';
import 'assessment/scores.dart';
import 'models.dart';
import 'offline.dart';
import 'util.dart';

/// App-wide state: the signed-in user plus every row RLS lets that user see.
///
/// Each role runs the same queries; the database decides what comes back. Timetable weeks are
/// loaded on demand and cached by their Monday. Writes live in `actions.dart`.
/// The message our Edge Function put in `{error: ...}`, or a generic one.
String functionError(FunctionException e) {
  final d = e.details;
  if (d is Map && d['error'] is String) return d['error'];
  return e.status == 0 ? "Couldn't reach the server. Check your internet connection." : 'Something went wrong. Please try again.';
}

/// True when the auth server turned a saved login down (refresh token revoked or unknown, e.g. after a password
/// reset). Being offline, a timeout or a server error is not a rejection: the login may still work later.
bool loginRejected(Object e) =>
    (e is AuthApiException || e is AuthInvalidJwtException || e is AuthSessionMissingException) && (int.tryParse((e as AuthException).statusCode ?? '') ?? 400) < 500;

/// A parent login remembered on this device, so a family with several children switches between them
/// without typing passwords again (like adding accounts in Instagram). Only the refresh token is kept,
/// in the same app storage Supabase already uses for the signed-in session.
class SavedAccount {
  final String userId, login, childName;
  String refreshToken;
  SavedAccount({required this.userId, required this.login, required this.childName, required this.refreshToken});
  SavedAccount.of(Json m)
      : userId = m['user_id'],
        login = m['login'],
        childName = m['child_name'],
        refreshToken = m['refresh_token'];
  Json toJson() => {'user_id': userId, 'login': login, 'child_name': childName, 'refresh_token': refreshToken};
}

class AppStore extends ChangeNotifier {
  final SupabaseClient db;

  /// Live updates across devices. Tests turn this off.
  bool realtime = true;

  AppStore({SupabaseClient? client}) : db = client ?? Supabase.instance.client {
    // Supabase rotates refresh tokens; keep the remembered copy of the signed-in parent account current.
    _authSub = db.auth.onAuthStateChange.listen((s) {
      if (_switching || role != Role.parent) return;
      final token = s.session?.refreshToken;
      if (token == null || s.session?.user.id != userId) return;
      final a = accounts.where((a) => a.userId == userId).firstOrNull;
      if (a != null && a.refreshToken != token) {
        a.refreshToken = token;
        _saveAccounts();
      }
    }, onError: (_) {});
  }

  StreamSubscription<AuthState>? _authSub;

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Changes only on sign-in/out, so the router can listen to it without reacting to every data refresh.
  final auth = ValueNotifier<Role?>(null);
  Role? get role => auth.value;
  set role(Role? r) => auth.value = r;
  bool restoring = false;

  String? userId;
  String userName = '';
  String? therapistId; // set when the signed-in user is a therapist

  /// Parent logins belong to one child (their ID is the login); this is that child.
  String? loginChildId;

  /// Signed in with the default password (new login or admin reset): must set their own before using the
  /// app. The router listens to [gate] so it can hold them on the set-password screen.
  bool get mustChangePassword => gate.value;
  set mustChangePassword(bool v) => gate.value = v;
  final gate = ValueNotifier<bool>(false);

  /// Set when a save worked but the person's login couldn't be created or updated (shown by the form).
  String? loginWarning;

  /// Admin only: children whose parent login exists.
  Set<String> parentLogins = {};

  /// Admin only: therapist/parent logins (profile ids) still on the default password, plus the parent
  /// login of each child, so profiles can say whether the default password is still the one in use.
  Set<String> defaultPasswordLogins = {};
  Map<String, String> parentProfileOf = {};
  bool onDefaultPassword(String? profileId) => profileId != null && defaultPasswordLogins.contains(profileId);

  /// Newest last. Admins get every conversation; parents only their children's and therapists only their
  /// own with the centre (RLS).
  List<Message> messages = [];
  bool ready = false;
  String? error;

  List<Therapy> therapies = [];
  List<Therapist> therapists = [];
  List<Child> children = [];
  final Map<String, List<Slot>> _weeks = {};

  /// Weekly bills (admin: every child; parent: their children), newest week first.
  List<FeeWeek> feeWeeks = [];

  /// Every payment attempt the user may see, newest first.
  List<Payment> payments = [];

  /// Admin only: the UPI IDs payments go to.
  List<UpiAccount> upiAccounts = [];
  List<RescheduleRequest> requests = [];

  /// Therapist: my attended sessions without a report yet. Admin: everyone's. Oldest first.
  List<PendingReport> pendingReports = [];
  final Map<String, List<ProgressPoint>> _progress = {};

  /// Assessment history per child, newest first (loaded when a child is opened; never kept offline: clinical
  /// records stay on the server). Admin: intake assessments not yet attached to a child.
  final Map<String, List<AssessmentSummary>> assessmentsByChild = {};
  List<AssessmentSummary> intakeDrafts = [];

  /// Completed assessments per child as chart points, oldest first (everyone who may see the child).
  final Map<String, List<AssessmentPoint>> assessmentTimeline = {};

  /// Children whose assessments are on screen right now (a profile can be open more than once in the stack).
  final Map<String, int> _assessmentViews = {};
  Iterable<String> get assessmentsShown => _assessmentViews.keys;
  void showingAssessments(String childId, bool on) {
    final n = (_assessmentViews[childId] ?? 0) + (on ? 1 : -1);
    n <= 0 ? _assessmentViews.remove(childId) : _assessmentViews[childId] = n;
  }
  final Map<String, Future<void>> _loadingProgress = {};

  /// Monday → how much is planned that week. Lets the timetable list weeks without loading them.
  Map<String, ({int slots, int sessions})> weekIndex = {};
  final Map<String, Future<void>> _loadingWeeks = {};

  Map<String, Therapy> _therapy = {};
  Map<String, Therapist> _therapist = {};
  Map<String, Child> _child = {};

  /// Bumped on sign-out so responses that arrive afterwards are dropped instead of cached for the next user.
  int _epoch = 0;

  RealtimeChannel? _channel;
  Timer? _debounce;
  final Set<String> _dirty = {};
  final Set<String> _dirtyWeeks = {};
  bool _allWeeksDirty = false;

  void touch() => notifyListeners();
  bool get isAdmin => role == Role.admin;

  // ---- offline -------------------------------------------------------------

  /// Saves a small snapshot for offline use (see [OfflineCache]). Tests turn this off.
  bool persist = true;

  /// The server can't be reached: what's on screen is the saved snapshot or the last data loaded.
  bool offline = false;

  /// When the data on screen was last fetched from the server.
  DateTime? dataAsOf;

  /// A reconnect attempt is running (the offline banner shows a spinner).
  bool reconnecting = false;

  // The rows behind what's loaded, kept as fetched so the snapshot can be rebuilt without re-encoding models.
  final Map<String, List<Json>> _raw = {};
  final Map<String, List<Json>> _rawWeeks = {};
  final Map<String, List<Json>> _rawProgress = {};
  Json? _rawProfile;
  Timer? _saveTimer, _retryTimer;
  int _retryStep = 0;

  @override
  void notifyListeners() {
    super.notifyListeners();
    // Any change to live data refreshes the snapshot a few seconds later (one write for a burst of changes).
    if (persist && ready && !offline && userId != null && role != null) {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(seconds: 4), saveSnapshot);
    }
  }

  /// What's kept for offline use: enough to show each role's main screens, and no more.
  @visibleForTesting
  Json snapshot() {
    final thisWeek = weekStart(todayISO());
    final weeks = {thisWeek, addDays(thisWeek, 7), if (role == Role.therapist) addDays(thisWeek, -7)};
    final recent = addDays(thisWeek, -28);
    final fortnight = DateTime.now().subtract(const Duration(days: 14));
    List<Json> rows(String k) => _raw[k] ?? const [];
    return {
      'v': OfflineCache.version,
      'user_id': userId,
      'saved_at': (dataAsOf ?? DateTime.now()).toUtc().toIso8601String(),
      'profile': _rawProfile,
      'therapies': rows('therapies'),
      'therapists': rows('therapists'),
      'children': rows('children'),
      'weeks': {for (final m in weeks) if (_rawWeeks[m] != null) m: _rawWeeks[m]},
      // Recent bills, plus any older week that still has something to pay.
      'fees': [for (final w in rows('fees')) if ((w['week_start'] as String).compareTo(recent) >= 0 || FeeWeek(w).due > 0) w],
      'payments': rows('payments').take(30).toList(),
      'messages': OfflineCache.lastPerThread(rows('messages'), 40),
      'requests': [
        for (final r in rows('requests'))
          if (r['status'] == 'pending' || (DateTime.tryParse('${r['resolved_at'] ?? r['created_at']}')?.isAfter(fortnight) ?? false)) r,
      ],
      'reports': rows('reports'),
      'upi': rows('upi'),
      'week_index': {for (final e in weekIndex.entries) if (e.key.compareTo(recent) >= 0) e.key: [e.value.slots, e.value.sessions]},
      // A family's progress charts; staff reload these when they open a child.
      'progress': role == Role.parent ? _rawProgress : const <String, dynamic>{},
    };
  }

  /// Writes the snapshot now (normally a few seconds after the data changes).
  Future<void> saveSnapshot() async {
    _saveTimer?.cancel();
    final uid = userId;
    if (!persist || offline || uid == null || role == null || _rawProfile == null || !_raw.containsKey('children')) return;
    await OfflineCache.write(uid, snapshot());
  }

  /// Shows the saved snapshot for the signed-in login. False when there is none.
  Future<bool> openSaved() async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) return false;
    if (role != null) return true;
    final s = await OfflineCache.read(uid);
    if (s == null) return false;
    // Live data may have arrived while the file was being read.
    if (role != null) return true;
    try {
      applySnapshot(s);
    } catch (_) {
      await OfflineCache.remove(uid);
      _clear();
      return false;
    }
    _scheduleRetry();
    notifyListeners();
    return true;
  }

  /// Fills the store from a saved snapshot and marks it [offline].
  @visibleForTesting
  void applySnapshot(Json s) {
    List<Json> rows(Object? v) => ((v as List?) ?? const []).cast<Json>();
    final p = s['profile'] as Json;
    _rawProfile = p;
    userId = s['user_id'] as String;
    userName = p['full_name'] ?? '';
    loginChildId = p['child_id'];
    mustChangePassword = p['must_change_password'] ?? false;
    for (final k in const ['therapies', 'therapists', 'children', 'fees', 'payments', 'messages', 'requests', 'reports', 'upi']) {
      _raw[k] = rows(s[k]);
    }
    setCatalog(_raw['therapies']!.map(Therapy.new).toList(), _raw['therapists']!.map(Therapist.new).toList(), _raw['children']!.map(Child.new).toList());
    for (final e in ((s['weeks'] as Map?) ?? const {}).entries) {
      _rawWeeks[e.key as String] = rows(e.value);
      _weeks[e.key as String] = rows(e.value).map(Slot.new).toList();
    }
    setFees(_raw['fees']!.map(FeeWeek.new).toList(), _raw['payments']!.map(Payment.new).toList());
    messages = _raw['messages']!.map(Message.new).toList();
    requests = _raw['requests']!.map(RescheduleRequest.new).toList();
    pendingReports = _raw['reports']!.map(PendingReport.new).toList();
    upiAccounts = _raw['upi']!.map(UpiAccount.new).toList();
    weekIndex = {
      for (final e in ((s['week_index'] as Map?) ?? const {}).entries)
        e.key as String: (slots: ((e.value as List)[0] as num).toInt(), sessions: ((e.value as List)[1] as num).toInt()),
    };
    for (final e in ((s['progress'] as Map?) ?? const {}).entries) {
      _rawProgress[e.key as String] = rows(e.value);
      _progress[e.key as String] = rows(e.value).map(ProgressPoint.new).toList();
    }
    therapistId = therapists.where((t) => t.profileId == userId).firstOrNull?.id;
    dataAsOf = DateTime.tryParse('${s['saved_at']}')?.toLocal();
    offline = true;
    ready = true;
    role = Role.of(p['role'] as String);
  }

  /// Tries the server again. On success everything is reloaded and the offline banner goes away.
  Future<bool> reconnect() async {
    if (reconnecting || role == null) return !offline;
    _retryTimer?.cancel();
    reconnecting = true;
    notifyListeners();
    try {
      await bootstrap(keepSession: true);
    } finally {
      reconnecting = false;
    }
    if (offline) {
      _scheduleRetry();
    } else {
      _retryStep = 0;
    }
    notifyListeners();
    return !offline;
  }

  /// A request couldn't reach the server: say the data may be out of date, and keep retrying.
  void noteNetworkError(Object e) {
    if (role == null || offline || !isNetworkError(e)) return;
    offline = true;
    _scheduleRetry();
    notifyListeners();
  }

  // Backs off from 10 seconds to 2 minutes; returning to the app or tapping Retry tries at once.
  void _scheduleRetry() {
    _retryTimer?.cancel();
    if (!persist) return;
    const steps = [10, 20, 40, 60, 120];
    _retryTimer = Timer(Duration(seconds: steps[_retryStep.clamp(0, steps.length - 1)]), reconnect);
    _retryStep++;
  }

  /// How far back fees are loaded.
  static const feeWeeksBack = 26;

  // ---- session -------------------------------------------------------------

  /// Signs in as [role] with what that role types (email, mobile number or child ID).
  /// Failures leave a friendly message in [error].
  Future<void> signIn(Role role, String typed, String password) async {
    error = null;
    final email = loginEmail(role, typed);
    if (email == null) {
      error = _missingLogin(role);
      notifyListeners();
      return;
    }
    try {
      await db.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      error = _authError(role, e);
      notifyListeners();
      return;
    } catch (_) {
      error = "Couldn't reach the server. Check your internet connection and try again.";
      notifyListeners();
      return;
    }
    await bootstrap();
  }

  String _missingLogin(Role role) => switch (role) {
        Role.admin => 'Enter your email address.',
        Role.therapist => 'Enter your 10-digit mobile number.',
        Role.parent => "Enter your child's ID, for example C001.",
      };

  String _authError(Role role, AuthException e) {
    final what = switch (role) { Role.admin => 'email', Role.therapist => 'mobile number', Role.parent => 'child ID' };
    final m = e.message.toLowerCase();
    return m.contains('banned')
        ? 'This login is paused. Please contact the centre.'
        : m.contains('invalid') || e.statusCode == '400'
            ? "That $what and password don't match. Check them, or ask the centre to reset your password."
            : e.message;
  }

  /// Creates an admin account. The server only allows emails on the centre's approved list.
  Future<void> signUpAdmin({required String name, required String email, required String password}) async {
    try {
      await db.functions.invoke('accounts', body: {'action': 'admin_signup', 'name': name.trim(), 'email': email.trim(), 'password': password});
    } on FunctionException catch (e) {
      throw Exception(functionError(e));
    }
    await signIn(Role.admin, email, password);
  }

  /// Sets the signed-in user's password. Admins can always change theirs; therapists and parents only to
  /// replace the default password (the database refuses any other change they try to make).
  Future<void> setPassword(String password) async {
    if (!isAdmin && !mustChangePassword) throw Exception('Your password is managed by the centre. Ask the admin to reset it.');
    try {
      await db.auth.updateUser(UserAttributes(password: password));
    } on AuthException catch (e) {
      throw Exception(e.message.toLowerCase().contains('different') || e.message.toLowerCase().contains('same')
          ? (mustChangePassword ? 'Choose a password different from the one the centre gave you.' : 'Choose a password different from the one you have now.')
          : e.message);
    }
    mustChangePassword = false;
    notifyListeners();
  }

  /// Loads everything for the signed-in user. A network failure signs them out unless [keepSession]
  /// (used when reopening the app, so being offline doesn't throw away a saved login).
  Future<void> bootstrap({bool keepSession = false}) async {
    final user = db.auth.currentUser;
    if (user == null) return;
    try {
      error = null;
      final p = await db.from('profiles').select().eq('id', user.id).single();
      _rawProfile = p;
      userId = user.id;
      userName = p['full_name'];
      loginChildId = p['child_id'];
      mustChangePassword = p['must_change_password'] ?? false;
      final r = Role.of(p['role']);
      await Future.wait([
        loadCatalog(),
        loadWeek(weekStart(todayISO()), force: true),
        // Families confirm next week's sessions ahead of time, so the Schedule badge needs it from the start.
        if (r == Role.parent) loadWeek(addDays(weekStart(todayISO()), 7), force: true),
        if (r != Role.therapist) loadFees(),
        loadMessages(),
        if (r != Role.therapist) loadRequests(),
        if (r == Role.admin) loadUpiAccounts(),
        if (r == Role.admin) loadWeekIndex(),
        if (r == Role.admin) loadParentLogins(),
        if (r != Role.parent) loadPendingReports(),
      ]);
      therapistId = therapists.where((t) => t.profileId == user.id).firstOrNull?.id;
      offline = false;
      dataAsOf = DateTime.now();
      _retryTimer?.cancel();
      role = r;
      ready = true;
      if (r == Role.parent) await _rememberAccount();
      if (realtime) _subscribe();
      unawaited(saveSnapshot());
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        // No profile row: the login exists but the centre hasn't set it up in the app.
        error = "This account isn't set up for Nuvara yet. Please contact your centre.";
        await db.auth.signOut();
      } else {
        await _couldNotLoad(keepSession, network: isNetworkError(e));
      }
    } catch (_) {
      await _couldNotLoad(keepSession, network: true);
    }
    notifyListeners();
  }

  /// Loading failed. When reopening the app, show the saved snapshot so the screens aren't empty.
  Future<void> _couldNotLoad(bool keepSession, {required bool network}) async {
    if (keepSession && (offline || await openSaved())) {
      error = null;
      offline = true;
      return;
    }
    error = network ? "Couldn't reach the server. Check your internet connection and try again." : 'Something went wrong while loading your data. Please try again.';
    if (!keepSession) await db.auth.signOut();
  }

  /// Forgets everything loaded for the current user (sign-out and account switches).
  void _clear() {
    _saveTimer?.cancel();
    _retryTimer?.cancel();
    _retryStep = 0;
    offline = reconnecting = false;
    dataAsOf = null;
    _raw.clear();
    _rawWeeks.clear();
    _rawProgress.clear();
    _rawProfile = null;
    _epoch++;
    _debounce?.cancel();
    _dirty.clear();
    _dirtyWeeks.clear();
    _channel?.unsubscribe();
    _channel = null;
    userId = therapistId = loginChildId = null;
    ready = false;
    _weeks.clear();
    weekIndex = {};
    therapies = [];
    therapists = [];
    children = [];
    feeWeeks = [];
    payments = [];
    upiAccounts = [];
    requests = [];
    pendingReports = [];
    _progress.clear();
    assessmentsByChild.clear();
    intakeDrafts = [];
    assessmentTimeline.clear();
    messages = [];
    parentLogins = {};
    defaultPasswordLogins = {};
    parentProfileOf = {};
    mustChangePassword = false;
  }

  /// Signs out of the current login. A parent with other children remembered on this device moves on to
  /// the next one, like Instagram; [everywhere] signs out of every remembered login.
  Future<void> signOut({bool everywhere = false}) async {
    final leaving = userId;
    final others = role == Role.parent && !everywhere ? accounts.where((a) => a.userId != leaving).toList() : <SavedAccount>[];
    accounts.removeWhere((a) => everywhere || a.userId == leaving);
    await _saveAccounts();
    // Signing out of a login also removes its saved data from this device.
    if (everywhere) {
      await OfflineCache.clear();
    } else if (leaving != null) {
      await OfflineCache.remove(leaving);
    }
    _switching = true;
    try {
      await db.auth.signOut();
    } catch (_) {/* signed out locally anyway */}
    _clear();
    _switching = false;
    for (final a in others) {
      if (await _enter(a)) return;
    }
    role = null;
    notifyListeners();
  }

  // ---- parent accounts on this device -----------------------------------------

  /// Parent logins remembered on this device, the signed-in one included.
  List<SavedAccount> accounts = [];
  bool _accountsLoaded = false;

  /// True while moving to another account; screens show a loader rather than half-cleared data.
  bool get switching => _switching;
  bool _switching = false;

  static const _accountsKey = 'nuvara.parent_accounts.v1';

  Future<void> loadAccounts() async {
    if (_accountsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_accountsKey);
      if (raw != null) accounts = [for (final m in (jsonDecode(raw) as List).cast<Json>()) SavedAccount.of(m)];
    } catch (_) {/* starts empty */}
    _accountsLoaded = true;
  }

  Future<void> _saveAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accountsKey, jsonEncode([for (final a in accounts) a.toJson()]));
    } catch (_) {/* best effort: the next sign-in saves again */}
  }

  Future<void> _rememberAccount() async {
    await loadAccounts();
    final token = db.auth.currentSession?.refreshToken;
    final uid = userId;
    if (token == null || uid == null) return;
    final kid = child(loginChildId);
    final login = kid?.code ?? (accounts.where((a) => a.userId == uid).firstOrNull?.login ?? '');
    final name = kid?.name ?? (accounts.where((a) => a.userId == uid).firstOrNull?.childName ?? userName);
    accounts.removeWhere((a) => a.userId == uid);
    accounts.insert(0, SavedAccount(userId: uid, login: login, childName: name, refreshToken: token));
    await _saveAccounts();
  }

  /// Opens a remembered account. False when it can't be opened; the account is forgotten only when its login
  /// no longer works (e.g. the centre reset the password), never just because the device is offline.
  Future<bool> _enter(SavedAccount a) async {
    _switching = true;
    notifyListeners();
    try {
      await db.auth.setSession(a.refreshToken);
    } catch (e) {
      if (loginRejected(e)) {
        accounts.removeWhere((x) => x.userId == a.userId);
        await _saveAccounts();
        await OfflineCache.remove(a.userId);
      }
      _switching = false;
      return false;
    }
    _switching = false;
    await bootstrap();
    return role != null;
  }

  /// Switches to another remembered parent login. If that login no longer works, the current one is
  /// restored and the reason is thrown.
  Future<void> switchAccount(SavedAccount a) async {
    if (a.userId == userId) return;
    final back = db.auth.currentSession;
    await _stash(back);
    _switching = true;
    _clear();
    notifyListeners();
    try {
      await db.auth.setSession(a.refreshToken);
    } catch (e) {
      final rejected = loginRejected(e);
      if (rejected) {
        accounts.removeWhere((x) => x.userId == a.userId);
        await _saveAccounts();
        await OfflineCache.remove(a.userId);
      }
      await _restore(back);
      throw Exception(rejected
          ? "${a.login}'s login has changed. Add it again with the password from the centre."
          : "Couldn't reach the server. Check your internet connection and try again.");
    }
    _switching = false;
    await bootstrap();
  }

  /// Adds another child's login on this device and switches to it. On a wrong password nothing changes.
  Future<void> addAccount(String typed, String password) async {
    final email = loginEmail(Role.parent, typed);
    if (email == null) throw Exception(_missingLogin(Role.parent));
    final already = accounts.where((a) => a.login.toUpperCase() == normaliseChildCode(typed)).firstOrNull;
    if (already != null) {
      await switchAccount(already);
      return;
    }
    final back = db.auth.currentSession;
    await _stash(back);
    _switching = true;
    notifyListeners();
    try {
      await db.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      _switching = false;
      notifyListeners();
      throw Exception(_authError(Role.parent, e));
    } catch (_) {
      _switching = false;
      notifyListeners();
      throw Exception("Couldn't reach the server. Check your internet connection and try again.");
    }
    if (db.auth.currentUser?.id == userId) {
      _switching = false;
      notifyListeners();
      return;
    }
    _clear();
    _switching = false;
    await bootstrap();
    if (role != Role.parent) {
      // Not a parent login: go back to where we were.
      await db.auth.signOut().catchError((_) {});
      _switching = true;
      _clear();
      await _restore(back);
      throw Exception("That isn't a parent login. Use your child's ID, like C002.");
    }
  }

  /// Keeps the outgoing account's newest refresh token, so switching back to it works.
  Future<void> _stash(sb.Session? current) async {
    final a = accounts.where((x) => x.userId == userId).firstOrNull;
    final token = current?.refreshToken;
    if (a == null || token == null || a.refreshToken == token) return;
    a.refreshToken = token;
    await _saveAccounts();
  }

  /// Puts back the session that was active before a switch failed.
  Future<void> _restore(sb.Session? back) async {
    try {
      if (back != null) await db.auth.setSession(back.refreshToken!, accessToken: back.accessToken);
    } catch (_) {/* falls through to the login screen */}
    _switching = false;
    if (db.auth.currentSession != null) {
      await bootstrap();
    } else {
      role = null;
      notifyListeners();
    }
  }

  void _subscribe() {
    _channel?.unsubscribe();
    _channel = db
        .channel('centre')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          callback: (payload) {
            // Messages are applied straight from the change, so a chat updates instantly.
            if (payload.table == 'messages') return _onMessage(payload);
            _dirty.add(payload.table);
            // A row's date tells us which cached week to refresh; deletes only carry the id, so refresh all.
            final m = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch('${payload.newRecord['slot_date'] ?? payload.newRecord['during'] ?? ''}');
            if (const {'timetable_slots', 'sessions', 'session_children'}.contains(payload.table)) {
              m == null ? _allWeeksDirty = true : _dirtyWeeks.add(weekStart(m.group(0)!));
            }
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), _flush);
          },
        )
        .subscribe((status, [err]) {
          // The live channel drops with the network and rejoins when it's back: use that to come back online.
          if (status == RealtimeSubscribeStatus.subscribed && offline) unawaited(reconnect());
          if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
            noteNetworkError(err ?? TimeoutException('Live updates stopped'));
          }
        });
  }

  Future<void> _flush() async {
    final t = {..._dirty};
    final weeks = {..._dirtyWeeks};
    final allWeeks = _allWeeksDirty;
    _dirty.clear();
    _dirtyWeeks.clear();
    _allWeeksDirty = false;
    if (role == null) return;
    final seats = t.any(const {'sessions', 'session_children'}.contains);
    try {
      await Future.wait([
        // For therapists and parents, which children they may read depends on seats.
        if (t.any(const {'therapies', 'therapists', 'therapist_details', 'therapist_therapies', 'children', 'child_therapies'}.contains) || (!isAdmin && seats)) loadCatalog(),
        if (allWeeks) reloadWeeks() else for (final w in weeks) if (_weeks.containsKey(w)) loadWeek(w, force: true),
        if (isAdmin && t.any(const {'timetable_slots', 'sessions'}.contains)) loadWeekIndex(),
        // Attendance changes the bill; payments change what's due.
        if (role != Role.therapist && (seats || t.contains('fee_payments'))) loadFees(),
        if (role != Role.therapist && t.contains('reschedule_requests')) loadRequests(),
        if (isAdmin && t.contains('upi_accounts')) loadUpiAccounts(),
        if (seats) _reloadProgress(),
        if (seats && role != Role.parent) loadPendingReports(),
      ]);
      notifyListeners();
    } catch (_) {/* the next change retries */}
  }

  // ---- loading -------------------------------------------------------------

  /// Fetches every row of a query in pages: the API returns at most 1,000 rows per request.
  Future<List<Json>> _all(PostgrestTransformBuilder<PostgrestList> Function() query) async {
    const page = 1000;
    final out = <Json>[];
    for (var from = 0;; from += page) {
      final rows = await query().range(from, from + page - 1);
      out.addAll(rows);
      if (rows.length < page) return out;
    }
  }

  Future<void> loadCatalog() async {
    final epoch = _epoch;
    final r = await Future.wait([
      db.from('therapies').select().order('name', ascending: true),
      db.from('therapists').select('*, therapist_therapies(therapy_id), therapist_details(*)').order('therapist_no', ascending: true),
      _all(() => db.from('children').select('*, child_therapies(therapy_id, session_fee)').order('child_no', ascending: true)),
    ]);
    if (epoch != _epoch) return;
    _raw['therapies'] = r[0];
    _raw['therapists'] = r[1];
    _raw['children'] = r[2];
    setCatalog(r[0].map(Therapy.new).toList(), r[1].map(Therapist.new).toList(), r[2].map(Child.new).toList());
  }

  /// Replaces therapies, therapists and children and rebuilds the lookups. Also used by offline tests.
  void setCatalog(List<Therapy> therapies, List<Therapist> therapists, List<Child> children) {
    this.therapies = therapies;
    this.therapists = therapists;
    this.children = children;
    _therapy = {for (final x in therapies) x.id: x};
    _therapist = {for (final x in therapists) x.id: x};
    _child = {for (final x in children) x.id: x};
  }

  @visibleForTesting
  void setWeek(String monday, List<Slot> slots) => _weeks[monday] = slots;

  /// Weekly bills for the last [feeWeeksBack] weeks through next week, any older week still unpaid (so
  /// nothing owed is ever out of sight), and every payment.
  Future<void> loadFees() async {
    final epoch = _epoch;
    final monday = weekStart(todayISO());
    final from = addDays(monday, -7 * feeWeeksBack);
    final r = await Future.wait<dynamic>([
      db.rpc('fee_weeks', params: {'p_from': from, 'p_to': addDays(monday, 13)}),
      db.rpc('fee_weeks_due', params: {'p_before': from}),
      _all(() => db.from('fee_payments').select().order('created_at', ascending: false).order('id', ascending: true)),
    ]);
    if (epoch != _epoch) return;
    _raw['fees'] = [...(r[0] as List), ...(r[1] as List)].cast<Json>();
    _raw['payments'] = r[2] as List<Json>;
    setFees([for (final m in _raw['fees']!) FeeWeek(m)], [for (final m in _raw['payments']!) Payment(m)]);
  }

  /// Replaces bills and payments and indexes them by child and week. Also used by offline tests.
  void setFees(List<FeeWeek> weeks, List<Payment> payments) {
    feeWeeks = weeks..sort((a, b) => b.monday.compareTo(a.monday));
    this.payments = payments;
    _bill = {for (final w in weeks) '${w.childId}|${w.monday}': w};
    _billsOf = {};
    for (final w in feeWeeks) {
      (_billsOf[w.childId] ??= []).add(w);
    }
  }

  Map<String, FeeWeek> _bill = {};
  Map<String, List<FeeWeek>> _billsOf = {};

  Future<void> loadUpiAccounts() async {
    final epoch = _epoch;
    final rows = await db.from('upi_accounts').select().order('created_at', ascending: true);
    if (epoch != _epoch) return;
    _raw['upi'] = rows;
    upiAccounts = rows.map(UpiAccount.new).toList();
  }

  Future<void> loadPendingReports() async {
    final epoch = _epoch;
    final rows = (await db.rpc('pending_reports') as List).cast<Json>();
    if (epoch != _epoch) return;
    _raw['reports'] = rows;
    pendingReports = [for (final m in rows) PendingReport(m)];
  }

  Future<void> loadRequests() async {
    final epoch = _epoch;
    final rows = await _all(() => db.from('reschedule_requests').select().order('created_at', ascending: false).order('id', ascending: true));
    if (epoch != _epoch) return;
    _raw['requests'] = rows;
    requests = rows.map(RescheduleRequest.new).toList();
  }

  /// Every rated or noted session of [childId] (cached; [force] reloads).
  Future<void> loadProgress(String childId, {bool force = false}) {
    if (!force && _progress.containsKey(childId)) return Future.value();
    final running = _loadingProgress[childId];
    if (running != null) return running;
    final epoch = _epoch;
    return _loadingProgress[childId] = () async {
      try {
        final rows = (await db.rpc('progress_points', params: {'p_child': childId}) as List).cast<Json>();
        if (epoch == _epoch) {
          _rawProgress[childId] = rows;
          _progress[childId] = [for (final m in rows) ProgressPoint(m)];
        }
      } finally {
        _loadingProgress.remove(childId);
      }
    }();
  }

  Future<void> _reloadProgress() => Future.wait([for (final id in _progress.keys.toList()) loadProgress(id, force: true)]);

  @visibleForTesting
  void setProgress(String childId, List<ProgressPoint> points) => _progress[childId] = points;

  /// Null until loaded.
  List<ProgressPoint>? progressOf(String childId) => _progress[childId];

  /// Rated sessions in one therapy, oldest first.
  List<ProgressPoint> ratings(String childId, String therapyId) => [
        for (final p in _progress[childId] ?? const <ProgressPoint>[])
          if (p.therapyId == therapyId && p.rating != null) p,
      ];

  /// Rated sessions averaged per day, oldest first: one chart point a day, so two sessions on the same day
  /// don't stack. Optionally for one therapy and from [from] on.
  List<DayRating> dailyRatings(String childId, {String? therapyId, String? from}) {
    final sum = <String, double>{}, n = <String, int>{};
    for (final p in _progress[childId] ?? const <ProgressPoint>[]) {
      if (p.rating == null || (therapyId != null && p.therapyId != therapyId) || (from != null && p.date.compareTo(from) < 0)) continue;
      sum[p.date] = (sum[p.date] ?? 0) + p.rating!;
      n[p.date] = (n[p.date] ?? 0) + 1;
    }
    return [for (final d in sum.keys.toList()..sort()) (date: d, value: sum[d]! / n[d]!, count: n[d]!)];
  }

  /// Average of the last [n] ratings minus the average of the [n] before them; null without enough data.
  double? ratingTrend(String childId, String therapyId, {int n = 3}) {
    final r = ratings(childId, therapyId);
    if (r.length < n + 1) return null;
    double avg(Iterable<ProgressPoint> x) => x.fold(0.0, (a, p) => a + p.rating!) / x.length;
    final recent = r.sublist(r.length - n);
    final before = r.sublist((r.length - 2 * n).clamp(0, r.length - n), r.length - n);
    return avg(recent) - avg(before);
  }

  /// Loads the Monday–Sunday week starting at [monday]. Concurrent calls share one request; a forced
  /// load that arrives while one is running waits for it and then fetches again, so a reload issued
  /// right after a save always sees that save.
  Future<void> loadWeek(String monday, {bool force = false}) {
    if (!force && _weeks.containsKey(monday)) return Future.value();
    final running = _loadingWeeks[monday];
    if (running != null) {
      if (!force) return running;
      return running.catchError((_) {}).then((_) => loadWeek(monday, force: true));
    }
    final epoch = _epoch;
    return _loadingWeeks[monday] = () async {
      try {
        final rows = await db
            .from('timetable_slots')
            .select('*, sessions(id, name, therapist_id, therapy_id, session_children(child_id, attendance, note, absence_reason, absence_at, rating, rate, confirmed_at))')
            .gte('slot_date', monday)
            .lte('slot_date', addDays(monday, 6))
            .order('slot_date', ascending: true)
            .order('start_time', ascending: true)
            .order('end_time', ascending: true);
        if (epoch == _epoch) {
          _rawWeeks[monday] = rows;
          _weeks[monday] = rows.map(Slot.new).toList();
        }
      } finally {
        _loadingWeeks.remove(monday);
      }
    }();
  }

  Future<void> loadMessages() async {
    final epoch = _epoch;
    final rows = await _all(() => db.from('messages').select().order('created_at', ascending: true).order('id', ascending: true));
    if (epoch != _epoch) return;
    _raw['messages'] = rows;
    messages = rows.map(Message.new).toList();
  }

  /// Admin: which therapist and parent logins exist, and which are still on the default password.
  Future<void> loadParentLogins() async {
    final rows = await db.from('profiles').select('id, child_id, must_change_password').inFilter('role', ['THERAPIST', 'PARENT']);
    parentProfileOf = {for (final r in rows) if (r['child_id'] != null) r['child_id'] as String: r['id'] as String};
    parentLogins = parentProfileOf.keys.toSet();
    defaultPasswordLogins = {for (final r in rows) if (r['must_change_password'] == true) r['id'] as String};
  }

  void _onMessage(PostgresChangePayload p) {
    if (role == null) return;
    final row = p.newRecord;
    if (row.isEmpty) return;
    final m = Message(row);
    final i = messages.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      messages[i] = m;
    } else {
      messages.add(m);
    }
    final raw = _raw['messages'] ??= [];
    final j = raw.indexWhere((x) => x['id'] == m.id);
    if (j >= 0) {
      raw[j] = row;
    } else {
      raw.add(row);
    }
    notifyListeners();
  }

  /// Mine to read: the admin reads what families and therapists send; everyone else what the centre sends.
  bool _incoming(Message m) => m.readAt == null && m.fromAdmin != isAdmin;

  /// Newest first: one entry per conversation that has messages, with families or with therapists.
  List<({String id, Message last, int unread})> _threads(bool therapists) {
    final last = <String, Message>{};
    final unread = <String, int>{};
    for (final m in messages) {
      final id = therapists ? m.therapistId : m.childId;
      if (id == null) continue;
      last[id] = m;
      if (_incoming(m)) unread[id] = (unread[id] ?? 0) + 1;
    }
    return [for (final e in last.entries) (id: e.key, last: e.value, unread: unread[e.key] ?? 0)]..sort((a, b) => b.last.at.compareTo(a.last.at));
  }

  /// Conversations with families, newest first.
  List<({String id, Message last, int unread})> get threads => _threads(false);

  /// Admin: conversations with therapists, newest first.
  List<({String id, Message last, int unread})> get therapistThreads => _threads(true);

  List<Message> thread(Convo c) => messages.where(c.has).toList();
  int unreadIn(Convo c) => messages.where((m) => c.has(m) && _incoming(m)).length;
  int get unreadMessages => messages.where(_incoming).length;
  int get unreadFromFamilies => messages.where((m) => m.childId != null && _incoming(m)).length;
  int get unreadFromTherapists => messages.where((m) => m.therapistId != null && _incoming(m)).length;

  Future<void> loadWeekIndex() async {
    final epoch = _epoch;
    final rows = await _all(() => db.from('timetable_slots').select('slot_date, sessions(count)').gte('slot_date', addDays(weekStart(todayISO()), -7 * 26)).order('id', ascending: true));
    final idx = <String, ({int slots, int sessions})>{};
    for (final r in rows) {
      final m = weekStart(r['slot_date'] as String);
      final n = ((r['sessions'] as List?)?.firstOrNull?['count'] as num?)?.toInt() ?? 0;
      final cur = idx[m] ?? (slots: 0, sessions: 0);
      idx[m] = (slots: cur.slots + 1, sessions: cur.sessions + n);
    }
    if (epoch == _epoch) weekIndex = idx;
  }

  Future<void> reloadWeeks() => Future.wait([for (final m in _weeks.keys.toList()) loadWeek(m, force: true)]);

  /// Reloads everything. Offline it tries to reconnect instead, and a network failure switches to offline
  /// mode (the banner says so) rather than throwing.
  Future<void> refresh() async {
    if (offline) {
      await reconnect();
      return;
    }
    try {
      await _reloadAll();
      dataAsOf = DateTime.now();
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      noteNetworkError(e);
    }
    notifyListeners();
  }

  Future<void> _reloadAll() async {
    await Future.wait([
      loadCatalog(),
      reloadWeeks(),
      if (role != Role.therapist) loadFees(),
      loadMessages(),
      if (role != Role.therapist) loadRequests(),
      if (isAdmin) loadUpiAccounts(),
      if (isAdmin) loadWeekIndex(),
      if (isAdmin) loadParentLogins(),
      if (role != Role.parent) loadPendingReports(),
      _reloadProgress(),
      // Assessments of the children whose profile is on screen.
      for (final id in assessmentsShown) refreshAssessments(id),
    ]);
  }

  // ---- lookups -------------------------------------------------------------

  Therapy? therapy(String? id) => _therapy[id];
  Therapist? therapist(String? id) => _therapist[id];
  Child? child(String? id) => _child[id];
  String therapyName(String? id) => _therapy[id]?.name ?? 'Therapy';
  String therapistName(String? id) => _therapist[id]?.name ?? 'Therapist';
  String childName(String? id) => _child[id]?.name ?? 'Child';
  List<Therapist> get activeTherapists => therapists.where((t) => t.active).toList();
  List<Child> get activeChildren => children.where((c) => c.active).toList();

  /// Null until that week has been loaded.
  List<Slot>? weekSlots(String monday) => _weeks[monday];
  bool weekLoaded(String date) => _weeks.containsKey(weekStart(date));
  List<Slot> slotsOn(String date) => (_weeks[weekStart(date)] ?? const <Slot>[]).where((s) => s.date == date).toList();
  Slot? slotAt(String date, String start, String end) => slotsOn(date).where((s) => s.start == start && s.end == end).firstOrNull;
  Slot? slotById(String id) {
    for (final w in _weeks.values) {
      for (final s in w) {
        if (s.id == id) return s;
      }
    }
    return null;
  }

  Session? sessionById(String id) {
    for (final w in _weeks.values) {
      for (final s in w) {
        for (final x in s.sessions) {
          if (x.id == id) return x;
        }
      }
    }
    return null;
  }

  List<Session> sessionsInWeek(String monday) => [for (final s in _weeks[monday] ?? const <Slot>[]) ...s.sessions];
  List<Session> sessionsOfChild(String childId, String monday) => sessionsInWeek(monday).where((s) => s.childIds.contains(childId)).toList();
  List<Session> sessionsOfTherapist(String therapistId, String monday) => sessionsInWeek(monday).where((s) => s.therapistId == therapistId).toList();

  int childrenCount(String therapyId) => children.where((c) => c.therapyIds.contains(therapyId)).length;
  int therapistCount(String therapyId) => therapists.where((t) => t.therapyIds.contains(therapyId)).length;

  // ---- scheduling rules ----------------------------------------------------
  // The database enforces these with exclusion constraints; checking here lets the form explain
  // *why* someone can't be picked before the admin presses save.

  /// The session that keeps [therapistId] busy between [start] and [end] on [date], if any.
  Session? therapistClash(String therapistId, String date, String start, String end, {String? exceptSession}) {
    for (final slot in slotsOn(date)) {
      if (!overlaps(start, end, slot.start, slot.end)) continue;
      for (final s in slot.sessions) {
        if (s.id != exceptSession && s.therapistId == therapistId) return s;
      }
    }
    return null;
  }

  Session? childClash(String childId, String date, String start, String end, {String? exceptSession}) {
    for (final slot in slotsOn(date)) {
      if (!overlaps(start, end, slot.start, slot.end)) continue;
      for (final s in slot.sessions) {
        if (s.id != exceptSession && s.childIds.contains(childId)) return s;
      }
    }
    return null;
  }

  // ---- fees ----------------------------------------------------------------

  /// What [childId] pays per session of [therapyId] right now: their own rate, or the therapy's base fee.
  double rateOf(String childId, String therapyId) => child(childId)?.therapyOf(therapyId)?.sessionFee ?? therapy(therapyId)?.baseFee ?? 0;

  FeeWeek? bill(String childId, String monday) => _bill['$childId|$monday'];

  /// A child's bills, newest week first.
  List<FeeWeek> billsOf(String childId) => [...?_billsOf[childId]];

  /// Weeks with money due right now (the current week included), oldest first.
  List<FeeWeek> dueBills(String childId) => billsOf(childId).where((w) => w.payable).toList().reversed.toList();
  double dueTotal(String childId) => dueBills(childId).fold(0.0, (a, w) => a + w.due);

  /// Every child with money due, most owed first.
  List<({Child child, double due, List<FeeWeek> weeks})> get owing {
    final out = <({Child child, double due, List<FeeWeek> weeks})>[];
    for (final c in children) {
      final weeks = dueBills(c.id);
      if (weeks.isNotEmpty) out.add((child: c, due: weeks.fold(0.0, (a, w) => a + w.due), weeks: weeks));
    }
    return out..sort((a, b) => b.due.compareTo(a.due));
  }

  List<Payment> paymentsOf(String childId, [String? monday]) => payments.where((p) => p.childId == childId && (monday == null || p.monday == monday)).toList();

  /// A UPI attempt the parent started but never finished (app closed, no reply from the UPI app).
  Payment? unfinishedPayment(String childId, String monday) =>
      payments.where((p) => p.childId == childId && p.monday == monday && p.status == PayStatus.initiated).firstOrNull;

  List<Payment> get paymentsToVerify => payments.where((p) => p.status == PayStatus.verifying || p.status == PayStatus.initiated && DateTime.now().difference(p.createdAt).inMinutes > 30).toList();

  /// UPI payments confirmed by the parent's UPI app that the admin hasn't matched to the bank yet.
  List<Payment> get paymentsToReconcile => payments.where((p) => p.unreconciled).toList();

  UpiAccount? get activeUpi => upiAccounts.where((a) => a.active).firstOrNull;

  List<RescheduleRequest> get pendingRequests => requests.where((r) => r.pending).toList();

  /// Pending requests the admin can still act on (the session hasn't started), soonest session first.
  List<RescheduleRequest> get actionableRequests => requests.where((r) => r.pending && !r.expired).toList()..sort(bySession);

  /// Pending requests whose session has already started: they can only be closed. Soonest first.
  List<RescheduleRequest> get expiredRequests => requests.where((r) => r.expired).toList()..sort(bySession);
  static int bySession(RescheduleRequest a, RescheduleRequest b) => '${a.fromDate} ${a.fromStart}'.compareTo('${b.fromDate} ${b.fromStart}');

  /// Admin: loads every week from this one on that has a timetable (the index knows which), so checks for
  /// upcoming sessions don't miss a week nobody has opened on this device.
  Future<void> loadWeeksAhead() {
    final monday = weekStart(todayISO());
    return Future.wait([for (final m in {monday, ...weekIndex.keys}) if (m.compareTo(monday) >= 0) loadWeek(m)]);
  }

  /// Sessions that haven't started yet in the loaded weeks, soonest first, that pass [test].
  List<Session> upcomingSessions(bool Function(Session s) test) {
    final now = '${todayISO()} ${nowHM()}';
    final monday = weekStart(todayISO());
    return [
      for (final e in _weeks.entries)
        if (e.key.compareTo(monday) >= 0)
          for (final slot in e.value)
            for (final s in slot.sessions)
              if ('${s.date} ${s.start}'.compareTo(now) > 0 && test(s)) s,
    ]..sort((a, b) => '${a.date} ${a.start}'.compareTo('${b.date} ${b.start}'));
  }
  RescheduleRequest? pendingRequestFor(String childId, String sessionId) => requests.where((r) => r.pending && r.childId == childId && r.sessionId == sessionId).firstOrNull;

  /// The waiting change request that will move [session] for [childId]: one asked for this session, or a
  /// "Regularly" one for an earlier session of the same series (same therapist, therapy, start and end on a
  /// later day; the rule `resolve_reschedule` moves by, which `confirm_sessions` mirrors).
  RescheduleRequest? requestCovering(String childId, Session session) {
    final own = pendingRequestFor(childId, session.id);
    if (own != null) return own;
    for (final r in requests) {
      if (!r.pending || !r.series || r.childId != childId || r.sessionId == null) continue;
      // The original session as it is now when loaded; otherwise as it was when the family asked.
      final src = sessionById(r.sessionId!);
      if (session.therapistId == (src?.therapistId ?? r.therapistId) && session.therapyId == (src?.therapyId ?? r.therapyId) &&
          session.start == (src?.start ?? r.fromStart) && session.end == (src?.end ?? r.fromEnd) && session.date.compareTo(src?.date ?? r.fromDate) > 0) {
        return r;
      }
    }
    return null;
  }

  /// [childId]'s sessions in the week of [monday] still waiting for the family to confirm them, soonest first.
  /// A session with a change request waiting (its own, or a "Regularly" one covering it) is not counted: the
  /// family has already answered.
  List<Session> awaitingConfirmation(String childId, String monday) => [
        for (final s in sessionsOfChild(childId, monday))
          if (s.unconfirmed(childId) && requestCovering(childId, s) == null) s,
      ]..sort((a, b) => '${a.date} ${a.start}'.compareTo('${b.date} ${b.start}'));

  /// Parent: sessions to confirm this week and next, across every child on this login (the Schedule tab badge).
  int get toConfirm {
    if (role != Role.parent) return 0;
    final monday = weekStart(todayISO());
    var n = 0;
    for (final c in children) {
      if (!c.active) continue;
      n += awaitingConfirmation(c.id, monday).length + awaitingConfirmation(c.id, addDays(monday, 7)).length;
    }
    return n;
  }
}
