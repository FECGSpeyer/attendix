import 'package:attendix/core/providers/dashboard_providers.dart';
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dashboardTeamOrgEnabledProvider', () {
    test('follows teamOrgEnabledProvider (enabled)', () {
      final container = ProviderContainer(overrides: [
        teamOrgEnabledProvider.overrideWithValue(true),
      ]);
      addTearDown(container.dispose);
      expect(container.read(dashboardTeamOrgEnabledProvider), isTrue);
    });

    test('follows teamOrgEnabledProvider (disabled)', () {
      final container = ProviderContainer(overrides: [
        teamOrgEnabledProvider.overrideWithValue(false),
      ]);
      addTearDown(container.dispose);
      expect(container.read(dashboardTeamOrgEnabledProvider), isFalse);
    });
  });
}
