// Sol review (PR #299): a popover menu opened at a trigger near the bottom
// edge flips above it and stays fully visible (all entries reachable).
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('menu at a bottom trigger stays on screen ($platform)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.forPlatform(Brightness.light, platform)
            .copyWith(platform: platform),
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: Builder(
              builder: (bc) => IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () => showAppPopoverMenu<int>(
                  context: bc,
                  items: [
                    for (var i = 0; i < 7; i++)
                      AppPopoverMenuItem(value: i, label: 'Eintrag $i'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      final screen = tester.getRect(find.byType(Scaffold));
      final trigger = tester.getRect(find.byType(IconButton));
      final last = tester.getRect(find.text('Eintrag 6'));
      expect(last.bottom, lessThanOrEqualTo(screen.bottom));
      expect(last.bottom, lessThanOrEqualTo(trigger.bottom));
      expect(tester.getRect(find.text('Eintrag 0')).top,
          greaterThanOrEqualTo(screen.top));
    });
  }
}
