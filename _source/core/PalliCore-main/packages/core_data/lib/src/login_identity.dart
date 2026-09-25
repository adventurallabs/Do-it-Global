import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// The one phone rule for teacher logins: digits only, a +91 / 0 trunk prefix
/// dropped. A teacher signs in as `<phone>@teacher.internal`, so this must
/// match `normalizeLoginPhone()` in the admin-create-teacher Edge Function and
/// `normalize_login_phone()` in the database — otherwise "98765 43210" typed
/// at login and "9876543210" stored at creation are two different accounts.
String normalizeLoginPhone(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('91')) return d.substring(2);
  if (d.length == 11 && d.startsWith('0')) return d.substring(1);
  return d;
}

/// Turns a failed `signInWithPassword` into a sentence the person can act
/// on. Only a real credentials rejection is reported as a wrong password —
/// a network drop or a build shipped without its API key used to show the
/// same "incorrect password" message, which sent people retyping a password
/// that was right all along.
String describeSignInError(Object error, {required String badCredentials}) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (error.code == 'invalid_credentials' ||
        message.contains('invalid login credentials')) {
      return badCredentials;
    }
    if (error.statusCode == '401' || message.contains('api key')) {
      return 'This copy of the app cannot reach the school server (missing '
          'API key). Install the latest version of the app.';
    }
    if (error.statusCode == '429' || message.contains('rate limit')) {
      return 'Too many attempts. Wait a minute, then try again.';
    }
    if (message.contains('email not confirmed')) {
      return 'This login has not been activated yet. Ask your school admin.';
    }
    if (error is AuthRetryableFetchException) {
      return "Can't reach the school server. Check your internet connection "
          'and try again.';
    }
    return error.message;
  }
  if (error is TimeoutException) {
    return "The school server didn't respond. Check your internet connection "
        'and try again.';
  }
  return "Can't reach the school server. Check your internet connection and "
      'try again.';
}
