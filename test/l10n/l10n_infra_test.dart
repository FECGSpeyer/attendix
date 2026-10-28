import 'dart:convert';
import 'dart:io';

import 'package:attendix/core/providers/locale_provider.dart';
import 'package:attendix/features/settings/presentation/widgets/language_picker_tile.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/i18n/build_arb.dart' as build_arb;

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('build_arb key mapping', () {
    test('dotted Ionic keys map to lowerCamelCase', () {
      expect(build_arb.toArbKey('settings.language.title'),
          'settingsLanguageTitle');
      expect(build_arb.toArbKey('common.status.lateExcused'),
          'commonStatusLateExcused');
    });

    test('`#` in plural branches becomes the selector placeholder', () {
      final msg = build_arb
          .convertMessage('{count, plural, one {# Person} other {# Personen}}');
      expect(msg.text,
          '{count, plural, one {{count} Person} other {{count} Personen}}');
      expect(msg.placeholders, {'count': true});
    });

    test('simple placeholders are collected, # outside plurals kept', () {
      final msg = build_arb.convertMessage('Nr. # von {name}');
      expect(msg.text, 'Nr. # von {name}');
      expect(msg.placeholders, {'name': false});
    });
  });

  group('ARB files', () {
    test('de and en have the same keys', () {
      final de = _arb('de').keys.where((k) => !k.startsWith('@')).toSet();
      final en = _arb('en').keys.where((k) => !k.startsWith('@')).toSet();
      expect(en.difference(de), isEmpty);
      expect(de.difference(en), isEmpty);
    });

    test('every de entry records its Ionic key', () {
      final de = _arb('de');
      for (final key in de.keys.where((k) => !k.startsWith('@'))) {
        final meta = de['@$key'] as Map<String, dynamic>?;
        expect(meta?['description'], isA<String>(), reason: key);
        expect(build_arb.toArbKey(meta!['description'] as String), key);
      }
    });

    test('generated Dart is in sync with the ARB (run flutter gen-l10n)', () {
      final generated =
          File('lib/l10n/generated/app_localizations_de.dart').readAsStringSync();
      final de = _arb('de');
      for (final key in de.keys.where((k) => !k.startsWith('@'))) {
        expect(generated, contains(' $key'), reason: key);
      }
    });
  });

  group('context.l10n', () {
    testWidgets('falls back to German without delegates', (tester) async {
      late String label;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
        label = context.l10n.tabsMore;
        return const SizedBox();
      })));
      expect(label, 'Mehr');
    });

    testWidgets('language picker switches the app to English',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(ProviderScope(
        overrides: [initialLanguageProvider.overrideWithValue('de')],
        child: Consumer(builder: (context, ref, _) {
          return MaterialApp(
            locale: ref.watch(localeProvider),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(children: [
                  Text(context.l10n.settingsLogout),
                  const LanguagePickerTile(),
                ]),
              ),
            ),
          );
        }),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Ausloggen'), findsOneWidget);
      expect(find.text('Sprache'), findsOneWidget);
      expect(find.text('NEU'), findsOneWidget);

      await tester.tap(find.byKey(const Key('languagePicker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();

      expect(find.text('Log out'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      setActiveLanguage('de');
    });
  });
}
