// Beta-Skin: the old (Ionic) building blocks draw the new design while the
// Beta theme is active and keep the Ionic look without it.
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/adaptive/app_action_sheet.dart';
import 'package:attendix/shared/widgets/adaptive/app_dialog.dart';
import 'package:attendix/shared/widgets/adaptive/app_segmented_button.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _beta() => buildRdTheme(RdFarbwelt.nachtblau, Brightness.light).copyWith(platform: TargetPlatform.iOS);
ThemeData _ionic() => AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS, web: false);

Widget _app(ThemeData theme, Widget home) => MaterialApp(
      theme: theme,
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
  test('rdSkin is set only by the Beta theme', () {
    expect(_beta().extension<RdTokens>(), isNotNull);
    expect(_ionic().extension<RdTokens>(), isNull);
  });

  testWidgets('list header: uppercase group label in the Beta', (tester) async {
    await tester.pumpWidget(_app(_beta(), const Scaffold(body: IonListHeader('Allgemein'))));
    expect(find.text('ALLGEMEIN'), findsOneWidget);
    await tester.pumpWidget(_app(_ionic(), const Scaffold(body: IonListHeader('Allgemein'))));
    await tester.pump(const Duration(seconds: 1)); // theme animation
    expect(find.text('Allgemein'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('inset list: Farbwelt surface and list radius in the Beta', (tester) async {
    await tester.pumpWidget(_app(_beta(), Scaffold(body: IonInsetList(children: [IonItem(title: const Text('A'), onTap: () {}, detail: true)]))));
    final p = rdPalette(RdFarbwelt.nachtblau, Brightness.light);
    final box = tester.widget<Container>(find.descendant(of: find.byType(IonInsetList), matching: find.byType(Container)).first);
    final deco = box.decoration! as BoxDecoration;
    expect(deco.color, p.surface);
    expect(deco.borderRadius, BorderRadius.circular(p.listRadius));
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('alert: new-design buttons in the Beta, iOS pills without', (tester) async {
    await tester.pumpWidget(_app(_beta(), Scaffold(body: _dialog())));
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(IosAlertButton), findsNothing);
    await tester.pumpWidget(_app(_ionic(), Scaffold(body: _dialog())));
    await tester.pump(const Duration(seconds: 1)); // theme animation
    expect(find.byType(IosAlertButton), findsNWidgets(2));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('action sheet: grouped rows and outlined cancel in the Beta', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(_app(_beta(), Builder(builder: (c) {
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
    expect(find.byType(IosAlertButton), findsNothing);
  });

  testWidgets('segments stay keyboard-focusable in the Beta', (tester) async {
    var picked = 0;
    await tester.pumpWidget(_app(_beta(), Scaffold(
      body: AppSegmentedButton<int>(
        segments: const [ButtonSegment(value: 0, label: Text('PDF')), ButtonSegment(value: 1, label: Text('Excel'))],
        selected: const {0},
        onSelectionChanged: (v) => picked = v.first,
      ),
    )));
    expect(find.ancestor(of: find.text('Excel'), matching: find.byType(InkWell)), findsOneWidget);
    await tester.tap(find.text('Excel'));
    expect(picked, 1);
  });

  testWidgets('locked switches look locked in the Beta', (tester) async {
    final theme = _beta();
    final track = theme.switchTheme.trackColor!;
    expect(track.resolve({WidgetState.selected, WidgetState.disabled})!.a, lessThan(track.resolve({WidgetState.selected})!.a));
  });
}
