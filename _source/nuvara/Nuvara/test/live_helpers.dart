// Seeded accounts and sign-in for the live test suite (test/live_test.dart). Test-only: none of this ships in the app.
import 'package:nuvara/models.dart';
import 'package:nuvara/store.dart';

class TestAccount {
  /// What the person types to sign in: email (admin), mobile number (therapist) or child ID (parent).
  final String name, login, label;
  const TestAccount(this.name, this.login, this.label);
}

/// The seeded accounts' password, from `--dart-define-from-file=.env`.
const testPassword = String.fromEnvironment('TEST_PASSWORD');
const testAccounts = {
  Role.admin: TestAccount('Lakshmi Narayanan', 'admin@nuvara.test', 'Centre admin'),
  Role.therapist: TestAccount('Priya Raman', '98400 11001', 'Occupational Therapist'),
  Role.parent: TestAccount('Neha Sharma', 'C001', 'Parent of Aarav'),
};

extension LiveSignIn on AppStore {
  /// Signs in as the seeded account for [r].
  Future<void> signInAs(Role r) => signIn(r, testAccounts[r]!.login, testPassword);
}
