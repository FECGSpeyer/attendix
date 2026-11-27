
import 'package:attendix/features/team_organization/protocol_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/source_reader.dart';

String _read(String path) => readDartLibrary(path);

/// P10_SONGS_ORG: final parity sweep (songs, team organisation, protocols).
void main() {
  test('song category dialogs show the "name empty" toast', () {
    final src = _read('lib/features/redesign/presentation/pages/rd_work_categories_page.dart');
    expect(src, contains('songsCategoryNameEmpty'));
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
    expect(src, contains("rdBack(context, '/settings/team-organization')"));
  });

  test('topic planning refreshes the plan caches (SOL_FIX33)', () {
    final src = _read('lib/features/team_organization/presentation/pages/agenda_item_detail_page.dart');
    final start = src.indexOf('Future<void> _planInto(');
    final body = src.substring(start, src.indexOf('Widget build(', start));
    expect(body, contains('ref.invalidate(planAttendancesProvider);'));
    expect(body, contains('ref.invalidate(orgPlansProvider);'));
  });
}
