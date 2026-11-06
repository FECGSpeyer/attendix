// Parity (Ionic song.page update()): every change on the song page is saved.
// A change made while a save is still running must be saved afterwards
// instead of being dropped.
import 'dart:async';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/songs/presentation/pages/song_detail_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks/supabase_mocks.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref);
}

class _SlowSongNotifier extends SongNotifier {
  final calls = <Map<String, dynamic>>[];
  final pending = <Completer<void>>[];

  @override
  Future<Song?> updateSong(int id, Map<String, dynamic> updates) async {
    calls.add(updates);
    final c = Completer<void>();
    pending.add(c);
    await c.future;
    return Song(id: id, name: updates['name'] as String);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, _SlowSongNotifier notifier, {bool show = true}) async {
    final auth = MockGoTrueClient();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
        supabaseAuthProvider.overrideWithValue(auth),
        currentAuthUserIdProvider.overrideWithValue(null),
        currentRoleProvider.overrideWithValue(Role.admin),
        effectiveRoleProvider.overrideWithValue(Role.admin),
        songNotifierProvider.overrideWith(() => notifier),
        songDetailDataProvider((songId: 1, sharingId: null)).overrideWith(
          (ref) async => const SongDetailData(
            song: Song(id: 1, name: 'Festmusik', number: 12),
            tenantType: 'general',
            instruments: [],
            categories: [],
            additionalFields: [],
            history: [],
            readOnly: false,
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: show ? const SongDetailPage(songId: '1') : const SizedBox(),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('a change during a running save is saved afterwards', (tester) async {
    final notifier = _SlowSongNotifier();
    await pump(tester, notifier);

    await tester.tap(find.text('Chor & Orchester'));
    await tester.pump();
    expect(notifier.calls, hasLength(1));

    // Second change while the first save is still running.
    await tester.tap(find.text('Mit Solo-Gesang'));
    await tester.pump();
    expect(notifier.calls, hasLength(1));

    notifier.pending.first.complete();
    await tester.pump();
    expect(notifier.calls, hasLength(2));
    expect(notifier.calls.last['withChoir'], isTrue);
    expect(notifier.calls.last['withSolo'], isTrue);

    notifier.pending.last.complete();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('text typed last is saved when the page closes', (tester) async {
    final notifier = _SlowSongNotifier();
    await pump(tester, notifier);
    await tester.enterText(find.widgetWithText(TextField, 'Festmusik'), 'Festmusik II');
    await tester.pump();
    expect(notifier.calls, isEmpty);

    await pump(tester, notifier, show: false);
    expect(notifier.calls.single['name'], 'Festmusik II');
    notifier.pending.single.complete();
  });

  testWidgets('closing without changes saves nothing', (tester) async {
    final notifier = _SlowSongNotifier();
    await pump(tester, notifier);
    await pump(tester, notifier, show: false);
    expect(notifier.calls, isEmpty);
  });
}
