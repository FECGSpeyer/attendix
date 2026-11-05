import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ionic settings `openPlayerModal`, `openApprovePersonModal` and
/// `openCreateInstanceModal` present PersonPage / RegisterPage as card
/// modals (`presentingElement`) instead of navigating to a page.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('archive, pending and "+" instance open card modals', () {
    final left = read('lib/features/settings/presentation/pages/left_players_page.dart');
    final pending = read('lib/features/settings/presentation/pages/pending_players_page.dart');
    final tenants = read('lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart');
    final person = read('lib/features/people/presentation/pages/person_detail_page.dart');

    expect(left, contains('await showPersonModal(context, id)'));
    expect(left, contains('if (result == PersonModalResult.activated)'));
    expect(pending, contains('showPersonModal(context, player.id!)'));
    for (final src in [left, pending]) {
      expect(src, isNot(contains("context.push('/people/")));
    }
    expect(tenants, contains('showTenantCreateModal(navigator.context)'));
    expect(tenants, isNot(contains("router.push('/tenants/new')")));

    // The person page closes its modal route with the Ionic dismiss data.
    expect(person, contains('_close(PersonModalResult.activated);'));
    expect(person, contains('_close(PersonModalResult.approved);'));
    expect(person, contains('Navigator.of(context).pop(result);'));
  });
}
