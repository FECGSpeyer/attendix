// U3: "Werk bearbeiten" (song page) in the new design while the Beta is
// on: plain header icons instead of the glass capsule, the files as a
// card, and deleting returns to the Werke of the new design.
import 'dart:io';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/songs/presentation/pages/song_detail_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive_platform.dart' show IosGlassSurface;
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonInsetList;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks/supabase_mocks.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref);
}

final _auth = () {
  final auth = MockGoTrueClient();
  when(() => auth.currentUser).thenReturn(null);
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  return auth;
}();

final _data = SongDetailData(
  song: const Song(id: 1, name: 'Festmusik', number: 12),
  tenantType: 'orchestra',
  instruments: const [],
  categories: const [],
  additionalFields: const [],
  history: const [],
  readOnly: false,
);

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      supabaseAuthProvider.overrideWithValue(_auth),
      currentAuthUserIdProvider.overrideWithValue(null),
      currentRoleProvider.overrideWithValue(Role.admin),
      effectiveRoleProvider.overrideWithValue(Role.admin),
      songDetailDataProvider((songId: 1, sharingId: null)).overrideWith((ref) async => _data),
    ],
    child: MaterialApp(
      theme: theme,
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SongDetailPage(songId: '1'),
    ),
  ));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Finder _filesCard() => find.ancestor(of: find.text('Keine Dateien vorhanden.'), matching: find.byType(IonInsetList));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Beta: plain header icons and the files as a card', (tester) async {
    await _pump(tester, buildRdTheme(RdFarbwelt.petrol, Brightness.light));
    expect(find.text('Werk bearbeiten'), findsWidgets);
    expect(find.byType(IosGlassSurface), findsNothing);
    expect(find.byTooltip('Werk löschen'), findsOneWidget);
    expect(_filesCard(), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('without the Beta (iOS) the glass capsule and plain files block stay', (tester) async {
    await _pump(tester, AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS, web: false));
    expect(find.byType(IosGlassSurface), findsWidgets);
    expect(_filesCard(), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('deleting in the Beta returns to the Werke of the new design', () {
    final source = File('lib/features/songs/presentation/pages/song_detail_page.dart').readAsStringSync();
    expect(source, contains("context.go(context.rdSkin != null ? RedesignRoutes.works : '/settings/songs')"));
  });
}
