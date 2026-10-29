import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../router/redesign_routes.dart';
import '../services/app_icon_service.dart';
import '../theme/redesign/rd_palette.dart';

/// REDESIGN: settings of the new design (Beta). Stored only on this device
/// (SharedPreferences), never in the database.

const redesignEnabledStorageKey = 'redesign.enabled';
const redesignFarbweltStorageKey = 'redesign.farbwelt';
const redesignModeStorageKey = 'redesign.mode';
const redesignAppIconStorageKey = 'redesign.appIcon';

/// Hell / Dunkel / Automatisch of the new design.
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
    this.enabled = false,
    this.world = RdFarbwelt.petrol,
    this.mode = RdBrightnessMode.auto,
    this.appIcon = true,
  });

  /// "Neues Design (Beta)" switched on.
  final bool enabled;
  final RdFarbwelt world;
  final RdBrightnessMode mode;

  /// The home screen icon follows the Farbwelt (iOS).
  final bool appIcon;

  /// Alternate app icon for these settings; null: the default icon (also
  /// whenever the old design is on).
  String? get appIconName => enabled && appIcon ? world.appIconName : null;

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
    bool? enabled,
    RdFarbwelt? world,
    RdBrightnessMode? mode,
    bool? appIcon,
  }) =>
      RedesignSettings(
        enabled: enabled ?? this.enabled,
        world: world ?? this.world,
        mode: mode ?? this.mode,
        appIcon: appIcon ?? this.appIcon,
      );

  @override
  bool operator ==(Object other) =>
      other is RedesignSettings &&
      other.enabled == enabled &&
      other.world == world &&
      other.mode == mode &&
      other.appIcon == appIcon;

  @override
  int get hashCode => Object.hash(enabled, world, mode, appIcon);
}

/// Reads the stored settings. Called in main() before runApp so the first
/// frame already has the right shell and colours.
Future<RedesignSettings> loadInitialRedesignSettings() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return RedesignSettings(
      enabled: prefs.getBool(redesignEnabledStorageKey) ?? false,
      world: RdFarbwelt.fromKey(prefs.getString(redesignFarbweltStorageKey)),
      mode: RdBrightnessMode.fromKey(prefs.getString(redesignModeStorageKey)),
      appIcon: prefs.getBool(redesignAppIconStorageKey) ?? true,
    );
  } catch (_) {
    // Storage can be unavailable (private mode): old design.
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

/// Whether the new design is switched on.
final redesignEnabledProvider = Provider<bool>(
  (ref) => ref.watch(redesignSettingsProvider.select((s) => s.enabled)),
);

class RedesignSettingsNotifier extends Notifier<RedesignSettings> {
  @override
  RedesignSettings build() {
    final initial = ref.watch(initialRedesignSettingsProvider);
    RedesignRoutes.active = initial.enabled;
    return initial;
  }

  Future<void> setEnabled(bool enabled) async {
    _update(state.copyWith(enabled: enabled));
    RedesignRoutes.active = enabled;
    await _store((p) => p.setBool(redesignEnabledStorageKey, enabled));
  }

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
