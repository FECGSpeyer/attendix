import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'saved_account.dart';

/// ACCOUNT_SWITCH: where the remembered accounts (with their refresh
/// tokens) live on this device.
abstract class SavedAccountsStore {
  Future<List<SavedAccount>> load();
  Future<void> save(List<SavedAccount> accounts);
}

const _storageKey = 'account_switch.accounts';

/// Marker in SharedPreferences: the secure store was written by this app
/// installation. The iOS keychain survives uninstalling the app, the
/// SharedPreferences do not – without the marker a reinstall would bring
/// back the accounts of the old installation.
const _installMarkerKey = 'account_switch.installed';

List<SavedAccount> decodeSavedAccounts(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final list = jsonDecode(raw);
    if (list is! List) return const [];
    return list.map(SavedAccount.fromJson).whereType<SavedAccount>().toList();
  } catch (_) {
    return const [];
  }
}

String encodeSavedAccounts(List<SavedAccount> accounts) =>
    jsonEncode([for (final a in accounts) a.toJson()]);

/// iOS / Android: keychain / keystore.
class SecureSavedAccountsStore implements SavedAccountsStore {
  SecureSavedAccountsStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<List<SavedAccount>> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_installMarkerKey) != true) {
      // Fresh installation: forget what an earlier one left behind.
      try {
        await _storage.delete(key: _storageKey);
      } catch (_) {}
      return const [];
    }
    return decodeSavedAccounts(await _storage.read(key: _storageKey));
  }

  @override
  Future<void> save(List<SavedAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    if (accounts.isEmpty) {
      await _storage.delete(key: _storageKey);
      return;
    }
    await _storage.write(key: _storageKey, value: encodeSavedAccounts(accounts));
    await prefs.setBool(_installMarkerKey, true);
  }
}

/// Web and desktop: SharedPreferences (in the browser: localStorage) – the
/// same place where Supabase already keeps the session of the signed-in
/// account on these platforms.
class PrefsSavedAccountsStore implements SavedAccountsStore {
  @override
  Future<List<SavedAccount>> load() async {
    final prefs = await SharedPreferences.getInstance();
    // In the browser another tab may have changed the list.
    try {
      await prefs.reload();
    } catch (_) {}
    return decodeSavedAccounts(prefs.getString(_storageKey));
  }

  @override
  Future<void> save(List<SavedAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    if (accounts.isEmpty) {
      await prefs.remove(_storageKey);
    } else {
      await prefs.setString(_storageKey, encodeSavedAccounts(accounts));
    }
  }
}

/// Keychain where the platform has a sandboxed one without extra
/// entitlements (iOS, Android), SharedPreferences elsewhere.
SavedAccountsStore createSavedAccountsStore() {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android)) {
    return SecureSavedAccountsStore();
  }
  return PrefsSavedAccountsStore();
}

/// Tests.
class InMemorySavedAccountsStore implements SavedAccountsStore {
  InMemorySavedAccountsStore([List<SavedAccount> initial = const []])
      : accounts = List.of(initial);

  List<SavedAccount> accounts;
  int saves = 0;

  @override
  Future<List<SavedAccount>> load() async => List.of(accounts);

  @override
  Future<void> save(List<SavedAccount> accounts) async {
    saves++;
    this.accounts = List.of(accounts);
  }
}
