import 'package:flutter/material.dart';

import '../../../../shared/widgets/dialogs/ion_modal.dart';
import '../pages/person_create_page.dart';
import '../pages/person_detail_page.dart';

/// Ionic `modalController.create({ component: PersonPage, presentingElement,
/// backdropDismiss: false })` from the people list and the dashboard cards:
/// the person page as an iOS card modal / md full-screen modal.
Future<void> showPersonModal(BuildContext context, int personId) =>
    showPageModal<void>(
      context,
      barrierDismissible: false,
      builder: (_) => PersonDetailPage(personId: personId),
    );

/// Ionic people list "add" (PersonPage without existing player) as modal.
Future<void> showPersonCreateModal(BuildContext context) =>
    showPageModal<void>(
      context,
      barrierDismissible: false,
      builder: (_) => const PersonCreatePage(),
    );
