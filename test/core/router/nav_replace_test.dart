import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NAV_REPLACE: tenant pick and auto-navigation replace the history entry', () {
    final s = File('lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart').readAsStringSync();
    expect(RegExp(r'goReplacingHistory\(').allMatches(s).length, 2);
    expect(s, isNot(contains('router.go(home)')));
  });

  test('NAV_REPLACE: helper neglects the history report', () {
    final s = File('lib/core/router/go_replace.dart').readAsStringSync();
    expect(s, contains('Router.neglect('));
    expect(s, contains('navigatorKey.currentContext'));
  });

  test('NAV_REPLACE: Back onto /login with an open instance goes to its start page', () {
    final s = File('lib/core/router/app_router.dart').readAsStringSync();
    final i = s.indexOf('// NAV_REPLACE: browser Back onto /login');
    expect(i, greaterThan(0));
    final block = s.substring(i, s.indexOf("return '/tenants';", i));
    expect(block, contains('homeRouteFor('));
    expect(block, contains('wantInstanceSelection'));
  });
}
