import 'package:flutter/material.dart';

import 'rd_unavailability_page.dart' show RdUnavailabilityPage;

/// Opens "Nicht verfügbar" for a person ([RdUnavailabilityPage]).
Future<void> openUnavailabilityPage(
  BuildContext context, {
  required int personId,
  String personName = '',
  bool forOther = false,
}) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      builder: (_) => RdUnavailabilityPage(personId: personId, personName: personName, forOther: forOther),
    ));
