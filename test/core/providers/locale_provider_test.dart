import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/locale_provider.dart';
import 'package:attendix/data/repositories/user_language_repository.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/auth_test_helpers.dart';

/// In-memory stand-in for the `notifications.language` column.
class FakeUserLanguageRepository extends UserLanguageRepository {
  FakeUserLanguageRepository(super.ref, {this.hasRow = true, this.language});

  bool hasRow;
  String? language;
  final saved = <String>[];

  @override
  Future<({bool hasRow, String? language})> getAccountLanguage(
      String userId) async {
    return (hasRow: hasRow, language: language);
  }

  @override
  Future<void> saveAccountLanguage(String userId, String language) async {
    saved.add(language);
    this.language = language;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeUserLanguageRepository repo;

  ProviderContainer makeContainer({
    String initial = 'de',
    User? user,
    bool hasRow = true,
    String? accountLanguage,
  }) {
    final container = ProviderContainer(overrides: [
      initialLanguageProvider.overrideWithValue(initial),
      currentUserProvider.overrideWith((ref) => Stream.value(user)),
      userLanguageRepositoryProvider.overrideWith((ref) {
        return repo = FakeUserLanguageRepository(ref,
            hasRow: hasRow, language: accountLanguage);
      }),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setActiveLanguage('de');
    Intl.defaultLocale = null;
  });

  group('localeProvider', () {
    test('starts with the initial language and applies intl locale', () {
      final container = makeContainer(initial: 'de');
      expect(container.read(localeProvider), const Locale('de'));
      expect(currentLanguage(), 'de');
      expect(Intl.defaultLocale, 'de_DE');
    });

    test('setLanguage stores the choice and switches to en_GB formats',
        () async {
      final container = makeContainer();
      await container.read(localeProvider.notifier).setLanguage('en-US');

      expect(container.read(localeProvider), const Locale('en'));
      expect(Intl.defaultLocale, 'en_GB');
      expect(dateFmt(), 'dd/MM/yyyy');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(appLanguageStorageKey), 'en');
    });

    test('setLanguage falls back to German for disabled languages', () async {
      final container = makeContainer(initial: 'en');
      final result =
          await container.read(localeProvider.notifier).setLanguage('ru');
      expect(result, 'de');
      expect(container.read(localeProvider), const Locale('de'));
    });

    test('setLanguage saves to notifications.language when signed in',
        () async {
      final container = makeContainer(user: TestAuth.createTestUser());
      container.read(localeProvider);
      await settle();
      await container.read(localeProvider.notifier).setLanguage('en');
      expect(repo.saved, contains('en'));
    });
  });

  group('syncWithAccount (Ionic LocaleService)', () {
    test('applies the account language when nothing is stored', () async {
      final container = makeContainer(
          user: TestAuth.createTestUser(), accountLanguage: 'en');
      container.read(localeProvider);
      await settle();
      await settle();
      expect(container.read(localeProvider), const Locale('en'));
      expect(repo.saved, isEmpty);
    });

    test('writes a stored device choice to the account', () async {
      SharedPreferences.setMockInitialValues({appLanguageStorageKey: 'de'});
      final container = makeContainer(
          user: TestAuth.createTestUser(), accountLanguage: 'en');
      container.read(localeProvider);
      await settle();
      await settle();
      expect(container.read(localeProvider), const Locale('de'));
      expect(repo.saved, ['de']);
    });

    test('does not write when the user has no notifications row', () async {
      SharedPreferences.setMockInitialValues({appLanguageStorageKey: 'en'});
      final container = makeContainer(
          initial: 'en', user: TestAuth.createTestUser(), hasRow: false);
      container.read(localeProvider);
      await settle();
      await settle();
      expect(repo.saved, isEmpty);
    });
  });

  group('languages.dart', () {
    test('resolveLanguage: stored -> device -> de', () {
      expect(resolveLanguage('en', ['de-DE']), 'en');
      expect(resolveLanguage(null, ['fr-FR', 'en-US']), 'en');
      expect(resolveLanguage(null, ['ru-RU']), 'de'); // ru not enabled
      expect(resolveLanguage('xx', []), 'de');
    });

    test('normalizeLanguage maps tags to base languages', () {
      expect(normalizeLanguage('en_GB'), 'en');
      expect(normalizeLanguage(' ES '), 'es');
      expect(normalizeLanguage('fr'), isNull);
      expect(normalizeLanguage(null), isNull);
    });
  });
}
