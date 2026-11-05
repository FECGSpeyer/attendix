// Sol review (PR #299): popover menu entries are reachable from the
// keyboard (Tab + Enter/Space), Escape closes, nested menus keep working.
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String?> results;
  late List<String> subTaps;
  late List<bool> flags;

  Future<void> pumpMenu(WidgetTester tester, TargetPlatform platform) async {
    results = [];
    subTaps = [];
    flags = [false, false];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.forPlatform(Brightness.light, platform)
          .copyWith(platform: platform),
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (bc) => IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () async {
                results.add(await showAppPopoverMenu<String>(
                  context: bc,
                  items: [
                    const AppPopoverMenuItem(value: 'share', label: 'Teilen'),
                    AppPopoverMenuItem(
                      value: 'filter',
                      label: 'Filter',
                      submenuItems: () => [
                        AppPopoverSubItem(
                          label: 'Nur aktive',
                          onTap: () => subTaps.add('aktiv'),
                        ),
                        for (var i = 0; i < 2; i++)
                          AppPopoverSubItem(
                            label: 'Option $i',
                            checked: flags[i],
                            onTap: () => flags[i] = !flags[i],
                          ),
                      ],
                    ),
                    const AppPopoverMenuItem(value: 'delete', label: 'Löschen'),
                  ],
                ));
              },
            ),
          ),
        ),
      ),
    ));
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('Tab + Enter triggers the first entry ($platform)',
        (tester) async {
      await pumpMenu(tester, platform);
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      await key(tester, LogicalKeyboardKey.tab);
      await key(tester, LogicalKeyboardKey.enter);

      expect(results, ['share']);
      expect(find.text('Teilen'), findsNothing);
    });

    testWidgets('Escape closes the menu ($platform)', (tester) async {
      await pumpMenu(tester, platform);
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      await key(tester, LogicalKeyboardKey.escape);

      expect(results, [null]);
      expect(find.text('Teilen'), findsNothing);
    });
  }

  testWidgets('opened from the keyboard: first entry focused, nested menu '
      'per keyboard, Escape closes the nested menu first', (tester) async {
    await pumpMenu(tester, TargetPlatform.android);

    // Focus the trigger and open the menu with Enter.
    await key(tester, LogicalKeyboardKey.tab);
    await key(tester, LogicalKeyboardKey.enter);
    expect(find.text('Teilen'), findsOneWidget);

    // First entry has the focus: arrow down → "Filter", Enter opens nested.
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.enter);
    expect(find.text('Nur aktive'), findsOneWidget);

    // Its first entry has the focus: Space triggers it, menu stays open.
    await key(tester, LogicalKeyboardKey.space);
    expect(subTaps, ['aktiv']);
    expect(find.text('Nur aktive'), findsOneWidget);

    // Entries with a (decorative) checkbox: the row toggles per Space/Enter
    // and Tab never lands on the checkbox itself (there Enter/Space would
    // only hit its no-op onChanged).
    Iterable<bool?> boxes() =>
        tester.widgetList<Checkbox>(find.byType(Checkbox)).map((c) => c.value);
    bool focusOnCheckbox() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<Checkbox>() !=
        null;
    expect(boxes(), [false, false]);
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(focusOnCheckbox(), isFalse);
    await key(tester, LogicalKeyboardKey.space);
    expect(flags, [true, false]);
    expect(boxes(), [true, false]);
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.enter);
    expect(flags, [true, true]);
    expect(boxes(), [true, true]);
    for (var i = 0; i < 6; i++) {
      await key(tester, LogicalKeyboardKey.tab);
      expect(focusOnCheckbox(), isFalse, reason: 'Tab #$i focused a checkbox');
    }
    // Back on the first entry of the nested popover for the steps below.
    await key(tester, LogicalKeyboardKey.escape);
    await key(tester, LogicalKeyboardKey.enter);
    expect(find.text('Nur aktive'), findsOneWidget);

    // Escape: nested closes, focus back on "Filter" (Enter reopens it).
    await key(tester, LogicalKeyboardKey.escape);
    expect(find.text('Nur aktive'), findsNothing);
    expect(find.text('Filter'), findsOneWidget);
    await key(tester, LogicalKeyboardKey.enter);
    expect(find.text('Nur aktive'), findsOneWidget);

    await key(tester, LogicalKeyboardKey.escape);
    await key(tester, LogicalKeyboardKey.escape);
    expect(find.text('Filter'), findsNothing);
    expect(results, [null]);
  });
}
