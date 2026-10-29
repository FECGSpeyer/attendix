import 'dart:io';

import 'package:attendix/features/team_organization/protocol_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// P10_SONGS_ORG: final parity sweep (songs, team organisation, protocols).
void main() {
  group('Werke tab keeps its tab while a song is open (Ionic /tabs/songs-tab/:id)', () {
    test('router registers /songs-tab/:id with the song detail page', () {
      final router = _read('lib/core/router/app_router.dart');
      final start = router.indexOf("path: '/songs-tab'");
      expect(start, greaterThan(0));
      final block = router.substring(start, router.indexOf("path: '/org-plans-tab'"));
      expect(block, contains("name: 'songsTabDetail'"));
      expect(block, contains('SongDetailPage(songId:'));
    });

    test('songs list opens songs from the Werke tab under /songs-tab', () {
      final page = _read('lib/features/songs/presentation/pages/songs_list_page.dart');
      expect(page, contains("context.push('/songs-tab/\$songId')"));
      expect(page, contains("uri.path.startsWith('/songs-tab')"));
    });
  });

  test('song category dialogs show the Ionic "name empty" toast', () {
    final src = _read('lib/features/songs/presentation/widgets/song_categories_sheet.dart');
    expect('songsCategoryNameEmpty'.allMatches(src).length, 2);
  });

  group('protocol', () {
    test('a task reload failure keeps the local list (no duplicate row)', () {
      final src = _read('lib/features/team_organization/presentation/pages/protocol_page.dart');
      expect(src, isNot(contains('_tasks = [..._tasks, task]);\n    }\n  }')));
    });

    test('share and publish PDFs carry the tenant branding', () {
      final src = _read('lib/features/team_organization/presentation/pages/protocol_page.dart');
      expect('_buildPdfData(branding: branding)'.allMatches(src).length, 2);
    });

    test('PDF renders with branding slot, empty sections and task lines', () async {
      final bytes = await createProtocolPdf(ProtocolPdfData(
        title: 'Protokoll: Vorstand',
        subtitle: 'Di, 21.10.2026',
        status: 'Entwurf',
        present: const ['Anna Weber'],
        sections: [
          ProtocolPdfSection(title: 'TOP 1 · Konzert', tasks: const ['Mappen bestellen · Paul']),
        ],
        otherTasks: const ['Noten kopieren'],
      ));
      expect(bytes.length, greaterThan(500));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });

  test('task detail "Zurück" never pops an empty stack', () {
    final src = _read('lib/features/team_organization/presentation/pages/task_detail_page.dart');
    expect(src, contains("context.canPop()"));
    expect(src, contains("'/settings/team-organization' : '/signout'"));
  });

  test('topic planning refreshes the plan caches (SOL_FIX33)', () {
    final src = _read('lib/features/team_organization/presentation/pages/agenda_item_detail_page.dart');
    final start = src.indexOf('Future<void> _planInto(');
    final body = src.substring(start, src.indexOf('Widget build(', start));
    expect(body, contains('ref.invalidate(planAttendancesProvider);'));
    expect(body, contains('ref.invalidate(orgPlansProvider);'));
  });
}
