import 'package:attendix/core/router/redesign_routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Notifications, pushes and "open attendance" links lead to the pages of
/// the new design while the Beta is on.
void main() {
  tearDown(() => RedesignRoutes.active = false);

  test('without the Beta every location stays', () {
    RedesignRoutes.active = false;
    for (final l in ['/attendance/5', '/signout', '/attendance', '/people', '/messages/3']) {
      expect(RedesignRoutes.betaTarget(l), l);
    }
  });

  test('with the Beta Termine and lists open on their new pages', () {
    RedesignRoutes.active = true;
    expect(RedesignRoutes.betaTarget('/attendance/5'), '/termine/5');
    expect(RedesignRoutes.betaTarget('/signout'), '/termine');
    expect(RedesignRoutes.betaTarget('/attendance'), '/termine');
    expect(RedesignRoutes.betaTarget('/people'), '/mitglieder');
  });

  test('with the Beta query and fragment stay (tenant switch of a push)', () {
    RedesignRoutes.active = true;
    expect(RedesignRoutes.betaTarget('/attendance?tenantId=4'), '/termine?tenantId=4');
    expect(RedesignRoutes.betaTarget('/attendance/5?tenantId=4'), '/termine/5?tenantId=4');
    expect(RedesignRoutes.betaTarget('/signout?tenantId=4#top'), '/termine?tenantId=4#top');
  });

  test('with the Beta other pages stay (protocol, messages, settings, parents)', () {
    RedesignRoutes.active = true;
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
}
