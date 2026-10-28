import 'package:attendix/core/utils/ionic_route_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapIonicRoute', () {
    test('strips the /tabs prefix', () {
      expect(mapIonicRoute('/tabs/settings/tasks/12'), '/settings/tasks/12');
      expect(mapIonicRoute('/tabs/attendance/5'), '/attendance/5');
      expect(mapIonicRoute('/tabs/signout'), '/signout');
    });

    test('keeps query parameters', () {
      expect(
        mapIonicRoute('/tabs/settings/team-organization?tab=topics'),
        '/settings/team-organization?tab=topics',
      );
    });

    test('maps the protocol route', () {
      expect(mapIonicRoute('/tabs/attendance/42/protocol'),
          '/settings/protocol/42');
    });

    test('maps the former meetings area to the team organization', () {
      expect(mapIonicRoute('/tabs/settings/meetings/3'),
          '/settings/team-organization');
    });

    test('leaves Flutter routes untouched', () {
      expect(mapIonicRoute('/settings/tasks/1'), '/settings/tasks/1');
    });
  });
}
