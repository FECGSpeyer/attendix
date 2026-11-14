import 'package:attendix/features/tenant_selection/presentation/pages/tenant_selection_page.dart';
import 'package:patrol/patrol.dart';

import 'support/app.dart';

void main() {
  patrolTest('Anmeldung mit Passwort (Beta)', ($) async {
    await startApp($);
    await signIn($, email: 'admin@attendix.test');
    await $(TenantSelectionPage)
        .waitUntilVisible(timeout: const Duration(seconds: 30));
  });

  patrolTest('Anmeldung mit Passwort (klassisch)', ($) async {
    await startApp($, beta: false);
    await signIn($, email: 'admin@attendix.test');
    await $(TenantSelectionPage)
        .waitUntilVisible(timeout: const Duration(seconds: 30));
  });
}
