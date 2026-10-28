import '../../l10n/l10n.dart';

/// Utility functions for tenant-type-dependent labels.
///
/// Tenant types: 'choir', 'orchestra', or default ('general'/empty).

/// Returns the singular label for groups based on tenant type.
/// choir → Stimme, orchestra → Instrument, default → Gruppe
String groupLabel(String? tenantType) {
  return switch (tenantType) {
    'choir' => l10nWithoutContext.commonGroupLabelVoice,
    'orchestra' => l10nWithoutContext.commonGroupLabelInstrument,
    _ => l10nWithoutContext.commonGroupLabelGroup,
  };
}

/// Returns the plural label for groups based on tenant type.
/// choir → Stimmen, orchestra → Instrumente, default → Gruppen
String groupLabelPlural(String? tenantType) {
  return switch (tenantType) {
    'choir' => l10nWithoutContext.coreFlutterVoices,
    'orchestra' => l10nWithoutContext.peopleInstruments,
    _ => l10nWithoutContext.settingsGroups,
  };
}
