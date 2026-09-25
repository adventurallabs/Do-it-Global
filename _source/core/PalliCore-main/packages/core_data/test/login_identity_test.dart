import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:core_data/core_data.dart';

void main() {
  // Must stay in step with normalize_login_phone() in the database and
  // normalizeLoginPhone() in the admin-create-teacher Edge Function.
  group('normalizeLoginPhone', () {
    test('keeps a plain 10-digit number', () {
      expect(normalizeLoginPhone('9876543210'), '9876543210');
      expect(normalizeLoginPhone('0101010101'), '0101010101');
    });
    test('drops spaces, dashes and a +91 / 0 prefix', () {
      expect(normalizeLoginPhone(' 98765 43210 '), '9876543210');
      expect(normalizeLoginPhone('+91 98765-43210'), '9876543210');
      expect(normalizeLoginPhone('919876543210'), '9876543210');
      expect(normalizeLoginPhone('09876543210'), '9876543210');
    });
  });

  group('describeSignInError', () {
    const bad = 'wrong password';
    test('only a credentials rejection reads as a wrong password', () {
      expect(
        describeSignInError(
            const AuthApiException('Invalid login credentials',
                statusCode: '400', code: 'invalid_credentials'),
            badCredentials: bad),
        bad,
      );
    });
    test('a missing API key is not reported as a wrong password', () {
      final msg = describeSignInError(
          const AuthApiException('No API key found in request', statusCode: '401'),
          badCredentials: bad);
      expect(msg, isNot(bad));
      expect(msg, contains('API key'));
    });
    test('network failures are not reported as a wrong password', () {
      expect(describeSignInError(AuthRetryableFetchException(message: 'SocketException'),
          badCredentials: bad), isNot(bad));
      expect(describeSignInError(TimeoutException('slow'), badCredentials: bad), isNot(bad));
    });
  });
}
