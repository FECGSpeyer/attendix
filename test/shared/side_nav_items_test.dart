import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/shared/widgets/layout/side_nav/nav_items.dart';
import 'package:attendix/shared/widgets/layout/side_nav/side_nav_layout.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _ids(List<NavGroup> groups) =>
    [for (final g in groups) for (final i in g.items) i.id];

void main() {
  test('modes follow the Ionic breakpoints', () {
    expect(sideNavModeFor(767), SideNavMode.none);
    expect(sideNavModeFor(768), SideNavMode.overlay);
    expect(sideNavModeFor(992), SideNavMode.fixed);
    expect(sideNavCollapsed(1100, null), isTrue);
    expect(sideNavCollapsed(1200, null), isFalse);
    expect(sideNavCollapsed(900, true), isFalse); // overlay is never a rail
  });

  test('admin gets three headed groups incl. "Mehr" areas', () {
    final groups = buildNavGroups(const NavContext(
      role: Role.admin,
      canAccessFiles: true,
      hasOrganisation: true,
      showTeam: true,
    ));
    expect(groups.map((g) => g.id),
        [NavGroupId.main, NavGroupId.team, NavGroupId.account]);
    expect(_ids(groups), [
      'dashboard', 'attendance', 'player', 'songs', 'planning',
      'team', 'messages', 'files', 'stats', 'organisation',
      'settings', 'help',
    ]);
  });

  test('player: entries without heading, account set apart', () {
    final groups = buildNavGroups(const NavContext(
      role: Role.player,
      hasMultipleTenants: true,
      showMembersList: true,
      canAccessFiles: true,
    ));
    expect(groups.first.label, isNull);
    expect(_ids(groups),
        ['signout', 'overview', 'members', 'songs', 'files', 'settings', 'help']);
  });

  test('longest matching route is active', () {
    final groups = buildNavGroups(
        const NavContext(role: Role.admin, canAccessFiles: true));
    expect(activeNavItemId(groups, '/settings/files'), 'files');
    expect(activeNavItemId(groups, '/settings/general'), 'settings');
    expect(activeNavItemId(groups, '/attendance/12?x=1'), 'attendance');
  });
}
