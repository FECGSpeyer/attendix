import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/features/team_organization/presentation/widgets/task_form_sheet.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final beta in [false, true]) {
    testWidgets('Neue Aufgabe öffnet ohne Person (beta=$beta)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [playersProvider.overrideWith((ref) async => [])],
          child: MaterialApp(
            theme: beta ? buildRdTheme(RdFarbwelt.values.first, Brightness.light) : AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('de'),
            home: Builder(
              builder:
                  (c) => Scaffold(body: TextButton(onPressed: () => showTaskFormSheet(c), child: const Text('go'))),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Neue Aufgabe'), findsOneWidget);
    });
  }
}
