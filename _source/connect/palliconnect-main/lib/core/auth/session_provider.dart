import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_service.dart';
import '../data/parent_repository.dart';
import '../../shared/models/school.dart';
import '../../shared/models/student.dart';
import 'account_store.dart';

enum SessionStatus {
  /// Still checking for a persisted session — show the splash screen.
  unknown,
  signedOut,
  needsPasswordChange,
  ready,
  /// Signed in, but the register-number/child data couldn't be loaded
  /// (offline, server unreachable). Never falls back to placeholder data.
  error,
}

class SessionState {
  final SessionStatus status;
  final Student? currentStudent;
  final School? currentSchool;
  final List<Student> allStudents;
  final DateTime lastSyncedAt;
  final String? errorMessage;

  SessionState({
    this.status = SessionStatus.unknown,
    this.currentStudent,
    this.currentSchool,
    this.allStudents = const [],
    DateTime? lastSyncedAt,
    this.errorMessage,
  }) : lastSyncedAt = lastSyncedAt ?? DateTime.now();

  SessionState copyWith({
    SessionStatus? status,
    Student? currentStudent,
    School? currentSchool,
    List<Student>? allStudents,
    DateTime? lastSyncedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SessionState(
      status: status ?? this.status,
      currentStudent: currentStudent ?? this.currentStudent,
      currentSchool: currentSchool ?? this.currentSchool,
      allStudents: allStudents ?? this.allStudents,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Real Supabase Auth is the only source of truth here — there is no demo
/// fallback. A signed-out or unreachable app shows its own screen; it never
/// substitutes placeholder data.
class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier({ParentRepository? repository})
      : _repository = repository ?? ParentRepository.create(),
        super(SessionState()) {
    if (SupabaseService.isReady) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        _handleAuthChange(data.event, data.session);
      });
    }
  }

  final ParentRepository _repository;
  StreamSubscription<AuthState>? _authSub;

  /// The auth user the current `ready` state was loaded for.
  String? _resolvedAuthUid;

  /// Called once from the splash screen. Resolves instantly if a session was
  /// already restored by supabase_flutter; the auth-state listener above
  /// covers every later change (login, logout, token refresh).
  Future<void> bootstrap() async {
    if (!SupabaseService.isReady) {
      state = state.copyWith(
        status: SessionStatus.error,
        errorMessage: "Can't reach the school's server. Check your connection and try again.",
      );
      return;
    }
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      state = state.copyWith(status: SessionStatus.signedOut);
      return;
    }
    await _resolve();
  }

  Future<void> _handleAuthChange(AuthChangeEvent event, Session? session) async {
    if (session == null) {
      _resolvedAuthUid = null;
      state = SessionState(status: SessionStatus.signedOut);
      return;
    }
    // Hourly token refreshes and app-resume re-announcements carry the same
    // user. Re-running the whole bootstrap for them only risks swapping a
    // working parent onto the connection-error screen over a network blip.
    if (state.status == SessionStatus.ready && session.user.id == _resolvedAuthUid) return;
    await _resolve();
  }

  Future<void> _resolve() async {
    try {
      final account = await _repository.myParentAccount();
      if (account == null || account['is_active'] != true) {
        await Supabase.instance.client.auth.signOut();
        state = SessionState(
          status: SessionStatus.signedOut,
          errorMessage: 'This account is not set up for PalliConnect.',
        );
        return;
      }
      if (account['must_change_password'] == true) {
        state = state.copyWith(status: SessionStatus.needsPasswordChange, clearError: true);
        return;
      }
      final result = await _repository.bootstrap();
      _resolvedAuthUid = Supabase.instance.client.auth.currentUser?.id;
      state = state.copyWith(
        status: SessionStatus.ready,
        allStudents: result.students,
        currentStudent: result.students.isNotEmpty ? result.students.first : null,
        currentSchool: result.school,
        lastSyncedAt: DateTime.now(),
        clearError: true,
      );
      // Remember this login on-device so the child switcher can return to it
      // later without asking for the password again.
      final refreshToken = Supabase.instance.client.auth.currentSession?.refreshToken;
      final student = result.students.isNotEmpty ? result.students.first : null;
      if (refreshToken != null && student != null) {
        final registerNumber = (account['register_number'] as String?) ?? student.admissionNo;
        AccountStore.upsert(SavedAccount(
          registerNumber: registerNumber,
          studentName: student.fullName,
          refreshToken: refreshToken,
        ));
      }
    } catch (_) {
      state = state.copyWith(
        status: SessionStatus.error,
        errorMessage: "Can't reach the school's server. Check your connection and try again.",
      );
    }
  }

  /// Returns an error message on failure, or null on success (the auth-state
  /// listener resolves the rest).
  Future<String?> signIn(String registerNumber, String password) async {
    final reg = registerNumber.trim();
    if (reg.isEmpty || password.isEmpty) return 'Enter your register number and password.';
    if (!SupabaseService.isReady) {
      return "This copy of the app can't reach the school server. "
          'Install the latest version of the app.';
    }
    try {
      await Supabase.instance.client.auth
          .signInWithPassword(email: '$reg@parent.internal', password: password)
          .timeout(const Duration(seconds: 20));
      return null;
    } catch (e) {
      return _describeSignInError(e);
    }
  }

  /// Only a real credentials rejection means a wrong password. A network
  /// drop or a build missing its API key used to show the same message and
  /// sent parents retyping a password that was right all along.
  static String _describeSignInError(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (error.code == 'invalid_credentials' ||
          message.contains('invalid login credentials')) {
        return 'Incorrect register number or password.';
      }
      if (error.statusCode == '401' || message.contains('api key')) {
        return "This copy of the app can't reach the school server. "
            'Install the latest version of the app.';
      }
      if (error.statusCode == '429' || message.contains('rate limit')) {
        return 'Too many attempts. Wait a minute, then try again.';
      }
      if (error is! AuthRetryableFetchException) return error.message;
    }
    return "Can't reach the school's server. Check your connection and try again.";
  }

  Future<String?> completePasswordChange(String newPassword) async {
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      return 'Could not update your password: $e';
    }
    try {
      await Supabase.instance.client.rpc('complete_password_change');
    } catch (_) {}
    await _resolve();
    return null;
  }

  /// Signs out of the *active* session only — saved accounts on this device
  /// (for the child switcher) are untouched, matching an Instagram-style
  /// "log out" that still remembers the other accounts to switch back to.
  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }

  Future<List<SavedAccount>> savedAccounts() => AccountStore.list();

  /// Swaps to a previously-saved login without re-entering a password.
  /// Returns an error message if that saved session is no longer valid (its
  /// refresh token was already rotated/expired) — the caller should then
  /// remove it and prompt for the password again.
  Future<String?> switchToAccount(SavedAccount account) async {
    try {
      await Supabase.instance.client.auth.setSession(account.refreshToken);
      return null; // the auth-state listener resolves the rest
    } catch (_) {
      await AccountStore.remove(account.registerNumber);
      return 'That saved login has expired. Sign in again with the password.';
    }
  }

  Future<void> forgetAccount(String registerNumber) => AccountStore.remove(registerNumber);

  void selectStudent(Student student) {
    state = state.copyWith(currentStudent: student);
  }

  Future<void> refresh() async {
    if (state.status != SessionStatus.ready) return;
    await _resolve();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});

final currentStudentProvider = Provider((ref) => ref.watch(sessionProvider).currentStudent);
final currentSchoolProvider = Provider((ref) => ref.watch(sessionProvider).currentSchool);
final allStudentsProvider = Provider((ref) => ref.watch(sessionProvider).allStudents);

Color parseSchoolAccent(String hex, Color fallback) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return fallback;
  }
}
