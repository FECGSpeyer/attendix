import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/user_language_repository.dart';
import '../../l10n/languages.dart';
import '../config/supabase_config.dart';

/// SharedPreferences key of the user's explicit choice (Ionic: localStorage
/// `appLanguage`).
const appLanguageStorageKey = 'appLanguage';

/// Device languages, e.g. ['de', 'en-US'] (Ionic navigator.languages).
List<String> deviceLanguages() {
  try {
    return PlatformDispatcher.instance.locales
        .map((l) => l.toLanguageTag())
        .toList();
  } catch (_) {
    return const [];
  }
}

/// Resolves the start language: stored choice -> device language -> 'de'.
/// Called in main() before runApp so the first frame is in the right language.
Future<String> loadInitialLanguage() async {
  String? stored;
  try {
    final prefs = await SharedPreferences.getInstance();
    stored = prefs.getString(appLanguageStorageKey);
  } catch (_) {
    // Storage can be unavailable (private mode) – fall back to the device.
  }
  return resolveLanguage(stored, deviceLanguages());
}

/// Language resolved in main(); overridden in the root ProviderScope.
/// Defaults to the device language (tests, previews).
final initialLanguageProvider = Provider<String>((ref) {
  return resolveLanguage(null, deviceLanguages());
});

/// Current UI language as [Locale] (`de` or `en`). Drives
/// `MaterialApp.locale`, `Intl.defaultLocale` and [currentLanguage].
final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

/// Ionic LocaleService: applies the language, stores an explicit choice and
/// keeps `notifications.language` on the account in sync.
class LocaleNotifier extends Notifier<Locale> {
  String? _syncedUserId;

  @override
  Locale build() {
    final lang = ref.watch(initialLanguageProvider);
    _apply(lang);

    // Ionic DbService: syncWithAccount(user.id) whenever a user is signed in.
    ref.listen(currentUserProvider, (_, next) {
      final userId = next.valueOrNull?.id;
      if (userId == null) {
        _syncedUserId = null;
        return;
      }
      if (userId == _syncedUserId) return;
      _syncedUserId = userId;
      syncWithAccount(userId);
    }, fireImmediately: true);

    return Locale(lang);
  }

  String get language => state.languageCode;

  /// Sets the language chosen by the user (settings picker). Unknown or not
  /// yet enabled languages fall back to German. Also saves it on the account.
  Future<String> setLanguage(String? value) async {
    final lang = normalizeLanguage(value);
    final next =
        lang != null && enabledLanguages.contains(lang) ? lang : defaultLanguage;
    await _store(next);
    _apply(next);
    state = Locale(next);

    final userId = _currentUserId();
    if (userId != null) await saveToAccount(userId, next);
    return next;
  }

  /// A choice made on this device is written to the account, otherwise a
  /// choice from another device is applied here.
  Future<void> syncWithAccount(String userId) async {
    try {
      final repo = ref.read(userLanguageRepositoryProvider);
      final account = await repo.getAccountLanguage(userId);
      final accountLang = normalizeLanguage(account.language);
      final stored = normalizeLanguage(await _readStored());
      if (stored != null) {
        if (account.hasRow && accountLang != stored) {
          await saveToAccount(userId, stored);
        }
        return;
      }
      if (accountLang != null &&
          enabledLanguages.contains(accountLang) &&
          accountLang != language) {
        await _store(accountLang);
        _apply(accountLang);
        state = Locale(accountLang);
      }
    } catch (e) {
      debugPrint('Sprache konnte nicht abgeglichen werden: $e');
    }
  }

  /// Stores the language on the account so server messages use it too.
  Future<void> saveToAccount(String userId, String lang) async {
    try {
      await ref
          .read(userLanguageRepositoryProvider)
          .saveAccountLanguage(userId, lang);
    } catch (e) {
      debugPrint('Sprache konnte nicht gespeichert werden: $e');
    }
  }

  void _apply(String lang) {
    setActiveLanguage(lang);
    Intl.defaultLocale = intlLocales[lang];
  }

  String? _currentUserId() {
    try {
      return ref.read(currentUserProvider).valueOrNull?.id ??
          ref.read(supabaseAuthProvider).currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readStored() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(appLanguageStorageKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _store(String lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(appLanguageStorageKey, lang);
    } catch (_) {
      // Storage can be unavailable (private mode); the choice still applies.
    }
  }
}
