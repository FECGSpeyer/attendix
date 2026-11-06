import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/connectivity_provider.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/teacher_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/repositories/teacher_repository.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_teacher_edit_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_teachers_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../factories/test_factories.dart';

/// Records the writes instead of calling Supabase.
class _FakeTeacherRepo extends TeacherRepository {
  _FakeTeacherRepo(super.ref) {
    bindTenantId(7);
  }

  final updates = <Map<String, dynamic>>[];

  @override
  Future<Teacher?> updateTeacher(int id, Map<String, dynamic> updates) async {
    this.updates.add(Map.of(updates));
    return _anna;
  }
}

const _anna = Teacher(id: 3, name: 'Anna Berg', instruments: [5], number: '0151', tenantId: 7);
const _violin = Group(id: 5, name: 'Violine');
const _cello = Group(id: 6, name: 'Cello');

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app({required Role role, required String location, void Function(_FakeTeacherRepo)? onRepo}) {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: RedesignRoutes.teachers,
        builder: (_, __) => const RdTeachersPage(),
        routes: [
          GoRoute(path: ':id', builder: (_, s) => RdTeacherEditPage(teacherId: int.parse(s.pathParameters['id']!))),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      effectiveRoleProvider.overrideWithValue(role),
      currentTenantIdProvider.overrideWithValue(7),
      offlineQueueUserIdProvider.overrideWithValue(() => 'u1'),
      connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
      offlineQueueSessionIdProvider.overrideWithValue(() => 's1'),
      teacherRepositoryWithTenantProvider.overrideWith((ref) {
        final repo = _FakeTeacherRepo(ref);
        onRepo?.call(repo);
        return repo;
      }),
      teachersProvider.overrideWith((ref) async => const [_anna]),
      enrichedTeachersProvider.overrideWith(
        (ref) async => [_anna.copyWith(insNames: 'Violine', playerCount: 2)],
      ),
      groupsProvider.overrideWith((ref) async => const [_violin, _cello]),
      playersProvider.overrideWith(
        (ref) async => [TestFactories.createPerson(id: 1, firstName: 'Lena', lastName: 'Kurz').copyWith(teacher: 3)],
      ),
    ],
    child: MaterialApp.router(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
      routerConfig: router,
    ),
  );
}

void main() {
  group('Lehrer', () {
    testWidgets('list: name, instruments and players; Beobachter only read', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(role: Role.viewer, location: RedesignRoutes.teachers));
      await _settle(tester);

      expect(find.text('Lehrer'), findsOneWidget);
      expect(find.text('Anna Berg'), findsOneWidget);
      expect(find.text('Violine'), findsOneWidget);
      expect(find.text('2 Spieler'), findsOneWidget);
      // Old page: no "+" and no tap for Beobachter.
      expect(find.byKey(const Key('rd-manage-list-add')), findsNothing);
      await tester.tap(find.text('Anna Berg'));
      await _settle(tester);
      expect(find.text('Lehrer bearbeiten'), findsNothing);
    });

    testWidgets('list: Admins add and open a teacher', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(role: Role.admin, location: RedesignRoutes.teachers));
      await _settle(tester);
      expect(find.byKey(const Key('rd-manage-list-add')), findsOneWidget);
      await tester.tap(find.text('Anna Berg'));
      await _settle(tester);
      expect(find.text('Lehrer bearbeiten'), findsOneWidget);
    });

    testWidgets('edit page: every field of the old page, saved right away', (tester) async {
      _phone(tester);
      late _FakeTeacherRepo repo;
      await tester.pumpWidget(
        _app(role: Role.admin, location: RedesignRoutes.teacherEdit(3), onRepo: (r) => repo = r),
      );
      await _settle(tester);

      expect(find.text('Lehrer bearbeiten'), findsOneWidget);
      expect(find.text('Privatlehrer'), findsOneWidget);
      expect(find.text('Kontakt'), findsOneWidget);
      expect(find.text('Lena Kurz'), findsOneWidget); // her players

      await tester.tap(find.byKey(const Key('rd-teacher-edit-instrument-6')));
      await tester.tap(find.byKey(const Key('rd-teacher-edit-instrument-5')));
      await tester.tap(find.byKey(const Key('rd-teacher-edit-private')));
      // Edit without validation (old page): no instrument left is fine.
      await tester.enterText(find.byKey(const Key('rd-teacher-edit-name')), '  Anna Berg-Kurz ');
      await tester.tap(find.byKey(const Key('rd-teacher-edit-done')));
      await _settle(tester);

      expect(repo.updates, [
        {
          'instruments': [5, 6],
        },
        {
          'instruments': [6],
        },
        {'private': true},
        {'name': 'Anna Berg-Kurz'},
      ]);
      expect(find.text('Anna Berg'), findsOneWidget); // back on the list
    });

    test('route rights like /settings/teachers; a teacher only for leads', () {
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.teachers, Role.viewer), isNull);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.teachers, Role.responsible), isNull);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.teachers, Role.helper), RedesignRoutes.manage);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.teachers, Role.player), RedesignRoutes.manage);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.teacherEdit(3), Role.viewer), RedesignRoutes.teachers);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.teacherEdit(3), Role.voiceLeader), RedesignRoutes.manage);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.teacherEdit(3), Role.admin), isNull);
    });
  });
}
