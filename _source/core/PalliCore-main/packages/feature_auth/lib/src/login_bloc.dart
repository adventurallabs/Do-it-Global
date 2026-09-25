import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_data/core_data.dart';
import 'package:core_models/core_models.dart' as models;

abstract class LoginEvent {}

/// Admin — Google OAuth. Opens the browser; the resulting session is picked
/// up by the auth-state listener below, which resolves the role.
class AdminGoogleLoginRequested extends LoginEvent {}

/// Admin — email + password, for an address the school has already put on
/// the `auth_admin` allowlist.
class AdminEmailLoginRequested extends LoginEvent {
  final String email;
  final String password;
  AdminEmailLoginRequested(this.email, this.password);
}

/// Admin — create the email+password login. The allowlist is checked
/// server-side by the `admin-signup` function, which is also the only
/// thing that may create the account.
class AdminSignUpRequested extends LoginEvent {
  final String email;
  final String password;
  AdminSignUpRequested(this.email, this.password);
}

/// Teacher — phone + password. Internally `<phone>@teacher.internal`.
class TeacherLoginRequested extends LoginEvent {
  final String phone;
  final String password;
  TeacherLoginRequested(this.phone, this.password);
}

/// Fired by the force-password-change screen once Supabase Auth's own
/// updateUser(password:) has succeeded, to flip must_change_password off and
/// refresh the resolved user.
class PasswordChangeCompleted extends LoginEvent {}

class LogoutRequested extends LoginEvent {}

/// Internal — fired if the Google OAuth round trip never comes back within
/// the timeout started in [LoginBloc._onAdminGoogle], so the button doesn't
/// spin forever.
class _OAuthTimedOut extends LoginEvent {}

/// Internal — reacts to Supabase's own auth-state stream (covers both login
/// flows above, the OAuth deep-link callback, and session restore on app
/// relaunch).
class _AuthStateChanged extends LoginEvent {
  final Session? session;
  _AuthStateChanged(this.session);
}

abstract class LoginState {}

/// The very first state, before Supabase has reported whether a persisted
/// session exists. The router shows the splash screen while in this state —
/// distinct from [LoginInitial] (checked, confirmed signed out) so a
/// returning signed-in user never sees a flash of the login screen.
class LoginSessionUnresolved extends LoginState {}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {
  final models.User user;
  LoginSuccess(this.user);
}

class LoginFailure extends LoginState {
  final String message;
  LoginFailure(this.message);
}

/// The account was created. The sign-up screen shows this, then signs in.
class AdminSignUpSucceeded extends LoginState {
  final String email;
  AdminSignUpSucceeded(this.email);
}

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final SupabaseClient _client;
  StreamSubscription<AuthState>? _authSub;
  Timer? _oauthTimeout;

  /// The auth user behind the current [LoginSuccess]. Supabase re-announces
  /// the same session on every hourly token refresh, on app resume and after
  /// updateUser; none of those change who is signed in, so they must not
  /// drop the app back through LoginLoading (which the router treats as
  /// signed out — bouncing a working teacher to /login and wiping their
  /// screens, or stranding them there if the phone was offline right then).
  String? _resolvedAuthUid;

  LoginBloc(this._client) : super(LoginSessionUnresolved()) {
    on<AdminGoogleLoginRequested>(_onAdminGoogle);
    on<AdminEmailLoginRequested>(_onAdminEmailLogin);
    on<AdminSignUpRequested>(_onAdminSignUp);
    on<TeacherLoginRequested>(_onTeacherLogin);
    on<PasswordChangeCompleted>(_onPasswordChangeCompleted);
    on<LogoutRequested>(_onLogout);
    on<_AuthStateChanged>(_onAuthStateChanged);
    on<_OAuthTimedOut>(_onOAuthTimedOut);

    _authSub = _client.auth.onAuthStateChange.listen((data) {
      add(_AuthStateChanged(data.session));
    });
  }

  Future<void> _onAdminGoogle(AdminGoogleLoginRequested event, Emitter<LoginState> emit) async {
    emit(LoginLoading());
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        // On native, GoTrue redirects to this app-scheme URL, caught by the
        // intent-filter registered in AndroidManifest/Info.plist. On web,
        // redirectTo must be set explicitly to the current page — passing
        // null omits redirect_to from the request entirely, so GoTrue falls
        // back to the project's static Site URL instead, which silently
        // breaks local dev (a different port every `flutter run -d chrome`).
        redirectTo: kIsWeb ? Uri.base.toString() : 'io.supabase.pallicore://login-callback/',
        authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
      // Browser takes over from here; onAuthStateChange fires on return.
      // If it never does (redirect URL not allow-listed, deep link not
      // delivered, user backs out), don't leave the button spinning forever.
      _oauthTimeout?.cancel();
      _oauthTimeout = Timer(const Duration(seconds: 45), () => add(_OAuthTimedOut()));
    } catch (e) {
      emit(LoginFailure('Could not start Google sign-in: $e'));
    }
  }

  Future<void> _onAdminEmailLogin(
    AdminEmailLoginRequested event,
    Emitter<LoginState> emit,
  ) async {
    emit(LoginLoading());
    try {
      await _client.auth.signInWithPassword(
        email: event.email.trim().toLowerCase(),
        password: event.password,
      );
      // onAuthStateChange resolves the role from here.
    } catch (e) {
      emit(LoginFailure(describeSignInError(e,
          badCredentials: 'That email and password do not match. If you have '
              'only ever used Google, sign in with Google instead.')));
    }
  }

  /// Creating the login is the server's job: the allowlist lives behind the
  /// service role, and letting the client call `signUp` directly would make
  /// an auth account for any address at all, approved or not.
  Future<void> _onAdminSignUp(
    AdminSignUpRequested event,
    Emitter<LoginState> emit,
  ) async {
    emit(LoginLoading());
    final email = event.email.trim().toLowerCase();
    try {
      await _client.functions.invoke(
        'admin-signup',
        body: {'email': email, 'password': event.password},
      );
      emit(AdminSignUpSucceeded(email));
    } on FunctionException catch (e) {
      emit(LoginFailure(_readableFunctionError(e)));
    } catch (_) {
      emit(LoginFailure(
          'Could not create the account. Check your connection and try again.'));
    }
  }

  /// Edge Functions return their message in `{"error": "…"}`; the SDK hands
  /// that back as an untyped body, and without this the admin would see the
  /// raw status code instead of the sentence the function wrote.
  static String _readableFunctionError(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (details is String && details.trim().isNotEmpty) return details;
    return 'Could not create the account. Please try again.';
  }

  void _onOAuthTimedOut(_OAuthTimedOut event, Emitter<LoginState> emit) {
    if (state is LoginLoading) {
      emit(LoginFailure(
        "Google sign-in didn't complete. Make sure this app/browser is allowed to "
        'reopen after sign-in, then try again.',
      ));
    }
  }

  Future<void> _onTeacherLogin(TeacherLoginRequested event, Emitter<LoginState> emit) async {
    final phone = normalizeLoginPhone(event.phone);
    if (phone.length < 10) {
      emit(LoginFailure('Enter your 10-digit phone number.'));
      return;
    }
    emit(LoginLoading());
    try {
      await _client.auth
          .signInWithPassword(
            email: '$phone@teacher.internal',
            password: event.password,
          )
          .timeout(const Duration(seconds: 20));
      // onAuthStateChange resolves the role from here.
    } catch (e) {
      emit(LoginFailure(describeSignInError(e,
          badCredentials: 'Incorrect phone number or password.')));
    }
  }

  Future<void> _onPasswordChangeCompleted(PasswordChangeCompleted event, Emitter<LoginState> emit) async {
    try {
      await _client.rpc('complete_password_change');
    } catch (_) {}
    final session = _client.auth.currentSession;
    if (session != null) await _resolveRole(session, emit);
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<LoginState> emit) async {
    _resolvedAuthUid = null;
    try {
      await _client.auth.signOut();
    } catch (_) {}
    emit(LoginInitial());
  }

  Future<void> _onAuthStateChanged(_AuthStateChanged event, Emitter<LoginState> emit) async {
    _oauthTimeout?.cancel();
    final session = event.session;
    if (session == null) {
      _resolvedAuthUid = null;
      if (state is! LoginFailure) emit(LoginInitial());
      return;
    }
    if (state is LoginSuccess && session.user.id == _resolvedAuthUid) return;
    emit(LoginLoading());
    await _resolveRole(session, emit);
  }

  Future<void> _resolveRole(Session session, Emitter<LoginState> emit) async {
    final uid = session.user.id;
    _resolvedAuthUid = uid;
    final email = session.user.email ?? '';
    try {
      // Admin and teacher are mutually exclusive lookups on the same uid, so
      // firing them together halves the round-trip latency versus checking
      // admin, then teacher, in sequence — same queries, same security
      // checks, just concurrent.
      final results = await Future.wait([
        _client
            .from('auth_admin')
            .select('name, is_active')
            .eq('auth_user_id', uid)
            .maybeSingle(),
        _client
            .from('teachers')
            .select('id, name, role, is_active, must_change_password')
            .eq('auth_user_id', uid)
            .maybeSingle(),
      ]);
      final admin = results[0];
      final teacher = results[1];
      if (admin != null) {
        if (admin['is_active'] != true) {
          await _client.auth.signOut();
          emit(LoginFailure('Your admin access has been disabled.'));
          return;
        }
        emit(LoginSuccess(models.User(
          id: uid,
          email: email,
          role: models.UserRole.admin,
          name: (admin['name'] as String?)?.isNotEmpty == true ? admin['name'] as String : null,
          mustChangePassword: await _adminNeedsPassword(),
        )));
        return;
      }

      if (teacher != null) {
        if (teacher['is_active'] != true) {
          await _client.auth.signOut();
          emit(LoginFailure('Your account has been deactivated. Contact your school admin.'));
          return;
        }
        // The librarian is staff and signs in here like any teacher; only
        // where they land differs (the router sends them to /library).
        emit(LoginSuccess(models.User(
          id: teacher['id'] as String,
          email: email,
          role: teacher['role'] == 'librarian' ? models.UserRole.librarian : models.UserRole.teacher,
          name: teacher['name'] as String?,
          mustChangePassword: teacher['must_change_password'] == true,
        )));
        return;
      }

      // The session is real but nothing claims it yet. That happens when the
      // school added the allowlist row *after* this person already had an
      // account — most often because they signed in with Google first. The
      // database links the row carrying their own verified email, and only
      // that row, so it is safe to offer before giving up.
      try {
        final claimed = await _client.rpc('claim_admin_access');
        if (claimed == true) {
          final row = await _client
              .from('auth_admin')
              .select('name, is_active')
              .eq('auth_user_id', uid)
              .maybeSingle();
          if (row != null && row['is_active'] == true) {
            emit(LoginSuccess(models.User(
              id: uid,
              email: email,
              role: models.UserRole.admin,
              name: (row['name'] as String?)?.isNotEmpty == true
                  ? row['name'] as String
                  : null,
              mustChangePassword: await _adminNeedsPassword(),
            )));
            return;
          }
        }
      } catch (_) {
        // Fall through to the plain refusal below.
      }

      await _client.auth.signOut();
      emit(LoginFailure('This account is not set up for PalliCore. '
          'Ask your school to add your email first.'));
    } catch (_) {
      _resolvedAuthUid = null;
      emit(LoginFailure("Signed in, but couldn't load your account. Check your "
          'internet connection and try again.'));
    }
  }

  /// An admin who has only ever used Google has no password, so email login
  /// can never work for them. Routing them through the set-password screen
  /// (via mustChangePassword) fixes that once. A failed check must never lock
  /// an admin out, so it counts as "has a password".
  Future<bool> _adminNeedsPassword() async {
    try {
      return await _client.rpc('admin_needs_password') == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    _oauthTimeout?.cancel();
    return super.close();
  }
}
