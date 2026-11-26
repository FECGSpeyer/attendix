import 'dart:io';

import 'package:attendix/data/repositories/sign_in_out_repository.dart';
import 'package:attendix/features/self_service/presentation/widgets/self_service_event_actions.dart';
import 'package:flutter_test/flutter_test.dart';

/// P10_SELF_PLAN: final parity sweep of "Meine Termine", "Übersicht",
/// Dienstplan, Dashboard and Ablaufplan export sheets with Ionic.
void main() {
  SelfServiceEventActions actions({bool overview = false}) => SelfServiceEventActions(
        absenceReasons: const [],
        lateReasons: const [],
        signIn: (_, __) async => true,
        signOut: (_, __, ___) async => true,
        updateNote: (_, __) async => true,
        openPlan: (_) async {},
        overviewMode: overview,
      );

  CrossTenantPersonAttendance att({String? deadline, Map<String, dynamic>? plan, String? place}) =>
      CrossTenantPersonAttendance(
        id: 'pa1',
        attendanceId: 1,
        date: DateTime.now().add(const Duration(days: 5)).toIso8601String(),
        deadline: deadline,
        tenantId: 1,
        tenantName: 'Chor',
        tenantColor: 'primary',
        plan: plan,
        sharePlan: plan != null,
        place: place,
      );

  group('deadline chip', () {
    final now = DateTime(2026, 10, 29, 12);

    test('Meine Termine: always shown (Ionic signout showDeadlineInfo)', () {
      final a = att(deadline: DateTime.utc(2026, 11, 20, 18).toIso8601String());
      expect(actions().deadlineChipText(a, now: now), isNotNull);
    });

    test('Übersicht: only within 3 days before the deadline', () {
      final far = att(deadline: DateTime.utc(2026, 11, 20, 18).toIso8601String());
      final soon = att(deadline: DateTime.utc(2026, 10, 31, 18).toIso8601String());
      final passed = att(deadline: DateTime.utc(2026, 10, 28, 18).toIso8601String());
      final o = actions(overview: true);
      expect(o.deadlineChipText(far, now: now), isNull);
      expect(o.deadlineChipText(passed, now: now), isNull);
      expect(o.deadlineChipText(soon, now: now), 'Anmeldefrist: 31.10.2026 18:00');
    });
  });

  test('Übersicht sheet has no Ablaufplan / Route entries (Ionic OverviewPage)', () {
    final a = att(plan: const {'fields': [{'id': 'a', 'name': 'x', 'time': '5'}]}, place: 'Halle');
    final signout = actions().buildActions(a).map((e) => e.type).toList();
    final overview = actions(overview: true).buildActions(a).map((e) => e.type).toList();
    expect(signout, contains(SelfServiceActionType.openNavigation));
    expect(overview, isNot(contains(SelfServiceActionType.showPlan)));
    expect(overview, isNot(contains(SelfServiceActionType.openNavigation)));
  });

  group('source parity', () {
    String read(String path) => File(path).readAsStringSync();

    test('"Kann nicht" on Meine Termine uses the excuse reason picker', () {
      final section = read('lib/features/duty/presentation/widgets/self_service_duty_section.dart');
      expect(section, isNot(contains('declineDutyAction(')));
      expect(section, contains('selfServiceDeclineDutyAction('));
      final actionsSrc = read('lib/features/duty/presentation/widgets/duty_actions.dart');
      expect(actionsSrc, contains('showExcuseReasonSheet('));
      expect(actionsSrc, contains('signoutThanksSignout'));
    });

    test('Regelmäßig verhindert only considers visible types', () {
      final page = read('lib/features/redesign/presentation/pages/rd_unavailability_page.dart');
      expect(page, contains('countFutureMatches(rule, types)'));
      final providers = read('lib/core/providers/duty_providers.dart');
      expect(providers, contains('.where((t) => t.visible)'));
    });

    test('Ablaufplan editor share sheet offers PDF, image and public link', () {
      final page = read('lib/features/planning/presentation/pages/planning_page_beta.dart');
      expect(page, contains("Key('rd-plan-pdf')"));
      expect(page, contains("Key('rd-plan-image')"));
      expect(page, contains("Key('rd-plan-link')"));
      expect(page, contains('title: l10n.planningExportPdf'));
    });
  });
}
