import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/router/legacy_routes.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/utils/dashboard_logic.dart';
import 'package:attendix/features/redesign/presentation/shell/rd_destinations.dart';
import 'package:flutter_test/flutter_test.dart';

List<RdTab> _tabs(Role role, {bool members = true, String type = 'orchestra'}) =>
    rdDestinationsFor(role, showMembersList: members, tenantType: type)
        .map((d) => d.tab)
        .toList();

String _route(Role role, RdTab tab, {bool members = true}) =>
    rdDestinationsFor(role, showMembersList: members, tenantType: 'orchestra')
        .firstWhere((d) => d.tab == tab)
        .route;

/// REDESIGN: fixed tabs per role; no role sees more than in the old design.
void main() {
  group('rdDestinationsFor', () {
    test('Dirigent, Verantwortlich, Beobachter: all five tabs', () {
      for (final role in [Role.admin, Role.responsible, Role.viewer]) {
        expect(_tabs(role), RdTab.values, reason: role.name);
        expect(_route(role, RdTab.events), '/termine');
        expect(_route(role, RdTab.members), '/people');
      }
    });

    test('Helfer: Termin list, members only when the group shows them', () {
      expect(_route(Role.helper, RdTab.events), '/termine');
      expect(_route(Role.helper, RdTab.members), '/members');
      expect(_tabs(Role.helper, members: false), isNot(contains(RdTab.members)));
    });

    test('Spieler and Stimmführer: the new Termin list', () {
      for (final role in [Role.player, Role.voiceLeader]) {
        expect(_route(role, RdTab.events), '/termine', reason: role.name);
        expect(_tabs(role, members: false),
            [RdTab.today, RdTab.events, RdTab.works, RdTab.me]);
      }
    });

    test('Eltern: parents portal, no members and no works', () {
      expect(_tabs(Role.parent), [RdTab.today, RdTab.events, RdTab.me]);
      expect(_route(Role.parent, RdTab.events), '/parents');
    });

    test('Bewerber: only Heute and Ich', () {
      expect(_tabs(Role.applicant), [RdTab.today, RdTab.me]);
    });

    test('no Werke tab in general groups', () {
      expect(_tabs(Role.admin, type: 'general'), isNot(contains(RdTab.works)));
    });

    test('Heute is first and Ich is last for every role', () {
      for (final role in Role.values) {
        final tabs = _tabs(role);
        expect(tabs.first, RdTab.today, reason: role.name);
        expect(tabs.last, RdTab.me, reason: role.name);
      }
    });
  });

  group('rdTabForLocation', () {
    test('detail pages keep their tab', () {
      expect(rdTabForLocation('/heute'), RdTab.today);
      expect(rdTabForLocation('/termine'), RdTab.events);
      expect(rdTabForLocation('/attendance/12'), RdTab.events);
      expect(rdTabForLocation('/signout'), RdTab.events);
      expect(rdTabForLocation('/parents'), RdTab.events);
      expect(rdTabForLocation('/people/3'), RdTab.members);
      expect(rdTabForLocation('/members'), RdTab.members);
      expect(rdTabForLocation('/songs-tab'), RdTab.works);
      expect(rdTabForLocation('/settings/songs/4'), RdTab.works);
      expect(rdTabForLocation('/ich/darstellung'), RdTab.me);
      expect(rdTabForLocation('/settings/notifications'), RdTab.me);
    });

    test('a tab the role does not have selects Ich', () {
      final parent = rdDestinationsFor(Role.parent, showMembersList: true, tenantType: 'choir');
      expect(rdSelectedIndex(parent, '/people'), parent.length - 1);
      expect(rdSelectedIndex(parent, '/parents'), 1);
    });
  });

  group('RedesignRoutes', () {
    tearDown(() => RedesignRoutes.active = false);

    test('recognises the routes of the new design', () {
      expect(RedesignRoutes.isRedesignRoute('/heute'), isTrue);
      expect(RedesignRoutes.isRedesignRoute('/ich/darstellung'), isTrue);
      expect(RedesignRoutes.isRedesignRoute('/termine'), isTrue);
      expect(RedesignRoutes.isRedesignRoute('/ichbin'), isFalse);
      expect(RedesignRoutes.isRedesignRoute('/settings'), isFalse);
    });

    test('Heute and Ich are tenant scoped (cold start restores the group)', () {
      expect(isTenantScopedRoute('/heute'), isTrue);
      expect(isTenantScopedRoute('/ich/darstellung'), isTrue);
    });

    test('homeRouteFor: "Heute" for every role while the Beta is on', () {
      RedesignRoutes.active = true;
      for (final role in [Role.admin, Role.player, Role.parent, Role.helper]) {
        expect(homeRouteFor(role, 42, null), '/heute', reason: role.name);
      }
      RedesignRoutes.active = false;
      expect(homeRouteFor(Role.player, 42, null), Role.player.defaultRoute);
    });
  });
}
