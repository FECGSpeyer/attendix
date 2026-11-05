import 'package:attendix/core/utils/toast_helper.dart';
import 'package:attendix/l10n/generated/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('x-7da97d6aac: iOS-look toast is drawn above an open sheet', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    late BuildContext pageContext;
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
      builder: (_) => const SizedBox.expand(child: ColoredBox(color: Colors.white)),
    );
    await tester.pumpAndSettle();

    ToastHelper.showError(pageContext, 'Bitte einen Namen eingeben');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SnackBar), findsNothing);
    final toast = find.text('Bitte einen Namen eingeben');
    expect(toast, findsOneWidget);
    // Hit-testable = drawn above the sheet (the SnackBar was covered).
    expect(toast.hitTestable(), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    debugDefaultTargetPlatformOverride = null;
  });
}
