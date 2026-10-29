import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// SOL_FIX39: Sol review 6497424908 on PR #236.
void main() {
  String src(String p) => File(p).readAsStringSync();

  test('people list restore aborts when the tenant changed meanwhile', () {
    final s = src('lib/features/people/presentation/pages/people_list_page.dart');
    expect(s, contains('bool _stillTenant(int? tenantId)'));
    expect(s, contains("ref.read(currentTenantProvider)?.id == tenantId"));
    expect(s, contains('_restoreOtherInstanceFilter(savedFilterAdd, tenant.id)'));
    expect(s, contains('if (!_stillTenant(tenantId)) return;'));
  });

  test('reactivation invalidates the cached person', () {
    final s = src('lib/features/people/presentation/pages/person_detail_page.dart');
    final i = s.indexOf('reactivatePlayer(widget.person)');
    expect(i, isNonNegative);
    expect(s.substring(i, i + 400), contains('ref.invalidate(personProvider('));
  });

  test('archive list refresh after push uses a captured container', () {
    final s = src('lib/features/settings/presentation/pages/left_players_page.dart');
    expect(s, contains('final container = ProviderScope.containerOf(context);'));
    expect(s, contains('container.invalidate(leftPlayersProvider);'));
    expect(s, isNot(contains("await context.push('/people/\${player.id}');\n                    ref.invalidate")));
  });
}
