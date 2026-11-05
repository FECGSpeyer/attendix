import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/auto_message_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/data/models/auto_message/auto_message.dart';
import 'package:attendix/features/messages/presentation/pages/auto_message_list_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Ladefehler-Toast gilt je Ladezyklus: auch wenn der Regel-Provider von
/// außen neu geladen wird (z. B. nach Speichern im Regel-Editor).
void main() {
  const failText = 'Automatische Nachrichten konnten nicht geladen werden';

  testWidgets('externer Reload mit Fehler zeigt den Toast erneut', (tester) async {
    var calls = 0;
    // Erster Abruf gelingt, alle weiteren scheitern.
    Future<List<AutoMessageRule>> loadRules() async {
      calls++;
      if (calls == 1) return [AutoMessageRule(tenantId: 1)];
      throw Exception('offline');
    }

    final container = ProviderContainer(
      overrides: [
        currentTenantIdProvider.overrideWithValue(1),
        attendanceTypesProvider.overrideWith((ref) async => []),
        autoMessageRulesProvider.overrideWith((ref) => loadRules()),
        autoMessageLastWeekProvider.overrideWith((ref) async => (sent: 0, people: 0)),
      ],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AutoMessageListPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(failText), findsNothing);

    // Erster externer Reload scheitert → Toast.
    container.invalidate(autoMessageRulesProvider);
    await tester.pumpAndSettle();
    expect(find.text(failText), findsOneWidget);

    // Toast läuft ab, zweiter externer Reload scheitert → wieder Toast.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text(failText), findsNothing);

    container.invalidate(autoMessageRulesProvider);
    await tester.pumpAndSettle();
    expect(find.text(failText), findsOneWidget);
  });
}
