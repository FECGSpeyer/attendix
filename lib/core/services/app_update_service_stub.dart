import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'native/native_platform.dart';
import 'native/store_update_service.dart';

/// Provider for app update availability state
final appUpdateAvailableProvider = StateProvider<bool>((ref) => false);

/// Provider for AppUpdateService
final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService(ref);
});

/// Non-web implementation.
///
/// NATIVE_MISC: in the installed iOS/Android app this is the counterpart of
/// Ionic's native `LiveUpdateService`: it checks the store once on start and
/// sets [appUpdateAvailableProvider]; [applyUpdate] runs the store update
/// ("Update installieren" on login + settings). Desktop: no-op.
class AppUpdateService {
  AppUpdateService(this._ref, {StoreUpdateService? store})
      : _store = store ?? StoreUpdateService();

  final Ref _ref;
  final StoreUpdateService _store;
  Future<void> Function()? _apply;
  bool _started = false;

  void startListening() {
    if (_started || !isNativeApp) return;
    _started = true;
    unawaited(_store.check().then((apply) {
      if (apply == null) return;
      _apply = apply;
      try {
        _ref.read(appUpdateAvailableProvider.notifier).state = true;
      } catch (_) {
        // Container disposed.
      }
    }));
  }

  void applyUpdate() {
    final apply = _apply;
    if (apply != null) unawaited(apply());
  }

  void markDialogShown() {}

  /// Native: no global snackbar – like Ionic the update is offered on the
  /// login page and in the settings menu only.
  bool get wasDialogShown => true;

  void resetDialogShown() {}
  void dispose() {}
}
