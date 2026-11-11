import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/features/redesign/presentation/widgets/manage/rd_type_create_sheet.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

/// Leon (11.11.): "Neue Terminart" with the keyboard open filled the whole
/// screen up to the status bar, no way out and no visible "Anlegen".
void main() {
  testWidgets('Neue Terminart: close button, below status bar, Anlegen above keyboard', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    addTearDown(tester.view.reset);

    final types = [for (var i = 0; i < 8; i++) TestFactories.createAttendanceType(id: 'type-$i', name: 'Art $i')];
    String? result = 'unset';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [attendanceTypesProvider.overrideWith((ref) async => types)],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: TextButton(onPressed: () async => result = await showRdTypeCreateSheet(context), child: const Text('öffnen')),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();

    expect(find.text('Neue Terminart'), findsOneWidget);
    // Sheet stays below the status bar.
    expect(tester.getTopLeft(find.text('Neue Terminart')).dy, greaterThan(47));
    // "Anlegen" is pinned and visible above the keyboard.
    final create = find.byKey(const Key('rd-type-new-create'));
    expect(create, findsOneWidget);
    expect(tester.getBottomLeft(create).dy, lessThanOrEqualTo(844 - 336));
    expect(tester.takeException(), isNull);

    // The close button closes it.
    await tester.tap(find.byKey(const Key('rd-sheet-close')));
    await tester.pumpAndSettle();
    expect(find.text('Neue Terminart'), findsNothing);
    expect(result, isNull);
  });
}
