// B1 (#413): "Anfrage prüfen", Pausieren (Leitung, andere Gruppen, Ich)
// in the new design. The flows behind them stay the old ones.
import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/church_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/parent_providers.dart';
import 'package:attendix/core/providers/profile_providers.dart';
import 'package:attendix/core/providers/shift_providers.dart';
import 'package:attendix/core/providers/teacher_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/core/utils/person_matcher.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/repositories/cross_tenant_person_repository.dart' show LinkedTenantRef;
import 'package:attendix/features/people/presentation/pages/person_detail_page.dart' show personProvider;
import 'package:attendix/features/people/presentation/widgets/duplicate_candidates_card.dart';
import 'package:attendix/features/people/presentation/widgets/pause_person_sheet.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_pending_review_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/members/rd_pause_sheets.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks/supabase_mocks.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref);

  @override
  Future<void> setTenant(Tenant? tenant) async {}
}

final _auth = () {
  final auth = MockGoTrueClient();
  when(() => auth.currentUser).thenReturn(null);
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  return auth;
}();

final _pending = Person(
  id: 7,
  tenantId: 1,
  firstName: 'Neu',
  lastName: 'Ling',
  email: 'neu@test.de',
  instrument: 2,
  pending: true,
  createdAt: DateTime(2026, 11, 3, 12),
);

Future<void> _pump(WidgetTester tester, Widget home, {List<RankedMatch<Person>> duplicates = const []}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      currentTenantIdProvider.overrideWithValue(1),
      supabaseAuthProvider.overrideWithValue(_auth),
      currentUserProvider.overrideWith((ref) => Stream.value(null)),
      currentAuthUserIdProvider.overrideWithValue(null),
      groupsProvider.overrideWith((ref) async => const []),
      groupsMapProvider.overrideWith((ref) async => const {2: 'Violine'}),
      mainGroupProvider.overrideWith((ref) async => null),
      churchesProvider.overrideWith((ref) async => const []),
      teachersProvider.overrideWith((ref) async => const []),
      parentsProvider.overrideWith((ref) async => const []),
      shiftsProvider.overrideWith((ref) async => const []),
      personExtraFieldsProvider.overrideWith((ref) async => const []),
      currentRoleProvider.overrideWithValue(Role.admin),
      personProvider(7).overrideWith((ref) async => _pending),
      duplicateCandidatesProvider(_pending).overrideWith((ref) async => duplicates),
    ],
    child: MaterialApp(
      theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// A button that opens [open] and keeps its result.
class _Opener<T> extends StatelessWidget {
  const _Opener(this.open, this.onResult);

  final Future<T?> Function(BuildContext context) open;
  final void Function(T? result) onResult;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(onPressed: () async => onResult(await open(context)), child: const Text('open')),
        ),
      );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Anfrage prüfen lives below Freigaben and is for leads only', () {
    expect(RedesignRoutes.approvalReview(7), '/ich/verwaltung/freigaben/7');
    expect(RedesignRoutes.roleRedirect(RedesignRoutes.approvalReview(7), Role.player), RedesignRoutes.manage);
    expect(RedesignRoutes.roleRedirect(RedesignRoutes.approvalReview(7), Role.helper), RedesignRoutes.manage);
    expect(RedesignRoutes.roleRedirect(RedesignRoutes.approvalReview(7), Role.responsible), isNull);
  });

  testWidgets('Anfrage prüfen: head, Doppelung, Angaben, Ablehnen / Aufnehmen', (tester) async {
    const candidate = Person(id: 3, firstName: 'Neu', lastName: 'Ling', instrument: 2);
    await _pump(
      tester,
      const RdPendingReviewPage(personId: 7),
      duplicates: const [RankedMatch(candidate: candidate, score: 1, reason: 'Gleicher Name')],
    );
    expect(find.text('Neu Ling'), findsWidgets);
    expect(find.text('Anfrage vom 03.11.2026 · Violine'), findsOneWidget);
    expect(find.text('Mögliche Doppelung'), findsOneWidget);
    expect(find.byKey(const Key('rd-review-merge-3')), findsOneWidget);
    expect(find.text('ANGABEN'), findsOneWidget);
    // The registration is read, not edited: no inputs, only the group can
    // be changed; empty values (Telefon) are left out.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('neu@test.de'), findsOneWidget);
    expect(find.byKey(const Key('rd-review-phone')), findsNothing);
    expect(find.byKey(const Key('rd-review-group')), findsOneWidget);
    expect(find.text('Ablehnen'), findsOneWidget);
    expect(find.text('Aufnehmen'), findsOneWidget);
  });

  testWidgets('Anfrage prüfen: no Doppelung card without candidates', (tester) async {
    await _pump(tester, const RdPendingReviewPage(personId: 7));
    expect(find.text('Mögliche Doppelung'), findsNothing);
    expect(find.text('Aufnehmen'), findsOneWidget);
  });

  testWidgets('Pausieren (Leitung): reason chip, Ab Heute, Bis Ohne Ende', (tester) async {
    PauseInput? result;
    var closed = false;
    await _pump(
      tester,
      _Opener<PauseInput>(
        (context) => showRdPauseSheet(context, title: 'Anna Beispiel pausieren', hint: 'Hinweis'),
        (r) {
          result = r;
          closed = true;
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Anna Beispiel pausieren'), findsOneWidget);
    expect(find.text('Ab'), findsOneWidget);
    expect(find.text('Heute'), findsOneWidget);
    expect(find.text('Bis'), findsOneWidget);
    expect(find.text('Ohne Ende'), findsOneWidget);
    // No reason yet: the button stays off.
    final submit = find.byKey(const Key('rd-pause-submit'));
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(closed, isFalse);

    await tester.enterText(find.byKey(const Key('rd-pause-reason')), 'Auslandsjahr');
    await tester.pump();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result?.reason, 'Auslandsjahr');
    expect(result?.from, isNull);
    expect(result?.until, isNull);
    expect(buildPauseHistoryText(result!.reason, from: result!.from, until: result!.until), 'Auslandsjahr');
  });

  testWidgets('Ich › Pausieren: no "Ab"', (tester) async {
    await _pump(
      tester,
      _Opener<PauseInput>(
        (context) => showRdPauseSheet(context, title: 'Pausieren', hint: 'Hinweis', withFrom: false),
        (_) {},
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Ab'), findsNothing);
    expect(find.text('Bis'), findsOneWidget);
  });

  testWidgets('Auch in anderen Gruppen pausieren: round checks, Pausieren returns the picked', (tester) async {
    List<LinkedTenantRef>? result;
    await _pump(
      tester,
      _Opener<List<LinkedTenantRef>>(
        (context) => showRdPauseOthersSheet(
          context,
          name: 'Anna Beispiel',
          tenants: const [LinkedTenantRef(id: 1, name: 'Chor'), LinkedTenantRef(id: 2, name: 'Band')],
        ),
        (r) => result = r,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Auch in anderen Gruppen pausieren?'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    await tester.tap(find.text('Band'));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.tap(find.byKey(const Key('rd-pause-others-submit')));
    await tester.pumpAndSettle();
    expect(result?.map((t) => t.id), [2]);
  });
}
