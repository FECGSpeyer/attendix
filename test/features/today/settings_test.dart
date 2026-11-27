import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/appearance_providers.dart';
import 'package:attendix/core/theme/app_palette.dart';
import 'package:attendix/features/today/data/providers/today_providers.dart';
import 'package:attendix/features/today/presentation/widgets/today_common.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Darstellung settings stored on device and helpers of "Heute".
void main() {
  group('RedesignSettings', () {
    test('defaults: Petrol, automatic', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await loadInitialRedesignSettings();
      expect(s, const RedesignSettings());
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

      await notifier.setWorld(RdFarbwelt.nachtblau);
      await notifier.setMode(RdBrightnessMode.dark);

      final restored = await loadInitialRedesignSettings();
      expect(
        restored,
        const RedesignSettings(
          world: RdFarbwelt.nachtblau,
          mode: RdBrightnessMode.dark,
        ),
      );
    });

    test('the start value comes from main()', () {
      final container = ProviderContainer(overrides: [
        initialRedesignSettingsProvider.overrideWithValue(
          const RedesignSettings(world: RdFarbwelt.klar),
        ),
      ]);
      addTearDown(container.dispose);
      expect(container.read(redesignSettingsProvider).world, RdFarbwelt.klar);
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
