import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/profile_providers.dart';
import 'package:attendix/core/providers/signout_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/repositories/profile_repository.dart';
import 'package:attendix/features/members/data/providers/members_providers.dart';
import 'package:attendix/features/parents/data/providers/parents_providers.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_member_list_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_parent_events_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_voice_leader_page.dart';
import 'package:attendix/features/voice_leader/data/providers/voice_leader_providers.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../factories/test_factories.dart';

/// REDESIGN: Beta pages of the roles without the Dirigent views
/// (Mitglieder for Spieler/Helfer, Termine for Eltern, "Meine Stimme").

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'SO', longName: 'Sinfonieorchester');
  }
}

String _day(int offset) {
  final d = DateTime.now().add(Duration(days: offset));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _app(Widget page, List<Override> overrides) => ProviderScope(
      overrides: [
        currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
        ...overrides,
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        home: page,
      ),
    );

Person _person(int id, String first, String last, int group, {bool leader = false, String? einteilung}) =>
    TestFactories.createPerson(
      id: id,
      firstName: first,
      lastName: last,
      tenantId: 7,
      instrument: group,
      isLeader: leader,
    ).copyWith(additionalFields: einteilung == null ? null : {'einteilung': einteilung});

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  group('Mitglieder for Spieler/Helfer (Beta)', () {
    final anna = _person(1, 'Anna', 'Berg', 1, leader: true, einteilung: 'Nord');
    final ben = _person(2, 'Ben', 'Clas', 1, einteilung: 'Süd');
    final clara = _person(3, 'Clara', 'Dorn', 2, einteilung: 'Nord');

    List<Override> overrides({bool einteilung = true}) => [
          membersGroupedProvider.overrideWith((ref) async => [
                MembersGroup(groupId: 1, groupName: 'Flöte', members: [anna, ben]),
                MembersGroup(groupId: 2, groupName: 'Oboe', members: [clara]),
              ]),
          personExtraFieldsProvider.overrideWith((ref) async => [
                if (einteilung)
                  const ProfileExtraField(id: 'einteilung', name: 'Einteilung', type: 'select', options: ['Nord', 'Süd']),
              ]),
        ];

    testWidgets('shows registers as cards with the leader tag, no percentages', (tester) async {
      await tester.pumpWidget(_app(const RdMemberListPage(), overrides()));
      await _settle(tester);

      expect(find.text('Mitglieder'), findsOneWidget);
      expect(find.text('3 Personen'), findsOneWidget);
      expect(find.text('FLÖTE · 2'), findsOneWidget);
      expect(find.text('OBOE · 1'), findsOneWidget);
      expect(find.text('Anna Berg'), findsOneWidget);
      expect(find.text('Stimmführung'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      // Read-only: rows do not open anything.
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('Einteilung chips filter the list', (tester) async {
      await tester.pumpWidget(_app(const RdMemberListPage(), overrides()));
      await _settle(tester);

      expect(find.text('Alle'), findsOneWidget);
      // Rows show the Einteilung under the name while all are listed.
      expect(find.text('Süd'), findsNWidgets(2));
      await tester.tap(find.text('Süd').first);
      await _settle(tester);
      expect(find.text('Ben Clas'), findsOneWidget);
      expect(find.text('Anna Berg'), findsNothing);
      expect(find.text('Clara Dorn'), findsNothing);
      expect(find.text('FLÖTE · 1'), findsOneWidget);
    });

    testWidgets('no chips without the Einteilung field; search narrows', (tester) async {
      await tester.pumpWidget(_app(const RdMemberListPage(), overrides(einteilung: false)));
      await _settle(tester);

      expect(find.text('Nord'), findsNothing);
      await tester.enterText(find.byType(TextField), 'clara');
      await _settle(tester);
      expect(find.text('Clara Dorn'), findsOneWidget);
      expect(find.text('Anna Berg'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await _settle(tester);
      expect(find.text('Niemand passt zur Suche.'), findsOneWidget);
    });

    testWidgets('load error offers retry', (tester) async {
      await tester.pumpWidget(_app(const RdMemberListPage(), [
        membersGroupedProvider.overrideWith((ref) async => throw Exception('offline')),
        personExtraFieldsProvider.overrideWith((ref) async => const []),
      ]));
      await _settle(tester);
      expect(find.text('Erneut versuchen'), findsOneWidget);
    });
  });

  group('Meine Stimme (Beta)', () {
    testWidgets('lists the register with contacts and coming absences', (tester) async {
      final lea = TestFactories.createPerson(id: 1, firstName: 'Lea', lastName: 'Bach', tenantId: 7, isLeader: true)
          .copyWith(email: 'lea@example.org', phone: null);
      final tim = TestFactories.createPerson(id: 2, firstName: 'Tim', lastName: 'Ruf', tenantId: 7)
          .copyWith(email: null, phone: null);
      await tester.pumpWidget(_app(const RdVoiceLeaderPage(), [
        voiceGroupNameProvider.overrideWith((ref) async => 'Flöte'),
        currentPlayerProvider.overrideWith((ref) async => lea),
        voiceGroupMembersProvider.overrideWith((ref) async => [
              VoiceGroupMember(person: lea, upcomingAbsences: const []),
              VoiceGroupMember(person: tim, upcomingAbsences: [
                UpcomingAbsence(attendanceId: 9, date: DateTime(2030, 3, 4), status: 2, typeName: 'Probe'),
              ]),
            ]),
      ]));
      await _settle(tester);

      expect(find.text('Meine Stimme'), findsOneWidget);
      expect(find.textContaining('Flöte · '), findsOneWidget);
      expect(find.text('Lea Bach'), findsOneWidget);
      expect(find.text('Stimmführung'), findsOneWidget);
      expect(find.text('lea@example.org'), findsOneWidget);
      expect(find.textContaining('Probe'), findsOneWidget);
    });

    testWidgets('no own profile shows the hint', (tester) async {
      await tester.pumpWidget(_app(const RdVoiceLeaderPage(), [
        voiceGroupNameProvider.overrideWith((ref) async => null),
        currentPlayerProvider.overrideWith((ref) async => null),
        voiceGroupMembersProvider.overrideWith((ref) async => const []),
      ]));
      await _settle(tester);
      expect(find.byIcon(Icons.person_off_outlined), findsOneWidget);
    });
  });

  group('Termine for Eltern (Beta)', () {
    final mia = TestFactories.createPerson(id: 11, firstName: 'Mia', lastName: 'Kurz', tenantId: 7);
    final ben = TestFactories.createPerson(id: 12, firstName: 'Ben', lastName: 'Kurz', tenantId: 7);

    ChildPersonAttendance att(int attendanceId, Person child, String date,
            {AttendanceStatus status = AttendanceStatus.neutral, String? info, int? days}) =>
        ChildPersonAttendance(
          id: '$attendanceId-${child.id}',
          personId: child.id,
          attendanceId: attendanceId,
          status: status,
          date: date,
          typeInfo: info,
          childId: child.id!,
          childName: '${child.firstName} ${child.lastName}',
          childFirstName: child.firstName,
          place: 'Gemeindehaus',
          durationDays: days,
        );

    List<Override> overrides({int? pending}) => [
          parentChildrenProvider.overrideWith((ref) async => [mia, ben]),
          childrenAttendancesProvider.overrideWith((ref) async => [
                att(1, mia, _day(3), info: 'Kinderchor'),
                att(1, ben, _day(3), status: AttendanceStatus.present, info: 'Kinderchor'),
                att(2, mia, _day(-14), status: AttendanceStatus.present, info: 'Probe alt'),
                att(2, ben, _day(-14), status: AttendanceStatus.absent, info: 'Probe alt'),
              ]),
          attendanceTypesProvider.overrideWith((ref) async => const []),
          currentSongsProvider.overrideWith((ref) async => const []),
          if (pending != null) pendingAttendanceIdProvider.overrideWith((ref) => pending),
        ];

    testWidgets('coming Termin as card with one answer row per child', (tester) async {
      await tester.pumpWidget(_app(const RdParentEventsPage(), overrides()));
      await _settle(tester);

      expect(find.text('Termine'), findsOneWidget);
      expect(find.text('Kinderchor'), findsOneWidget);
      expect(find.text('Mia'), findsWidgets);
      // Mia is open, Ben already said yes.
      expect(find.text('Ist dabei'), findsOneWidget);
      expect(find.text('Kann nicht'), findsOneWidget);
      expect(find.text('Doch absagen'), findsOneWidget);
      expect(find.text('Route'), findsOneWidget);
      // Rates of the children from the past Termine.
      expect(find.text('Mia · 100 %'), findsOneWidget);
      expect(find.text('Ben · 0 %'), findsOneWidget);
      expect(find.text('Probe alt'), findsNothing);
    });

    testWidgets('Vergangen shows the status of each child', (tester) async {
      await tester.pumpWidget(_app(const RdParentEventsPage(), overrides()));
      await _settle(tester);

      await tester.tap(find.text('Vergangen'));
      await _settle(tester);
      expect(find.text('Probe alt'), findsOneWidget);
      expect(find.textContaining('Mia · '), findsWidgets);
      expect(find.text('Kinderchor'), findsNothing);
    });

    testWidgets('a notification opens its Termin as a sheet', (tester) async {
      await tester.pumpWidget(_app(const RdParentEventsPage(), overrides(pending: 1)));
      await _settle(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Kinderchor'), findsNWidgets(2));
    });

    testWidgets('a failed reload keeps the notification and shows retry', (tester) async {
      await tester.pumpWidget(_app(const RdParentEventsPage(), [
        parentChildrenProvider.overrideWith((ref) async => [mia, ben]),
        childrenAttendancesProvider.overrideWith((ref) async => throw Exception('offline')),
        attendanceTypesProvider.overrideWith((ref) async => const []),
        currentSongsProvider.overrideWith((ref) async => const []),
        pendingAttendanceIdProvider.overrideWith((ref) => 1),
      ]));
      await _settle(tester);

      expect(find.text('Erneut versuchen'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      final container = ProviderScope.containerOf(tester.element(find.byType(RdParentEventsPage)));
      expect(container.read(pendingAttendanceIdProvider), 1);
    });

    testWidgets('answered children keep the changes of the old page', (tester) async {
      await tester.pumpWidget(_app(const RdParentEventsPage(), [
        parentChildrenProvider.overrideWith((ref) async => [mia, ben]),
        childrenAttendancesProvider.overrideWith((ref) async => [
              // Excused: Zusage or another reason / late.
              att(1, mia, _day(3), status: AttendanceStatus.excused, info: 'Kinderchor'),
              // Late: Zusage or cancel.
              att(1, ben, _day(3), status: AttendanceStatus.late, info: 'Kinderchor'),
            ]),
        attendanceTypesProvider.overrideWith((ref) async => const []),
        currentSongsProvider.overrideWith((ref) async => const []),
      ]));
      await _settle(tester);

      expect(find.text('Doch dabei'), findsNWidgets(2));
      expect(find.text('Ändern'), findsOneWidget);
      expect(find.text('Doch absagen'), findsOneWidget);
    });

    testWidgets('multi-day Termine show their date range', (tester) async {
      await tester.pumpWidget(_app(const RdParentEventsPage(), [
        parentChildrenProvider.overrideWith((ref) async => [mia]),
        childrenAttendancesProvider.overrideWith((ref) async => [
              att(1, mia, _day(3), info: 'Freizeit', days: 3),
            ]),
        attendanceTypesProvider.overrideWith((ref) async => const []),
        currentSongsProvider.overrideWith((ref) async => const []),
      ]));
      await _settle(tester);

      expect(find.textContaining(' - '), findsOneWidget);
    });

    testWidgets('without linked children shows the hint', (tester) async {
      await tester.pumpWidget(_app(const RdParentEventsPage(), [
        parentChildrenProvider.overrideWith((ref) async => const []),
        childrenAttendancesProvider.overrideWith((ref) async => const []),
        attendanceTypesProvider.overrideWith((ref) async => const []),
        currentSongsProvider.overrideWith((ref) async => const []),
      ]));
      await _settle(tester);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });
}
