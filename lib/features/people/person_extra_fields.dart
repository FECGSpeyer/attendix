import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/profile_providers.dart';
import '../../data/models/tenant/tenant.dart';

/// Ionic VoS "Andere Orchester" options.
const otherOrchestraOptions = ['SoS', 'GoS', 'BoS'];

/// Person extra fields: organisation fields first, then tenant fields not
/// overridden by the organisation (Ionic getPersonExtraFields).
List<ExtraField> personExtraFields(WidgetRef ref, Tenant? tenant) {
  final all = ref.watch(personExtraFieldsProvider).valueOrNull;
  if (all == null) return tenant?.additionalFields ?? const [];
  return all
      .map((f) => ExtraField(
            id: f.id,
            name: f.name,
            type: f.type,
            defaultValue: f.defaultValue,
            options: f.options,
            visibleToPlayers: f.visibleToPlayers,
            editableByPlayers: f.editableByPlayers,
          ))
      .toList();
}
