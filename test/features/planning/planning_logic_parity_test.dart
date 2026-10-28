import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:attendix/core/providers/plan_providers.dart';
import 'package:attendix/core/services/plan_export_service.dart';
import 'package:attendix/core/utils/attendance_percentage_utils.dart';
import 'package:attendix/core/services/register_plan_service.dart';
import 'package:attendix/core/services/telegram_service.dart';
import 'package:attendix/core/utils/plan_utils.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// WAVE 7 LOGIC_PLANNING: Ionic planning.page / telegram.service / Utils parity.
void main() {
  group('Registerprobenplan (Ionic createPlan)', () {
    test('rows = max(conductors, groups), relative minutes round(total/rows*i)', () {
      final plan = RegisterPlanService.generate(
        conductors: ['Anna M.', 'Ben K.'],
        groups: ['Sopran', 'Alt', 'Tenor', 'Bass'],
        totalMinutes: 50,
      );
      expect(plan.rows.length, 4);
      expect(plan.rows.map((r) => r.first), ['0', '13', '25', '38']);
      // group g in row i → conductor (i + g) % rows, empty when none
      expect(plan.rows[0], ['0', 'Anna M.', 'Ben K.', '', '']);
      expect(plan.rows[1], ['13', 'Ben K.', '', '', 'Anna M.']);
      expect(plan.rows[3], ['38', '', 'Anna M.', 'Ben K.', '']);
    });

    test('more conductors than groups', () {
      final plan = RegisterPlanService.generate(
        conductors: ['A.', 'B.', 'C.'],
        groups: ['X', 'Y'],
        totalMinutes: 60,
      );
      expect(plan.rows, [
        ['0', 'A.', 'B.'],
        ['20', 'B.', 'C.'],
        ['40', 'C.', 'A.'],
      ]);
    });

    test('conductors as "Vorname N." without left ones', () {
      final names = RegisterPlanService.conductorNames([
        const Person(firstName: 'Anna', lastName: 'Müller'),
        const Person(firstName: 'Old', lastName: 'Gone', left: '2024-01-01'),
        const Person(firstName: 'Solo', lastName: ''),
      ]);
      expect(names, ['Anna M.', 'Solo .']);
    });

    test('default groups: categories first, else type defaults', () {
      expect(
        RegisterPlanService.defaultGroups(
            categoryNames: ['Hohe', 'Tiefe'], isChoir: true, choirDefaults: ['S'], otherDefaults: ['O']),
        ['Hohe', 'Tiefe'],
      );
      expect(
        RegisterPlanService.defaultGroups(categoryNames: [], isChoir: true, choirDefaults: ['S'], otherDefaults: ['O']),
        ['S'],
      );
      expect(
        RegisterPlanService.defaultGroups(categoryNames: [], isChoir: false, choirDefaults: ['S'], otherDefaults: ['O']),
        ['O'],
      );
    });

    test('stored groups only used with >= 2 entries; Ionic storage key', () {
      expect(RegisterPlanService.groupsStorageKey(7), 'registerplan-groups-7');
      expect(RegisterPlanService.parseStoredGroups(jsonEncode(['A', 'B']), ['D']), ['A', 'B']);
      expect(RegisterPlanService.parseStoredGroups(jsonEncode(['A']), ['D']), ['D']);
      expect(RegisterPlanService.parseStoredGroups('nope', ['D']), ['D']);
      expect(RegisterPlanService.parseStoredGroups(null, ['D']), ['D']);
    });

    test('isPlanExportDisabled', () {
      bool disabled(List<String> c, List<String> g, String t) =>
          RegisterPlanService.isExportDisabled(conductors: c, groups: g, time: t);
      expect(disabled(['A.'], ['X', 'Y'], '60'), isFalse);
      expect(disabled([], ['X', 'Y'], '60'), isTrue);
      expect(disabled(['A.', ' '], ['X', 'Y'], '60'), isTrue);
      expect(disabled(['A.'], ['X'], '60'), isTrue);
      expect(disabled(['A.'], ['X', ''], '60'), isTrue);
      expect(disabled(['A.'], ['X', 'Y'], ''), isTrue);
    });

    test('shuffle keeps all entries', () {
      final s = RegisterPlanService.shuffle(['a', 'b', 'c', 'd'], Random(1));
      expect(s.toSet(), {'a', 'b', 'c', 'd'});
    });
  });

  group('Telegram encodeFilename (Ionic)', () {
    test('strips diacritics, replaces specials, appends 3-digit number', () {
      final name = TelegramService.encodeFilename('Probe (Tutti) – Änderung: 1/2', '.pdf', random: Random(3));
      expect(name, matches(RegExp(r'^Probe -Tutti- - Anderung- 1-2_\d{3}\.pdf$')));
    });

    test('collapses dashes / whitespace and trims dashes, falls back to "file"', () {
      expect(TelegramService.encodeFilename('--a   b--', '.png', random: Random(1)),
          matches(RegExp(r'^a b_\d{3}\.png$')));
      expect(TelegramService.encodeFilename('???', '.pdf', random: Random(1)), matches(RegExp(r'^file_\d{3}\.pdf$')));
      expect(TelegramService.encodeFilename('Straße', '.pdf', random: Random(1)), matches(RegExp(r'^Stra-e_\d{3}\.pdf$')));
    });

    test('upload uses upsert like Ionic', () {
      final src = File('lib/core/services/telegram_service.dart').readAsStringSync();
      expect(src, contains('encodeFilename(name, extension)'));
      expect(src, contains('upsert: true'));
    });
  });

  group('Plan editor (Ionic planning.page)', () {
    const f = PlanField(id: 'a', name: 'A', time: '15');

    test('plan.end stored as YYYY-MM-DDTHH:mm, read in both formats', () {
      final end = PlanUtils.computeEndIso('17:50', [f, f], now: DateTime(2026, 3, 4));
      expect(end, '2026-03-04T18:20');
      expect(PlanUtils.computeEndIso('2026-03-04T23:50', [f]), '2026-03-05T00:05');
      expect(PlanUtils.formatTime(end), '18:20');
      expect(PlanUtils.formatTime('18:20'), '18:20');
      expect(PlanUtils.computeEndIso('', [f]), '');
    });

    test('validate requires a time on every field', () {
      expect(PlanUtils.validate('17:50', [f]), PlanValidation.ok);
      expect(PlanUtils.validate('17:50', []), PlanValidation.noFields);
      expect(PlanUtils.validate('', [f]), PlanValidation.noFields);
      expect(PlanUtils.validate('17:50', [f, f.copyWith(time: '')]), PlanValidation.missingTime);
      // '0' is truthy in JS
      expect(PlanUtils.validate('17:50', [f.copyWith(time: '0')]), PlanValidation.ok);
    });

    test('TOP numbering only counts agenda fields', () {
      final fields = [
        const PlanField(id: 'x', name: 'Begrüßung', time: '5'),
        const PlanField(id: 'agenda-1', name: 'Finanzen', time: '10', agendaItemId: '1'),
        const PlanField(id: 'agenda-2', name: 'Termine', time: '10', agendaItemId: '2'),
      ];
      final numbers = PlanUtils.topNumbers(fields);
      expect(PlanUtils.fieldDisplayName(fields[0], numbers), 'Begrüßung');
      expect(PlanUtils.fieldDisplayName(fields[1], numbers), contains('1'));
      expect(PlanUtils.fieldDisplayName(fields[1], numbers), contains('Finanzen'));
      expect(PlanUtils.fieldDisplayName(fields[2], numbers), startsWith('TOP 2'));
    });

    test('editor, viewer and PDF use the TOP display name', () {
      for (final path in [
        'lib/features/planning/presentation/widgets/plan_fields_editor.dart',
        'lib/features/planning/presentation/widgets/plan_view_list.dart',
        'lib/core/services/plan_export_service.dart',
      ]) {
        expect(File(path).readAsStringSync(), contains('PlanUtils.fieldDisplayName('), reason: path);
      }
    });

    test('attendances since season start, no limit (Ionic getCurrentAttDate)', () {
      final src = File('lib/data/repositories/plan_repository.dart').readAsStringSync();
      final fn = RegExp(r'getPlanAttendances\([^)]*\) async \{[\s\S]+?\n  \}').firstMatch(src)!.group(0)!;
      expect(fn, contains(".eq('tenantId', currentTenantId)"));
      expect(fn, contains(".gt('date', since)"));
      expect(fn, isNot(contains('.limit(')));
      expect(attendanceListStartDate('2025-09-01'), '2025-09-01');
      expect(attendanceListStartDate(null), startsWith('2023-01-01'));
    });
  });

  group('PDF export (Ionic createPlanExport)', () {
    const service = PlanExportService();

    PlanExportPage page(int n) => PlanExportPage(
          title: 'Plan',
          subtitle: 'Samstag',
          time: '17:50',
          fields: [for (var i = 0; i < n; i++) PlanField(id: 'f$i', name: 'Punkt $i', time: '5')],
        );

    test('short plan keeps font 11', () async {
      expect((await service.fitA4Style(page(5))).fontSize, 11);
    });

    test('long plan shrinks the font until it fits on one page', () async {
      final style = await service.fitA4Style(page(30));
      expect(style.fontSize, lessThan(11));
      if (style != PlanExportService.a4FitSteps.last) {
        expect(await service.a4PageCount(page(30), style), 1);
      }
    });

    test('no extra "Ende" line', () {
      final src = File('lib/core/services/plan_export_service.dart').readAsStringSync();
      expect(src, isNot(contains('coreFlutterExportEndAt')));
    });
  });
}
