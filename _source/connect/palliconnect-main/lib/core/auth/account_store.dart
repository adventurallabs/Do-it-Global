import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One saved login on this device — enough to switch back to it without
/// re-entering a password ("Instagram-style" account switching). PalliConnect
/// never runs multiple live Supabase sessions at once; switching swaps which
/// refresh token is active via `auth.setSession()`.
class SavedAccount {
  final String registerNumber;
  final String studentName;
  final String refreshToken;

  const SavedAccount({
    required this.registerNumber,
    required this.studentName,
    required this.refreshToken,
  });

  Map<String, dynamic> toJson() => {
        'registerNumber': registerNumber,
        'studentName': studentName,
        'refreshToken': refreshToken,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
        registerNumber: json['registerNumber'] as String,
        studentName: json['studentName'] as String,
        refreshToken: json['refreshToken'] as String,
      );
}

/// Backed by the platform keystore/keychain via flutter_secure_storage —
/// private to this device, never synced or sent anywhere by PalliConnect.
class AccountStore {
  AccountStore._();
  static const _key = 'palliconnect_saved_accounts';
  static const _storage = FlutterSecureStorage();

  static Future<List<SavedAccount>> list() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((m) => SavedAccount.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Adds or updates the entry for [account.registerNumber].
  static Future<void> upsert(SavedAccount account) async {
    final accounts = await list();
    final next = [
      for (final a in accounts)
        if (a.registerNumber != account.registerNumber) a,
      account,
    ];
    await _write(next);
  }

  static Future<void> remove(String registerNumber) async {
    final accounts = await list();
    await _write(accounts.where((a) => a.registerNumber != registerNumber).toList());
  }

  static Future<void> _write(List<SavedAccount> accounts) {
    return _storage.write(key: _key, value: jsonEncode(accounts.map((a) => a.toJson()).toList()));
  }
}
