import 'package:attendix/core/theme/app_palette.dart';
import 'package:attendix/core/theme/design_theme.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/adaptive/app_action_sheet.dart';
import 'package:attendix/shared/widgets/adaptive/app_dialog.dart';
import 'package:attendix/shared/widgets/adaptive/app_segmented_button.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _theme() => buildRdTheme(RdFarbwelt.nachtblau, Brightness.light).copyWith(platform: TargetPlatform.iOS);

Widget _app(Widget home) => MaterialApp(
      theme: _theme(),
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

Widget _dialog() => AppAlertDialog(
      title: const Text('Löschen?'),
      actions: [
        TextButton(onPressed: () {}, child: const Text('Abbrechen')),
        TextButton(onPressed: () {}, child: const Text('Ja')),
      ],
    );

void main() {
  test('buildRdTheme attaches RdTokens', () {
    expect(_theme().extension<RdTokens>(), isNotNull);
  });

  testWidgets('list header renders uppercase group label', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(body: IonListHeader('Allgemein'))));
    expect(find.text('ALLGEMEIN'), findsOneWidget);
  });

  testWidgets('inset list uses Farbwelt surface and list radius', (tester) async {
    await tester.pumpWidget(
      _app(Scaffold(body: IonInsetList(children: [IonItem(title: const Text('A'), onTap: () {}, detail: true)]))),
    );
    final p = rdPalette(RdFarbwelt.nachtblau, Brightness.light);
    final box = tester.widget<Container>(find.descendant(of: find.byType(IonInsetList), matching: find.byType(Container)).first);
    final deco = box.decoration! as BoxDecoration;
    expect(deco.color, p.surface);
    expect(deco.borderRadius, BorderRadius.circular(p.listRadius));
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('alert uses filled primary and outlined cancel buttons', (tester) async {
    await tester.pumpWidget(_app(Scaffold(body: _dialog())));
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('action sheet renders grouped rows and outlined cancel', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(_app(Builder(builder: (c) {
      ctx = c;
      return const Scaffold();
    })));
    showAppActionSheet<int>(ctx, title: 'Termin', actions: const [
      AppActionSheetAction(label: 'Löschen', value: 1, icon: Icons.delete_outline, destructive: true),
    ]);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Löschen'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Abbrechen'), findsOneWidget);
  });

  testWidgets('segments stay keyboard-focusable', (tester) async {
    var picked = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: AppSegmentedButton<int>(
        segments: const [ButtonSegment(value: 0, label: Text('PDF')), ButtonSegment(value: 1, label: Text('Excel'))],
        selected: const {0},
        onSelectionChanged: (v) => picked = v.first,
      ),
    )));
    expect(find.ancestor(of: find.text('Excel'), matching: find.byType(InkWell)), findsOneWidget);
    await tester.tap(find.text('Excel'));
    expect(picked, 1);

    picked = -1;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(picked, isNot(-1));
  });

  testWidgets('locked switches look locked', (tester) async {
    final theme = _theme();
    final track = theme.switchTheme.trackColor!;
    expect(track.resolve({WidgetState.selected, WidgetState.disabled})!.a, lessThan(track.resolve({WidgetState.selected})!.a));
  });
}
