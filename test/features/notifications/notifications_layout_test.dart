// IOS_R4: Benachrichtigungen – the "Telegramverknüpfung" row keeps its label
// on one line and the connect button is a small pill (Ionic ion-item with
// an ion-label and a small ion-button), on iOS and in Material.
import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/notification_settings_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/telegram_service.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/notifications/presentation/pages/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockAuth extends Mock implements GoTrueClient {}

class _MockChannel extends Mock implements RealtimeChannel {}

class _FakeTelegramService extends TelegramService {
  _FakeTelegramService(super.supabase, this.config);

  final NotificationConfig config;

  @override
  Future<NotificationConfig> getNotificationConfig(String userId) async =>
      config;
}

const _userId = '00000000-0000-0000-0000-000000000001';

Future<void> _pump(
  WidgetTester tester,
  TargetPlatform platform, {
  String? telegramChatId,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final supabase = _MockSupabase();
  final auth = _MockAuth();
  final channel = _MockChannel();
  when(() => supabase.auth).thenReturn(auth);
  when(() => auth.currentUser).thenReturn(const User(
    id: _userId,
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  ));
  when(() => supabase.channel(any())).thenReturn(channel);
  when(() => channel.onPostgresChanges(
        event: any(named: 'event'),
        schema: any(named: 'schema'),
        table: any(named: 'table'),
        filter: any(named: 'filter'),
        callback: any(named: 'callback'),
      )).thenReturn(channel);
  when(() => channel.subscribe()).thenReturn(channel);
  when(() => supabase.removeChannel(any())).thenAnswer((_) async => 'ok');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseClientProvider.overrideWithValue(supabase),
        telegramServiceProvider.overrideWithValue(_FakeTelegramService(
          supabase,
          NotificationConfig(
            id: _userId,
            enabled: true,
            telegramChatId: telegramChatId,
          ),
        )),
        userTenantsProvider.overrideWith((ref) async => const <Tenant>[]),
        tenantHasDutyTypesProvider.overrideWith((ref) async => false),
      ],
      child: MaterialApp(
        theme: AppTheme.forPlatform(Brightness.light, platform)
            .copyWith(platform: platform),
        home: const NotificationsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(PostgresChangeEvent.all);
    registerFallbackValue(PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'id',
      value: _userId,
    ));
    registerFallbackValue(_MockChannel());
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('"Telegramverknüpfung" stays on one line ($platform)',
        (tester) async {
      await _pump(tester, platform);
      // The test font draws every glyph 1em wide (19 × 16pt here), so the
      // label may wrap once at 390pt – but never into a one-letter column
      // (the bug: ≈16pt wide, ≈380pt tall).
      final label = tester.getSize(find.text('Telegramverknüpfung'));
      expect(label.width, greaterThan(80));
      expect(label.height, lessThan(label.width));

      final button = tester.getSize(find.ancestor(
        of: find.text('Verbinden'),
        matching: platform == TargetPlatform.iOS
            ? find.byType(IonSmallPillButton)
            : find.byType(ElevatedButton),
      ));
      // Never the full row width (the old bug: a 358pt wide button).
      expect(button.width, lessThan(200));
      if (platform == TargetPlatform.iOS) {
        // ion-button size small: a 24pt pill as wide as "Verbinden"
        // (9 × 13pt test glyphs + 2 × 11pt padding).
        expect(button.height, lessThan(30));
        expect(button.width,
            closeTo(tester.getSize(find.text('Verbinden')).width + 22, 1));
      }
      // Label and button share one row.
      expect(
        (tester.getCenter(find.text('Telegramverknüpfung')).dy -
                tester.getCenter(find.text('Verbinden')).dy)
            .abs(),
        lessThan(12),
      );
    });
  }

  testWidgets('iOS: linked state shows the note and a red "Trennen" pill',
      (tester) async {
    await _pump(tester, TargetPlatform.iOS, telegramChatId: '42');
    expect(find.text('Konto erfolgreich verknüpft'), findsOneWidget);
    final pill = tester.widget<IonSmallPillButton>(find.ancestor(
      of: find.text('Trennen'),
      matching: find.byType(IonSmallPillButton),
    ));
    expect(pill.label, 'Trennen');
    expect(tester.getSize(find.text('Telegramverknüpfung')).width,
        greaterThan(150));
  });

  testWidgets('iOS: plain page – white background, no card shadows',
      (tester) async {
    await _pump(tester, TargetPlatform.iOS);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, Colors.white);
    final shadows = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.boxShadow != null && d.boxShadow!.isNotEmpty);
    expect(shadows, isEmpty);
  });
}
