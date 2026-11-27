import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_icon_service.dart';
import '../theme/app_palette.dart';

/// REDESIGN: settings of the app design (Farbwelt, brightness, app icon). Stored
/// only on this device (SharedPreferences), never in the database.

const redesignFarbweltStorageKey = 'redesign.farbwelt';
const redesignModeStorageKey = 'redesign.mode';
const redesignAppIconStorageKey = 'redesign.appIcon';

/// Hell / Dunkel / Automatisch of the app design.
enum RdBrightnessMode {
  auto('auto'),
  light('light'),
  dark('dark');

  const RdBrightnessMode(this.key);
  final String key;

  static RdBrightnessMode fromKey(String? key) => RdBrightnessMode.values
      .firstWhere((m) => m.key == key, orElse: () => RdBrightnessMode.auto);
}

@immutable
class RedesignSettings {
  const RedesignSettings({
    this.world = RdFarbwelt.petrol,
    this.mode = RdBrightnessMode.auto,
    this.appIcon = true,
  });

  final RdFarbwelt world;
  final RdBrightnessMode mode;

  /// The home screen icon follows the Farbwelt (iOS).
  final bool appIcon;

  /// Alternate app icon for these settings; null uses the default icon.
  String? get appIconName => appIcon ? world.appIconName : null;

  /// Bühne is always dark; otherwise the chosen mode.
  ThemeMode get themeMode {
    if (world.alwaysDark) return ThemeMode.dark;
    return switch (mode) {
      RdBrightnessMode.auto => ThemeMode.system,
      RdBrightnessMode.light => ThemeMode.light,
      RdBrightnessMode.dark => ThemeMode.dark,
    };
  }

  RedesignSettings copyWith({
    RdFarbwelt? world,
    RdBrightnessMode? mode,
    bool? appIcon,
  }) =>
      RedesignSettings(
        world: world ?? this.world,
        mode: mode ?? this.mode,
        appIcon: appIcon ?? this.appIcon,
      );

  @override
  bool operator ==(Object other) =>
      other is RedesignSettings &&
      other.world == world &&
      other.mode == mode &&
      other.appIcon == appIcon;

  @override
  int get hashCode => Object.hash(world, mode, appIcon);
}

/// Reads the stored settings. Called in main() before runApp so the first
/// frame already has the right shell and colours.
Future<RedesignSettings> loadInitialRedesignSettings() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return RedesignSettings(
      world: RdFarbwelt.fromKey(prefs.getString(redesignFarbweltStorageKey)),
      mode: RdBrightnessMode.fromKey(prefs.getString(redesignModeStorageKey)),
      appIcon: prefs.getBool(redesignAppIconStorageKey) ?? true,
    );
  } catch (_) {
    // Storage can be unavailable (private mode): defaults apply.
    return const RedesignSettings();
  }
}

/// Settings loaded in main(); overridden in the root ProviderScope.
final initialRedesignSettingsProvider =
    Provider<RedesignSettings>((ref) => const RedesignSettings());

final redesignSettingsProvider =
    NotifierProvider<RedesignSettingsNotifier, RedesignSettings>(
  RedesignSettingsNotifier.new,
);

class RedesignSettingsNotifier extends Notifier<RedesignSettings> {
  @override
  RedesignSettings build() => ref.watch(initialRedesignSettingsProvider);

  Future<void> setWorld(RdFarbwelt world) async {
    _update(state.copyWith(world: world));
    await _store((p) => p.setString(redesignFarbweltStorageKey, world.key));
  }

  Future<void> setAppIcon(bool follow) async {
    _update(state.copyWith(appIcon: follow));
    await _store((p) => p.setBool(redesignAppIconStorageKey, follow));
  }

  /// New state; switches the home screen icon when it changes.
  void _update(RedesignSettings next) {
    final icon = state.appIconName;
    state = next;
    if (next.appIconName != icon) unawaited(AppIconService.setIcon(next.appIconName));
  }

  Future<void> setMode(RdBrightnessMode mode) async {
    state = state.copyWith(mode: mode);
    await _store((p) => p.setString(redesignModeStorageKey, mode.key));
  }

  Future<void> _store(Future<bool> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // Not stored (private mode): the choice still applies until restart.
    }
  }
}
