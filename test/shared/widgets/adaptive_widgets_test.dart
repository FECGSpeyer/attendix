import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget home) => MaterialApp(
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        home: Scaffold(body: home),
      );

  group('AppAlertDialog', () {
    testWidgets('returns action value on tap', (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      final result = showAppDialog<bool>(
        context: ctx,
        builder: (c) => AppAlertDialog(
          title: const Text('Löschen?'),
          content: const Text('Wirklich?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Nein')),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Weg'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Weg'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });

    testWidgets('showAppPrompt returns entered text', (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      final result = showAppPrompt(ctx, title: 'Name', initialValue: 'A');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Neu');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(await result, 'Neu');
    });
  });

  group('showAppActionSheet', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('returns the tapped value on $platform', (tester) async {
        await tester.pumpWidget(app(const SizedBox()));
        final ctx = tester.element(find.byType(Scaffold));
        final result = showAppActionSheet<String>(
          ctx,
          title: 'Datei',
          actions: const [
            AppActionSheetAction(value: 'open', label: 'Öffnen'),
            AppActionSheetAction(
                value: 'delete', label: 'Löschen', destructive: true),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.text('Abbrechen'), findsOneWidget);
        await tester.tap(find.text('Löschen'));
        await tester.pumpAndSettle();
        expect(await result, 'delete');
      }, variant: TargetPlatformVariant.only(platform));
    }

    testWidgets('cancel returns null', (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      final result = showAppActionSheet<String>(
        ctx,
        actions: const [AppActionSheetAction(value: 'a', label: 'A')],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });
  });

  testWidgets('AppSpinner: iOS activity indicator, Material elsewhere',
      (tester) async {
    await tester.pumpWidget(app(const Center(child: AppSpinner())));
    final ios = debugDefaultTargetPlatformOverride == TargetPlatform.iOS;
    expect(find.byType(CupertinoActivityIndicator),
        ios ? findsOneWidget : findsNothing);
    expect(find.byType(CircularProgressIndicator),
        ios ? findsNothing : findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('AppSpinner iOS: supports SliverFillRemaining, IntrinsicHeight and tight boxes',
      (tester) async {
    await tester.pumpWidget(app(
      CustomScrollView(
        slivers: const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: AppSpinner()),
          ),
        ],
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(tester.getSize(find.byType(AppSpinner)), const Size(28, 28));

    await tester.pumpWidget(app(
      const IntrinsicHeight(
        child: Row(
          children: [AppSpinner()],
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppSpinner)), const Size(28, 28));

    await tester.pumpWidget(app(
      const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: AppSpinner(),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppSpinner)), const Size(20, 20));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('AppSegmentedButton: tap updates selection', (tester) async {
    Set<int>? changed;
    await tester.pumpWidget(app(AppSegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 1, label: Text('Eins')),
        ButtonSegment(value: 2, label: Text('Zwei')),
      ],
      selected: const {1},
      onSelectionChanged: (s) => changed = s,
    )));
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.byType(IonSegment<int>), findsOneWidget);
    await tester.tap(find.text('Zwei'));
    expect(changed, {2});
  });
}
