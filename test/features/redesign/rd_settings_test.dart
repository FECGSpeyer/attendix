import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/features/redesign/data/providers/rd_today_providers.dart';
import 'package:attendix/features/redesign/presentation/widgets/today/rd_today_common.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';

/// REDESIGN: Beta switch and Darstellung are stored on the device only;
/// helpers of "Heute".
void main() {
  tearDown(() => RedesignRoutes.active = false);

  group('RedesignSettings', () {
    test('defaults: old design, Petrol, automatic', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await loadInitialRedesignSettings();
      expect(s, const RedesignSettings());
      expect(s.enabled, isFalse);
      expect(s.world, RdFarbwelt.petrol);
      expect(s.themeMode, ThemeMode.system);
    });

    test('Bühne is always dark, otherwise the chosen mode', () {
      const s = RedesignSettings(world: RdFarbwelt.buehne, mode: RdBrightnessMode.light);
      expect(s.themeMode, ThemeMode.dark);
      expect(s.copyWith(world: RdFarbwelt.klar).themeMode, ThemeMode.light);
    });

    test('changes are stored and read back on the next start', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(redesignSettingsProvider.notifier);

      await notifier.setEnabled(true);
      await notifier.setWorld(RdFarbwelt.nachtblau);
      await notifier.setMode(RdBrightnessMode.dark);

      expect(RedesignRoutes.active, isTrue);
      expect(container.read(redesignEnabledProvider), isTrue);

      final restored = await loadInitialRedesignSettings();
      expect(
        restored,
        const RedesignSettings(
          enabled: true,
          world: RdFarbwelt.nachtblau,
          mode: RdBrightnessMode.dark,
        ),
      );

      await notifier.setEnabled(false);
      expect(RedesignRoutes.active, isFalse);
      expect((await loadInitialRedesignSettings()).enabled, isFalse);
    });

    test('the start value comes from main() and sets the router flag', () {
      final container = ProviderContainer(overrides: [
        initialRedesignSettingsProvider.overrideWithValue(
          const RedesignSettings(enabled: true, world: RdFarbwelt.klar),
        ),
      ]);
      addTearDown(container.dispose);
      expect(container.read(redesignSettingsProvider).world, RdFarbwelt.klar);
      expect(RedesignRoutes.active, isTrue);
    });

    test('unknown stored values fall back to the defaults', () async {
      SharedPreferences.setMockInitialValues({
        redesignFarbweltStorageKey: 'neon',
        redesignModeStorageKey: 'sepia',
      });
      final s = await loadInitialRedesignSettings();
      expect(s.world, RdFarbwelt.petrol);
      expect(s.mode, RdBrightnessMode.auto);
    });
  });

  group('Heute helpers', () {
    final l10n = lookupAppLocalizations(const Locale('de'));

    test('RdStatusCounts groups the statuses like the card', () {
      final c = RdStatusCounts.fromStatuses([
        AttendanceStatus.present,
        AttendanceStatus.late,
        AttendanceStatus.lateExcused,
        AttendanceStatus.excused,
        AttendanceStatus.excused,
        AttendanceStatus.absent,
        AttendanceStatus.neutral,
      ]);
      expect(c.present, 2);
      expect(c.lateAnnounced, 1);
      expect(c.excused, 2);
      expect(c.absent, 1);
      expect(c.open, 1);
      expect(c.total, 7);
    });

    test('rdStartOf combines date and start time', () {
      expect(rdStartOf('2026-10-30', '19:30'), DateTime(2026, 10, 30, 19, 30));
      expect(rdStartOf('2026-10-30', null), DateTime(2026, 10, 30));
      expect(rdStartOf(null, '19:30'), isNull);
    });

    test('rdThisWeek: the coming 7 days, at most three', () {
      final now = DateTime(2026, 10, 29, 10);
      final list = [
        TestFactories.createAttendance(id: 1, date: '2026-10-30'),
        TestFactories.createAttendance(id: 2, date: '2026-11-01'),
        TestFactories.createAttendance(id: 3, date: '2026-11-04'),
        TestFactories.createAttendance(id: 4, date: '2026-11-05'),
        TestFactories.createAttendance(id: 5, date: '2026-11-20'),
      ];
      expect(rdThisWeek(list, now: now).map((a) => a.id), [1, 2, 3]);
      expect(rdThisWeek(list, now: now, limit: 10).map((a) => a.id), [1, 2, 3, 4]);
    });

    test('rdRelativeDay and rdCountdown', () {
      final now = DateTime(2026, 10, 29, 16, 0);
      expect(rdRelativeDay(l10n, DateTime(2026, 10, 29, 19), now: now), 'Heute');
      expect(rdRelativeDay(l10n, DateTime(2026, 10, 30, 19), now: now), 'Morgen');
      expect(rdCountdown(l10n, DateTime(2026, 10, 29, 19, 30), now: now), 'in 4 Std.');
      expect(rdCountdown(l10n, DateTime(2026, 10, 29, 16, 25), now: now), 'in 25 Min.');
      expect(rdCountdown(l10n, DateTime(2026, 10, 29, 15), now: now), 'läuft');
      expect(rdCountdown(l10n, DateTime(2026, 10, 30, 19), now: now), isNull);
      expect(rdCountdown(l10n, DateTime(2026, 10, 29), hasTime: false, now: now), isNull);
    });
  });
}
