import 'package:attendix/core/router/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Notifications, pushes and "open attendance" links lead to the standard
/// app routes.
void main() {
  test('Termine and lists open on their canonical routes', () {
    expect(RedesignRoutes.betaTarget('/attendance/5'), '/termine/5');
    expect(RedesignRoutes.betaTarget('/signout'), '/termine');
    expect(RedesignRoutes.betaTarget('/attendance'), '/termine');
    expect(RedesignRoutes.betaTarget('/people'), '/mitglieder');
  });

  test('query and fragment stay (tenant switch of a push)', () {
    expect(RedesignRoutes.betaTarget('/attendance?tenantId=4'), '/termine?tenantId=4');
    expect(RedesignRoutes.betaTarget('/attendance/5?tenantId=4'), '/termine/5?tenantId=4');
    expect(RedesignRoutes.betaTarget('/signout?tenantId=4#top'), '/termine?tenantId=4#top');
  });

  test('other pages stay (protocol, messages, settings, parents)', () {
    for (final l in [
      '/attendance/5/protocol',
      '/messages/3',
      '/settings/team-organization?tab=tasks',
      '/parents',
      '/people/4',
    ]) {
      expect(RedesignRoutes.betaTarget(l), l);
    }
  });

  test('legacyTarget: old start pages open the canonical ones, sub pages stay', () {
    expect(RedesignRoutes.legacyTarget('/attendance/5'), RedesignRoutes.event(5));
    expect(RedesignRoutes.legacyTarget('/signout'), RedesignRoutes.events);
    expect(RedesignRoutes.legacyTarget('/people'), RedesignRoutes.members);
    expect(RedesignRoutes.legacyTarget('/settings'), RedesignRoutes.me);
    expect(RedesignRoutes.legacyTarget('/settings/notifications'), isNull);
    expect(RedesignRoutes.legacyTarget('/people/3'), RedesignRoutes.person(3));
  });
}
