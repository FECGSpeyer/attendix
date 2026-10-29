import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SOL_FIX25: asked before the shell replaces the current page (tab switch
/// via `context.go`). Returns false to stay on the page.
typedef RouteLeaveGuard = Future<bool> Function();

/// SOL_FIX25: pages with pending work (e.g. the Ablaufplan editor) register
/// a guard here; [MainShell] awaits [canLeave] before it switches tabs.
///
/// A `context.go` replaces the page stack without asking `PopScope`, so
/// without this the page would be disposed with unsaved edits. Ionic opens
/// such editors as modals that cover the tab bar, so a tab switch there
/// always happens after the editor saved and closed.
class RouteLeaveGuardRegistry {
  final List<RouteLeaveGuard> _guards = [];
  bool _checking = false;

  /// Whether a guard is registered.
  bool get hasGuards => _guards.isNotEmpty;

  void add(RouteLeaveGuard guard) => _guards.add(guard);

  void remove(RouteLeaveGuard guard) => _guards.remove(guard);

  /// Asks every guard (newest first). False when one of them says stay,
  /// throws, or a check is already running (double tap).
  Future<bool> canLeave() async {
    if (_guards.isEmpty) return true;
    if (_checking) return false;
    _checking = true;
    try {
      for (final guard in _guards.reversed.toList()) {
        if (!await guard()) return false;
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      _checking = false;
    }
  }
}

/// SOL_FIX25: one registry per [ProviderContainer] (app-wide).
final routeLeaveGuardRegistryProvider =
    Provider<RouteLeaveGuardRegistry>((ref) => RouteLeaveGuardRegistry());
