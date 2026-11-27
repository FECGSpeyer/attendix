part of 'sibelius_sync.dart';

/// The plug-in as this app installs it: it brings this app to the front.
Uint8List rdSibeliusPluginOfThisApp() =>
    rdSibeliusPluginBytes(rdSibeliusPluginFor(rdAttendixAppPath(Platform.resolvedExecutable)));

const String _pluginInstalledKey = 'rd_sibelius_plugin_installed';
const String _pluginHintDismissedKey = 'rd_sibelius_plugin_hint_dismissed';

/// Whether the Attendix plug-in is in Sibelius' plug-ins folder (Mac app).
/// Where the app may not look there (older build, no Sibelius yet), whether
/// it was installed from here. A plug-in of an older Attendix is brought up
/// to date on the way. Checked again each time a Werk page asks.
final rdSibeliusPluginInstalledProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (!rdSibeliusSupported) return false;
  final home = await ref.read(rdSibeliusSyncProvider.notifier).home();
  if (home != null) {
    final plugins = Directory(rdSibeliusPluginsFolder(home));
    try {
      if (await plugins.exists()) {
        final file = File('${plugins.path}/$rdSibeliusPluginCategory/$rdSibeliusPluginFileName');
        if (!await file.exists()) return false;
        final bytes = rdSibeliusPluginOfThisApp();
        if (!listEquals(await file.readAsBytes(), bytes)) await file.writeAsBytes(bytes, flush: true);
        return true;
      }
    } catch (e) {
      debugPrint('[RdSibeliusSync] plug-ins folder: $e');
    }
  }
  try {
    return (await SharedPreferences.getInstance()).getBool(_pluginInstalledKey) ?? false;
  } catch (_) {
    return false;
  }
});

/// Whether the Werk page shows the hint "Stimmen direkt aus Sibelius" (Mac
/// app): while the plug-in is not installed, unless the hint was closed
/// (then never again).
class RdSibeliusPluginHint extends AutoDisposeAsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    if (!rdSibeliusSupported) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_pluginHintDismissedKey) ?? false) return false;
    } catch (_) {
      return false;
    }
    return !await ref.watch(rdSibeliusPluginInstalledProvider.future);
  }

  Future<void> dismiss() async {
    state = const AsyncData(false);
    try {
      await (await SharedPreferences.getInstance()).setBool(_pluginHintDismissedKey, true);
    } catch (_) {
      // Shown again after the next start.
    }
  }
}

/// Remembers that the plug-in was installed from here (for where the app
/// may not look into the plug-ins folder); then invalidate
/// [rdSibeliusPluginInstalledProvider].
Future<void> rdRememberSibeliusPluginInstalled() async {
  try {
    await (await SharedPreferences.getInstance()).setBool(_pluginInstalledKey, true);
  } catch (_) {
    // Checked in the folder anyway where possible.
  }
}

final rdSibeliusPluginHintProvider = AsyncNotifierProvider.autoDispose<RdSibeliusPluginHint, bool>(
  RdSibeliusPluginHint.new,
);
