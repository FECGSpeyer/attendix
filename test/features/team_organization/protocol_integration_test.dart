import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/player_absence/player_absence.dart';
import 'package:attendix/data/models/team_org/team_org.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/settings/presentation/widgets/type_protocol_settings.dart';
import 'package:attendix/features/team_organization/presentation/widgets/attendance_protocol_section.dart';
import 'package:attendix/features/team_organization/presentation/widgets/my_tasks_card.dart';
import 'package:attendix/features/team_organization/presentation/widgets/protocol_editor.dart';
import 'package:attendix/features/team_organization/presentation/widgets/quick_create_attendance.dart';
import 'package:attendix/features/team_organization/protocol_layout.dart';
import 'package:attendix/features/team_organization/tiptap_delta.dart';
import 'package:flutter/material.dart' show Icons, TextSelection;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tiptap embeds', () {
    test('task and topic references stay in place', () {
      final doc = {
        'type': 'doc',
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'Vorher'}
            ]
          },
          taskRefNode(id: 't1', title: 'Noten kaufen', status: 'open'),
          {
            'type': 'agendaItemRef',
            'attrs': {'id': 'a1', 'title': 'Pulte', 'status': 'open', 'priority': 'high'}
          },
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'Nachher'}
            ]
          },
        ],
      };
      final parts = tiptapToDelta(doc);
      // Quill accepts the ops (embeds as block embeds).
      final document = Document.fromJson(parts.ops);
      final back = deltaToTiptap(document.toDelta().toJson());
      final types = (back['content'] as List).map((n) => (n as Map)['type']).toList();
      expect(types, ['paragraph', 'taskRef', 'agendaItemRef', 'paragraph']);
      expect(taskRefIds(back), ['t1']);
      final topic = (back['content'] as List)[2] as Map;
      expect((topic['attrs'] as Map)['priority'], 'high');
    });

    test('inserting a task reference in the editor saves it at the cursor', () {
      final controller = QuillController.basic();
      controller.replaceText(0, 0, 'Hallo', const TextSelection.collapsed(offset: 5));
      insertRefEmbed(controller, taskRefEmbedType, {'id': 't9', 'title': 'Aufgabe', 'status': 'open'});
      final doc = deltaToTiptap(controller.document.toDelta().toJson());
      expect(taskRefIds(doc), ['t9']);
      expect(docToPlainText(doc), contains('Hallo'));
      controller.dispose();
    });

    test('taskRefText shows the live status', () {
      expect(taskRefText('Noten', 'open'), '📋 Noten · Offen');
      expect(taskRefText('Noten', 'completed'), '✅ Noten · Erledigt');
      expect(taskRefText('Noten', null), '📋 Noten');
    });
  });

  group('slash commands', () {
    test('slashQueryAt finds the query left of the cursor', () {
      expect(slashQueryAt('Text /auf', 9), (start: 5, query: 'auf'));
      expect(slashQueryAt('/', 1), (start: 0, query: ''));
      expect(slashQueryAt('a/b', 3), isNull);
      expect(slashQueryAt('Text', 4), isNull);
    });

    test('filterSlashCommands matches title and description', () {
      Future<void> noop() async {}
      final cmds = [
        SlashCommand('Überschrift 1', 'Große Überschrift', Icons.title, noop),
        SlashCommand('/aufgabe – Neue Aufgabe', 'Aufgabe erstellen und verknüpfen', Icons.title, noop),
      ];
      expect(filterSlashCommands(cmds, 'auf').map((c) => c.title), ['/aufgabe – Neue Aufgabe']);
      expect(filterSlashCommands(cmds, ''), hasLength(2));
    });
  });

  group('protocol layout', () {
    test('clampSideWidth keeps the middle column usable', () {
      expect(clampSideWidth(100, 280, 1200), minSideWidth);
      expect(clampSideWidth(900, 280, 1200), 1200 - 280 - minMainWidth - 2 * resizerWidth);
      expect(clampSideWidth(300, 280, 0), 300);
    });

    test('parseColumnWidths falls back to defaults', () {
      expect(parseColumnWidths(null), defaultColumnWidths);
      expect(parseColumnWidths('nope'), defaultColumnWidths);
      expect(parseColumnWidths('{"left":320,"right":10}'), (left: 320.0, right: defaultSideWidth));
      final w = (left: 300.0, right: 200.0);
      expect(parseColumnWidths(encodeColumnWidths(w)), w);
    });

    test('next / previous point', () {
      expect(nextSectionId(['a', 'b'], null), 'a');
      expect(nextSectionId(['a', 'b'], 'a'), 'b');
      expect(nextSectionId(['a', 'b'], 'b'), isNull);
      expect(previousSectionId(['a', 'b'], 'b'), 'a');
      expect(previousSectionId(['a', 'b'], 'a'), isNull);
    });
  });

  group('type protocol settings', () {
    test('switching on fills the default duration', () {
      final s = const TypeProtocolSettings().toggled(true);
      expect(s.agendaDefaultDuration, 10);
      expect(s.toUpdate(), {'enable_protocol': true, 'suggest_postponed': true, 'agenda_default_duration': 10});
    });

    test('an invalid duration is not written (NOT NULL column)', () {
      final s = const TypeProtocolSettings(enableProtocol: true).copyWith(clearDuration: true);
      expect(s.toUpdate().containsKey('agenda_default_duration'), isFalse);
    });

    test('placeholder detection', () {
      expect(hasAgendaPlaceholder([agendaPlaceholderField()]), isTrue);
      expect(hasAgendaPlaceholder([
        {'id': 'x'}
      ]), isFalse);
      expect(agendaPlaceholderField()['time'], '0');
    });
  });

  group('protocol card', () {
    test('status texts', () {
      expect(protocolCardStatus(null), 'Noch nicht begonnen');
      expect(
        protocolCardStatus(const Protocol(status: 'published', publishedAt: '2026-10-01T10:00:00Z')),
        startsWith('Freigegeben am 01.10.2026'),
      );
      expect(protocolCardStatus(const Protocol(updatedAt: '2026-10-01T10:00:00Z')),
          startsWith('Entwurf · zuletzt bearbeitet 01.10.2026'));
      expect(taskStatusLabel('in_progress'), 'In Arbeit');
    });
  });

  group('my tasks', () {
    test('open tasks sorted with overdue first and labels', () {
      const today = '2026-10-28';
      final tasks = [
        const TeamTask(id: '1', title: 'Später', dueDate: '2026-12-01'),
        const TeamTask(id: '2', title: 'Alt', dueDate: '2026-10-01'),
        const TeamTask(id: '3', title: 'Fertig', status: 'completed'),
        const TeamTask(id: '4', title: 'Ohne'),
      ];
      final open = openTasksSorted(tasks, today);
      expect(open.map((t) => t.id), ['2', '1', '4']);
      expect(myTaskDueLabel(open.first, today), startsWith('Überfällig seit'));
      expect(myTaskDueLabel(open.last, today), 'Ohne Fälligkeit');
      expect(myTasksSubtitle(open, today), '3 offen · 1 überfällig');
    });
  });

  group('quick-create Termin', () {
    const types = [
      AttendanceType(id: 'b', name: 'Vorstand', index: 2),
      AttendanceType(id: 'a', name: 'Sitzung', index: 1),
      AttendanceType(id: 'c', name: 'Probe', index: 0),
      AttendanceType(id: 'd', name: 'Versteckt', index: 3, visible: false),
    ];
    const protocolTypes = [
      ProtocolType(id: 'a', enableProtocol: true),
      ProtocolType(id: 'b', enableProtocol: true),
      ProtocolType(id: 'd', enableProtocol: true),
    ];

    test('only visible protocol types, by index', () {
      expect(protocolAttendanceTypes(types, protocolTypes).map((t) => t.id), ['a', 'b']);
    });

    test('persons are filtered by groups and extra field', () {
      final persons = [
        {'id': 1, 'instrument': 5, 'additional_fields': {'f': 'x'}},
        {'id': 2, 'instrument': 6},
        {'id': 3, 'instrument': 5, 'additional_fields': {'f': 'y'}},
      ];
      const type = AttendanceType(
        id: 'a',
        name: 'Sitzung',
        relevantGroups: [5],
        additionalFieldsFilter: {'key': 'f', 'option': 'x'},
      );
      const fields = [ExtraField(id: 'f', name: 'F', type: 'select', defaultValue: 'y')];
      expect(personsForAttendanceType(persons, type, fields).map((p) => p['id']), [1]);
    });

    test('planned absences excuse, duty types start neutral', () {
      final day = DateTime(2026, 11, 3);
      const type = AttendanceType(id: 'a', name: 'Sitzung', defaultStatus: AttendanceStatus.present);
      final rows = newPersonAttendanceRows(
        [
          {'id': 1},
          {'id': 2},
        ],
        type,
        day,
        absences: const [PlayerAbsence(personId: 2, fromDate: '2026-11-01', untilDate: '2026-11-05', reason: 'Urlaub')],
      );
      expect(rows[0]['status'], AttendanceStatus.present.value);
      expect(rows[1]['status'], AttendanceStatus.excused.value);
      expect(rows[1]['notes'], 'Urlaub');

      final duty = newPersonAttendanceRows([
        {'id': 1}
      ], type.copyWith(dutyMode: true), day);
      expect(duty.single['status'], AttendanceStatus.neutral.value);
    });

    test('new Termin row is stored at noon with the type times', () {
      const type = AttendanceType(id: 'a', name: 'Sitzung', startTime: '19:00', endTime: '21:00');
      final row = newAttendanceRow(type, DateTime(2026, 11, 3));
      expect(DateTime.parse(row['date'] as String).toLocal().hour, 12);
      expect(row['type_id'], 'a');
      expect(row['start_time'], '19:00');
      expect(row.containsKey('tenantId'), isFalse, reason: 'the repository forces the tenant');
    });
  });
}
