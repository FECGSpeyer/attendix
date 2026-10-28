import 'package:attendix/data/models/team_org/team_org.dart';
import 'package:attendix/features/team_organization/team_org_utils.dart';
import 'package:attendix/features/team_organization/tiptap_delta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('team_org_utils', () {
    final fields = <PlanField>[
      {'id': 'a', 'name': 'Begrüßung', 'time': '5'},
      {'id': agendaItemsPlaceholderId, 'name': 'Themen', 'time': '0'},
      {'id': 'b', 'name': 'Sonstiges', 'time': '10'},
    ];

    test('insertAgendaFields inserts at the marker and skips duplicates', () {
      const item = AgendaItem(id: 'x1', title: 'Konzert');
      final field = buildAgendaField(item, 15);
      expect(field['id'], 'agenda-x1');
      final result = insertAgendaFields(fields, [field]);
      expect(result.map(fieldId), ['a', 'agenda-x1', agendaItemsPlaceholderId, 'b']);
      expect(insertAgendaFields(result, [field]).length, result.length);
    });

    test('protocolSections drops the marker and topNumbers counts TOPs', () {
      final plan = insertAgendaFields(fields, [
        buildAgendaField(const AgendaItem(id: '1', title: 'A'), 10),
        buildAgendaField(const AgendaItem(id: '2', title: 'B'), 10),
      ]);
      final sections = protocolSections(plan);
      expect(sections.any((f) => fieldId(f) == agendaItemsPlaceholderId), isFalse);
      final numbers = topNumbers(sections);
      expect(numbers, {'agenda-1': 1, 'agenda-2': 2});
      expect(fieldDisplayName(sections[1], numbers), 'TOP 1 · A');
    });

    test('fieldStartTimes accumulates durations', () {
      final times = fieldStartTimes('19:30', fields);
      expect(times['a'], '19:30');
      expect(times['b'], '19:35');
    });

    test('isTaskOverdue only for open tasks with past due date', () {
      expect(isTaskOverdue(const TeamTask(dueDate: '2026-01-01'), '2026-02-01'), isTrue);
      expect(isTaskOverdue(const TeamTask(dueDate: '2026-01-01', status: 'completed'), '2026-02-01'), isFalse);
      expect(isTaskOverdue(const TeamTask(dueDate: '2026-03-01'), '2026-02-01'), isFalse);
    });

    test('joinNames and matchesSearch', () {
      expect(joinNames(['Anna']), 'Anna');
      expect(joinNames(['Anna', 'Jonas', 'Paul']), 'Anna, Jonas und Paul');
      expect(matchesSearch('kon pro', ['Konzert', 'Probe']), isTrue);
      expect(matchesSearch('xyz', ['Konzert']), isFalse);
    });

    test('isTeamLeaderRole', () {
      expect(isTeamLeaderRole(null), isFalse);
    });
  });

  group('tiptap_delta', () {
    final doc = {
      'type': 'doc',
      'content': [
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': 'Hallo '},
            {
              'type': 'text',
              'text': 'Welt',
              'marks': [
                {'type': 'bold'}
              ]
            },
          ],
        },
        {
          'type': 'bulletList',
          'content': [
            {
              'type': 'listItem',
              'content': [
                {
                  'type': 'paragraph',
                  'content': [
                    {'type': 'text', 'text': 'Punkt'}
                  ]
                }
              ],
            },
          ],
        },
        taskRefNode(id: 't1', title: 'Noten', status: 'open'),
      ],
    };

    test('round trip keeps text, marks, lists and task refs', () {
      final parts = tiptapToDelta(doc);
      expect(parts.refs, hasLength(1));
      // The reference is a Quill block embed at its position.
      expect(parts.ops.where((o) => o['insert'] is Map), hasLength(1));
      final back = deltaToTiptap(parts.ops);
      expect(docToPlainText(back), contains('Hallo Welt'));
      expect(docToPlainText(back), contains('Punkt'));
      expect(taskRefIds(back), ['t1']);
      final content = back['content'] as List;
      expect(content.any((n) => (n as Map)['type'] == 'bulletList'), isTrue);
      final para = content.first as Map;
      final bold = (para['content'] as List).firstWhere((n) => (n as Map)['text'] == 'Welt') as Map;
      expect((bold['marks'] as List).first['type'], 'bold');
    });

    test('isDocEmpty', () {
      expect(isDocEmpty(null), isTrue);
      expect(isDocEmpty({'type': 'doc', 'content': []}), isTrue);
      expect(isDocEmpty(doc), isFalse);
    });
  });
}
