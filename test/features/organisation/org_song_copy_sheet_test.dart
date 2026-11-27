import 'package:attendix/core/providers/org_song_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/song/org_song.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/data/repositories/org_song_repository.dart';
import 'package:attendix/features/organisation/presentation/widgets/org_song_copy_sheet.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOrgSongRepository extends Fake implements OrgSongRepository {
  final Map<int, List<Map<String, dynamic>>> songsByLibrary = {
    10: [
      {
        'id': 100,
        'tenantId': 10,
        'name': 'Vorhandenes Werk',
        'number': 1,
        'prefix': 'A',
        'link': 'https://old.example',
        'files': <Map<String, dynamic>>[],
      },
    ],
    20: [
      {
        'id': 200,
        'tenantId': 20,
        'name': 'Anderes Werk',
        'number': 12,
        'prefix': '',
        'files': <Map<String, dynamic>>[],
      },
      {
        'id': 201,
        'tenantId': 20,
        'name': 'Choral in Es',
        'number': 5,
        'prefix': '',
        'link': '',
        'files': [
          {
            'storageName': 'existing.pdf',
            'fileName': 'Partitur.pdf',
            'fileType': 'application/pdf',
            'url': 'https://example/existing.pdf',
          },
        ],
      },
    ],
  };

  final Map<int, List<Group>> groupsByLibrary = {
    10: [const Group(id: 11, name: 'Trompete'), const Group(id: 12, name: 'Posaune', maingroup: true)],
    20: [const Group(id: 21, name: 'Chor')],
  };

  OrgSongCopyRequest? lastCopyRequest;

  @override
  Future<List<Map<String, dynamic>>> getLibrarySongRows(int libraryId) async =>
      songsByLibrary[libraryId] ?? const [];

  @override
  Future<List<Group>> getLibraryGroups(int libraryId) async =>
      groupsByLibrary[libraryId] ?? const [];

  @override
  Future<List<String>> ensureSongCategories(int libraryId, List<String> names) async => const ['cat-1'];

  @override
  Future<Song> copyOrgSong(OrgSongCopyRequest request, {void Function(int current, int total)? onProgress}) async {
    lastCopyRequest = request;
    return Song(id: 999, name: request.source.name, number: (request.fields['number'] as int?) ?? 1);
  }
}

final _tenants = [
  const OrgSongTenant(id: 10, shortName: 'PC', longName: 'Posaunenchor'),
  const OrgSongTenant(id: 20, shortName: 'JC', longName: 'Jugendchor'),
];

final _targets = [
  OrgSongCopyTarget(tenant: _tenants[0], libraryId: 10),
  OrgSongCopyTarget(tenant: _tenants[1], libraryId: 20, libraryName: 'Gemeinsame Bibliothek'),
];

const _sourceSong = OrgSongResult(
  id: 50,
  tenantId: 99,
  tenantName: 'Bezirkschor',
  name: 'Choral in Es',
  number: 5,
  prefix: 'A',
  difficulty: 2,
  withChoir: true,
  link: 'https://example.org/choral',
  categoryNames: ['Choral', 'Festlich'],
  files: [
    OrgSongFile(
      storageName: 'p.pdf',
      fileName: 'Partitur.pdf',
      url: 'https://example/p.pdf',
      instrumentId: 30,
      groupName: 'Trompete',
    ),
    OrgSongFile(
      storageName: 'rec.mp3',
      fileName: 'Aufnahme.mp3',
      url: 'https://example/rec.mp3',
      instrumentId: 1,
    ),
  ],
);

Widget _host(
  _FakeOrgSongRepository repo, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
  OrgSongResult source = _sourceSong,
  void Function(int)? onCopied,
}) {
  return ProviderScope(
    overrides: [
      orgSongRepositoryWithTenantProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: OrgSongCopySheet(
            source: source,
            targets: _targets,
            orgTenants: _tenants,
            onCopied: onCopied,
          ),
        ),
      ),
    ),
  );
}

void main() {
  Finder outerScrollable() => find.byType(Scrollable).first;

  Future<void> scrollToSubmit(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('org-copy-submit')),
      200,
      scrollable: outerScrollable(),
    );
    await tester.pumpAndSettle();
  }

  group('OrgSongCopySheet', () {
    testWidgets('renders Redesign primitives without Ionic legacy chrome', (tester) async {
      final repo = _FakeOrgSongRepository();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(IonSheetHeader), findsNothing);
      expect(find.byType(IonInsetList), findsNothing);
      expect(find.byType(OutlineInputBorder), findsNothing);
      expect(find.text('A5 Choral in Es'), findsOneWidget);

      await scrollToSubmit(tester);
      expect(find.byKey(const Key('org-copy-submit')), findsOneWidget);
    });

    testWidgets('fits 320x640 at 1.6x text scale without overlap or overflow', (tester) async {
      final repo = _FakeOrgSongRepository();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(repo, size: const Size(320, 640), textScale: 1.6));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final targetRect = tester.getRect(find.byKey(const Key('org-copy-target')));
      final prefixRect = tester.getRect(find.byKey(const Key('org-copy-prefix')));
      expect(targetRect.bottom <= prefixRect.top, isTrue);

      await scrollToSubmit(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('org-copy-submit')), findsOneWidget);
    });

    testWidgets('validates taken prefix + number and disables copy button until free', (tester) async {
      final repo = _FakeOrgSongRepository();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      Future<FilledButton> submitButton() async {
        await scrollToSubmit(tester);
        return tester.widget<FilledButton>(
          find.descendant(of: find.byKey(const Key('org-copy-submit')), matching: find.byType(FilledButton)),
        );
      }

      // Initially A5 is free -> submit button enabled.
      expect((await submitButton()).onPressed, isNotNull);

      // Scroll back up to edit number to 1 (already taken with prefix A in target 10).
      await tester.drag(outerScrollable(), const Offset(0, 400));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('org-copy-number')), '1');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('org-copy-next-free')), findsOneWidget);
      expect((await submitButton()).onPressed, isNull);

      // Scroll back up, tap suggested next free number -> restores free number and re-enables button.
      await tester.drag(outerScrollable(), const Offset(0, 400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('org-copy-next-free')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('org-copy-next-free')), findsNothing);
      expect((await submitButton()).onPressed, isNotNull);

      // Edit prefix so it no longer collides even with 1.
      await tester.drag(outerScrollable(), const Offset(0, 400));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('org-copy-prefix')), 'B');
      await tester.enterText(find.byKey(const Key('org-copy-number')), '1');
      await tester.pumpAndSettle();
      expect((await submitButton()).onPressed, isNotNull);
    });

    testWidgets('switches target, detects duplicates, toggles copy mode, and submits', (tester) async {
      final repo = _FakeOrgSongRepository();
      int? copiedLibraryId;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(repo, onCopied: (id) => copiedLibraryId = id));
      await tester.pumpAndSettle();

      // Open target picker and switch to target 20 (which has duplicate "Choral in Es").
      await tester.tap(find.byKey(const Key('org-copy-target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JC').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('org-copy-mode-existing')), findsOneWidget);
      expect(find.byKey(const Key('org-copy-mode-new')), findsOneWidget);

      final ctx = tester.element(find.byType(OrgSongCopySheet));
      final l10n = ctx.l10n;
      expect(find.text(l10n.orgSongsCopyIntoExisting), findsOneWidget);

      // Switch duplicate mode to "create new" -> number/prefix fields appear & CTA label changes.
      await tester.tap(find.byKey(const Key('org-copy-mode-new')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('org-copy-prefix')), findsOneWidget);

      // Scroll to submit button and verify CTA label changed, then tap to copy.
      await scrollToSubmit(tester);
      expect(find.text(l10n.orgSongsCopyAsNew), findsOneWidget);
      await tester.tap(find.byKey(const Key('org-copy-submit')));
      await tester.pumpAndSettle();

      expect(repo.lastCopyRequest, isNotNull);
      expect(repo.lastCopyRequest!.targetLibraryId, 20);
      expect(repo.lastCopyRequest!.existingSongId, isNull);
      expect(copiedLibraryId, 20);
    });
  });
}
