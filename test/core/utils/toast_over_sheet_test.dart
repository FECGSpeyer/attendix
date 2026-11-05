import 'package:attendix/core/utils/toast_helper.dart';
import 'package:attendix/l10n/generated/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// x-7da97d6aac: in the iOS look a toast must be visible above an open
/// bottom sheet, once, whether or not the sheet has its own Scaffold.
void main() {
  const message = 'Bitte einen Namen eingeben';

  Future<BuildContext> openSheet(WidgetTester tester, {required bool ownScaffold}) async {
    late BuildContext pageContext;
    late BuildContext sheetContext;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Builder(builder: (c) {
        pageContext = c;
        return const SizedBox.expand();
      })),
    ));
    showModalBottomSheet<void>(
      context: pageContext,
      isScrollControlled: true,
      builder: (_) => SizedBox.expand(
        child: ownScaffold
            // e.g. Stammdaten / Registerplan sheets.
            ? Scaffold(body: Builder(builder: (c) {
                sheetContext = c;
                return const SizedBox.expand();
              }))
            : Builder(builder: (c) {
                sheetContext = c;
                return const ColoredBox(color: Colors.white);
              }),
      ),
    );
    await tester.pumpAndSettle();
    return ownScaffold ? sheetContext : pageContext;
  }

  for (final ownScaffold in [false, true]) {
    testWidgets('toast above a sheet ${ownScaffold ? 'with' : 'without'} its own Scaffold', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final context = await openSheet(tester, ownScaffold: ownScaffold);

      ToastHelper.showError(context, message);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SnackBar), findsNothing);
      // Exactly once, and hit-testable = drawn above the sheet.
      expect(find.text(message), findsOneWidget);
      expect(find.text(message).hitTestable(), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
