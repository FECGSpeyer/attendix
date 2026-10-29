// PARITY_R7: role guards of the router per role (Ionic AuthGuard,
// TabsPage `Utils.isUrlAccessAllowed` → `Utils.getUrl(role)`, and the role
// conditions of the settings/tab entry points).
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/router/app_router.dart';
import 'package:attendix/core/router/route_access.dart';
import 'package:flutter_test/flutter_test.dart';

const _tenant = RouteAccessTenant(
  type: 'orchestra',
  showMembersList: true,
  tenantCount: 2,
);

String? _go(
  String url,
  Role role, {
  RouteAccessTenant tenant = _tenant,
  bool canCreate = true,
}) {
  final uri = Uri.parse(url);
  return roleRouteRedirect(uri.path, uri, role,
      canCreateAttendance: canCreate, tenant: tenant);
}

void main() {
  group('helper (Ionic: start page /tabs/signout)', () {
    const role = Role.helper;

    test('audit routes: planning/parents redirect, history stays (Ionic modal)', () {
      expect(_go('/planning', role), '/signout');
      expect(_go('/parents', role), '/signout');
      expect(_go('/statistics', role), '/signout');
      expect(_go('/settings/messages', role), '/signout');
      // Ionic settings: Werkhistorie for `isAdmin || isHelper`.
      expect(_go('/history', role), isNull);
    });

    test('plan of a Termin may be edited (att-list canEdit: isHelper)', () {
      expect(_go('/planning?attendanceId=12', role), isNull);
      expect(_go('/planning?attendanceId=x', role), '/signout');
    });

    test('own tabs stay reachable', () {
      for (final r in ['/signout', '/attendance', '/members', '/overview', '/songs-tab', '/settings']) {
        expect(_go(r, role), isNull, reason: r);
      }
    });

    test('conductor-only pages redirect', () {
      for (final r in [
        '/people',
        '/people/3',
        '/export',
        '/settings/general',
        '/settings/planung',
        '/settings/org-plans',
        '/settings/songs/new',
        '/settings/songs/5/edit',
        '/settings/voice-leader',
        '/home-dashboard',
        '/org-plans-tab',
      ]) {
        expect(_go(r, role), '/signout', reason: r);
      }
    });
  });

  group('player', () {
    const role = Role.player;

    test('restricted routes redirect to /signout', () {
      for (final r in [
        '/planning',
        '/planning?attendanceId=3',
        '/history',
        '/parents',
        '/statistics',
        '/export',
        '/people',
        '/attendance',
        '/attendance/3',
        '/settings/messages',
        '/settings/planung',
        '/settings/voice-leader',
      ]) {
        expect(_go(r, role), '/signout', reason: r);
      }
    });

    test('own routes stay reachable', () {
      for (final r in ['/signout', '/members', '/overview', '/songs-tab', '/settings', '/settings/songs', '/settings/help']) {
        expect(_go(r, role), isNull, reason: r);
      }
    });

    test('tenant flags: members list and multiple instances', () {
      const single = RouteAccessTenant(showMembersList: false, tenantCount: 1);
      expect(_go('/members', role, tenant: single), '/signout');
      expect(_go('/overview', role, tenant: single), '/signout');
      // unknown tenant data never blocks (cold start)
      expect(_go('/members', role, tenant: const RouteAccessTenant()), isNull);
    });
  });

  group('voice leader', () {
    test('voice-leader settings only for VL/VLH', () {
      expect(_go('/settings/voice-leader', Role.voiceLeader), isNull);
      expect(_go('/settings/voice-leader', Role.voiceLeaderHelper), isNull);
      expect(_go('/settings/voice-leader', Role.admin), '/people');
    });

    test('overview is not a voice-leader tab (Ionic isPlayer || isHelper)', () {
      expect(_go('/overview', Role.voiceLeader), '/signout');
      expect(_go('/overview', Role.voiceLeaderHelper), isNull);
    });
  });

  group('conductor / admin', () {
    test('admin and responsible open all management routes', () {
      for (final role in [Role.admin, Role.responsible]) {
        for (final r in [
          '/people',
          '/attendance',
          '/planning',
          '/planning?attendanceId=1',
          '/history',
          '/statistics',
          '/export',
          '/settings/messages',
          '/settings/planung',
          '/settings/general',
          '/settings/viewers',
          '/settings/parents',
          '/settings/songs/new',
          '/settings/songs/5/edit',
          '/songs-tab',
          '/home-dashboard',
        ]) {
          expect(_go(r, role), isNull, reason: '${role.name} $r');
        }
      }
      expect(_go('/settings/users', Role.responsible), '/people');
    });

    test('admin has no self-service or parent tabs', () {
      expect(_go('/signout', Role.admin), '/people');
      expect(_go('/parents', Role.admin), '/people');
      expect(_go('/overview', Role.admin), '/people');
      expect(_go('/members', Role.admin), '/people');
    });

    test('general tenants have no Werkhistorie', () {
      expect(
        _go('/history', Role.admin, tenant: const RouteAccessTenant(type: 'general')),
        '/people',
      );
    });

    test('viewer: read-only conductor (no planning/history/statistics/export)', () {
      const role = Role.viewer;
      expect(_go('/people', role), isNull);
      expect(_go('/attendance', role), isNull);
      expect(_go('/settings/teachers', role), isNull);
      for (final r in [
        '/planning',
        '/planning?attendanceId=1',
        '/history',
        '/statistics',
        '/export',
        '/attendance/4',
        '/signout',
        '/settings/messages',
      ]) {
        expect(_go(r, role), '/people', reason: r);
      }
    });
  });

  group('parent (Ionic start page /tabs/parents)', () {
    const role = Role.parent;

    test('parents portal only for parents', () {
      expect(_go('/parents', role), isNull);
      expect(_go('/settings', role), isNull);
    });

    test('everything else lands on /parents (no /signout loop)', () {
      for (final r in [
        '/signout',
        '/members',
        '/overview',
        '/songs-tab',
        '/people',
        '/attendance',
        '/planning',
        '/history',
        '/statistics',
        '/settings/messages',
      ]) {
        expect(_go(r, role), '/parents', reason: r);
      }
    });
  });

  group('applicant', () {
    const role = Role.applicant;

    test('only "Meine Termine" and settings', () {
      expect(_go('/signout', role), isNull);
      expect(_go('/settings', role), isNull);
      for (final r in [
        '/songs-tab',
        '/members',
        '/overview',
        '/parents',
        '/planning',
        '/history',
        '/statistics',
        '/people',
        '/attendance',
      ]) {
        expect(_go(r, role), '/signout', reason: r);
      }
    });
  });

  test('every role start page is allowed for that role (no redirect loop)', () {
    for (final role in Role.values) {
      expect(_go(role.defaultRoute, role), isNull, reason: role.name);
    }
  });

  test('role-loading check covers the gated routes', () {
    for (final r in ['/parents', '/signout', '/planning', '/history', '/members', '/overview']) {
      expect(isRoleGatedRoute(r), isTrue, reason: r);
    }
    expect(isRoleGatedRoute('/settings'), isFalse);
  });
}
