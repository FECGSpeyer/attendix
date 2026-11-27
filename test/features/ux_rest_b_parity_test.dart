import 'package:attendix/core/theme/app_icons.dart';

import 'package:attendix/core/providers/profile_providers.dart';
import 'package:attendix/data/repositories/profile_repository.dart';
import 'package:attendix/features/people/data/providers/members_providers.dart';
import 'package:attendix/shared/widgets/common/swipe_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';

import '../factories/test_factories.dart';
import '../helpers/source_reader.dart';

String _read(String path) => readDartLibrary(path);

void main() {
  group('Mitglieder (Ionic people/members)', () {
    ProviderContainer container({required List<ProfileExtraField> fields}) {
      final a = TestFactories.createPerson(id: 1, firstName: 'Anna', lastName: 'A', instrument: 10)
          .copyWith(additionalFields: {'einteilung': 'Team 1'});
      final b = TestFactories.createPerson(id: 2, firstName: 'Ben', lastName: 'B', instrument: 10)
          .copyWith(additionalFields: {'einteilung': 'Team 2'});
      final c = TestFactories.createPerson(id: 3, firstName: 'Carl', lastName: 'C');
      final c0 = ProviderContainer(overrides: [
        personExtraFieldsProvider.overrideWith((ref) async => fields),
        membersGroupedProvider.overrideWith((ref) async => [
              MembersGroup(groupId: 10, groupName: 'Sopran', members: [a, b]),
              MembersGroup(groupId: -1, groupName: 'Ohne Gruppe', members: [c]),
            ]),
      ]);
      addTearDown(c0.dispose);
      return c0;
    }

    const einteilung = ProfileExtraField(
      id: 'einteilung',
      name: 'Einteilung',
      type: 'select',
      options: ['Team 1', 'Team 2', '-'],
    );

    test('segment options come from the einteilung select field without "-"', () async {
      final c = container(fields: [einteilung]);
      await c.read(personExtraFieldsProvider.future);
      expect(c.read(membersEinteilungOptionsProvider), ['Team 1', 'Team 2']);
    });

    test('no segment without an einteilung field', () async {
      final c = container(fields: const []);
      await c.read(personExtraFieldsProvider.future);
      expect(c.read(membersEinteilungOptionsProvider), isEmpty);
    });

    test('einteilung filter keeps matching members and drops empty groups', () async {
      final c = container(fields: [einteilung]);
      await c.read(personExtraFieldsProvider.future);
      await c.read(membersGroupedProvider.future);
      c.read(membersEinteilungFilterProvider.notifier).state = 'Team 2';
      final groups = c.read(filteredMembersGroupedProvider).value!;
      expect(groups.length, 1);
      expect(groups.single.members.map((p) => p.firstName), ['Ben']);
    });
  });

  group('Swipe actions (audit section 8)', () {
    testWidgets('SwipeActions.delete wraps the child in a Slidable', (tester) async {
      var deleted = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SwipeActions.delete(
            onDelete: () => deleted = true,
            child: const ListTile(title: Text('Feld')),
          ),
        ),
      ));
      expect(find.byType(Slidable), findsOneWidget);
      await tester.drag(find.text('Feld'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(AppIcons.deleteOutline));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });

    test('lane lists use swipe options instead of trailing trash icons', () {
      final type = _read('lib/features/settings/presentation/pages/attendance_type_edit_page.dart');
      expect(type, contains('SwipeActions.delete('));
      expect(type, isNot(contains('AppIcons.close, size: 20')));

      for (final path in [
        'lib/features/settings/presentation/widgets/type_reminders_editor.dart',
        'lib/features/settings/presentation/widgets/registration_fields_editor.dart',
      ]) {
        expect(_read(path), contains('SwipeActions.delete('), reason: path);
      }
    });

    test('person history delete uses the alert and toast texts', () {
      final src = _read('lib/features/people/presentation/pages/person_history_page.dart');
      expect(src, contains('l10n.personRemoveEntry'));
      expect(src, contains('l10n.personEntryRemoved'));
    });
  });
}
