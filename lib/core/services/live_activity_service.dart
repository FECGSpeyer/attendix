import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/plan/plan.dart';
import '../../data/models/tenant/tenant.dart';
import '../../data/repositories/org_plan_repository.dart';
import '../../features/planning/presentation/pages/plan_viewer_page.dart';
import '../../l10n/l10n.dart';
import '../config/supabase_config.dart';
import '../constants/enums.dart';
import '../providers/attendance_type_providers.dart';
import '../providers/live_activity_providers.dart';
import '../providers/organisation_providers.dart';
import '../providers/plan_providers.dart';
import '../providers/self_service_providers.dart';
import '../providers/tenant_providers.dart';
import '../providers/user_preferences_provider.dart';
import '../router/app_router.dart';
import '../router/redesign_routes.dart';
import '../utils/live_plan.dart';
import '../utils/plan_utils.dart';
import 'error_reporter.dart';

part 'live_activity_host.dart';
part 'live_activity_models.dart';
part 'live_activity_sync.dart';

/// Core session, token, and deep-link lifecycle state for [LiveActivityService].
abstract class _LiveActivityServiceCore {
  _LiveActivityServiceCore({
    required LiveActivityHost host,
    MethodChannel? channel,
    bool? platformSupported,
    bool? isAndroid,
    int Function()? now,
    bool listenToLifecycle = true,
    this.nativeCloseTimeout = const Duration(seconds: 10),
  })  : _host = host,
        _channel =
            channel ?? const MethodChannel(LiveActivityService.channelName),
        _platformSupported =
            platformSupported ?? LiveActivityService.isSupportedPlatform,
        _isAndroid = isAndroid ?? LiveActivityService.isAndroidPlatform,
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
        _listenToLifecycle = listenToLifecycle;

  /// SOL_FIX18: how long [endSession] waits for the native side to stop its
  /// own token uploads (in-flight URLSession requests) – the logout must not
  /// hang on a slow network.
  final Duration nativeCloseTimeout;

  final LiveActivityHost _host;
  final MethodChannel _channel;
  final bool _platformSupported;
  final bool _isAndroid;
  final int Function() _now;
  final bool _listenToLifecycle;

  bool _attached = false;
  bool _supported = false;
  bool _started = false;
  bool _enabled = true;
  bool _orgPlansEnabled = true;
  bool _syncing = false;
  int? _loadedTenantId;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  Uri? _pendingUri;

  /// Last state pushed per plan, to skip no-op updates.
  final Map<String, String> _lastKeys = {};

  /// Activities started or updated by this service for the current tenant/org,
  /// so a deleted, archived, or un-planned Termin is ended on the next sync
  /// instead of remaining as a ghost activity.
  final Set<String> _ownedKeys = {};

  /// SOL_FIX15: account the tokens were registered for, and the tokens this
  /// device saved for it (removed again on logout).
  String? _sessionUserId;
  final Set<String> _savedTokens = {};

  /// Account whose tokens are registered on this device (null = none).
  String? get sessionUserId => _sessionUserId;

  /// SOL_FIX16: session generation, bumped synchronously by [endSession].
  int _generation = 0;

  bool _isStale(int generation) => generation != _generation;

  /// SOL_FIX17: token registration is open only while a session is
  /// initialised ([init] opens it, [endSession] closes it synchronously).
  bool _registrationOpen = false;

  /// SOL_FIX17: token upserts still running; [endSession] waits for them
  /// before it deletes this device's token rows.
  final Set<Future<void>> _pendingWrites = {};

  /// SOL_FIX17: bumped by [setEnabled]. A sync that started before the
  /// toggle changed must not start or update activities afterwards.
  int _enableEpoch = 0;

  /// SOL_FIX19: session teardowns ([endSession]) that are still running.
  final Set<Future<void>> _teardowns = {};

  /// True when this build has the native side (Ionic `hasNativePlugin`);
  /// controls the toggle in the notification settings.
  bool get hasNativePlugin => _platformSupported;

  /// Live Activities are allowed on this device (iOS 16.2+, user setting).
  bool get isSupported => _supported;
  bool get isEnabled => _enabled;
  bool get isOrgPlansEnabled => _orgPlansEnabled;
  bool get isLoopRunning => _timer != null;

  Future<void> startLoop();
  void stopLoop();

  /// Once at app start: receives native events and a deep link that launched the app.
  Future<void> attach() async {
    if (!_platformSupported || _attached) return;
    _attached = true;
    try {
      _channel.setMethodCallHandler(_onNativeCall);
      final url = await _channel.invokeMethod<String>('takePendingUrl');
      if (url != null && url.isNotEmpty) await openFromUrl(Uri.parse(url));
    } catch (e) {
      _log('attach', e);
    }
  }

  /// Ionic effect: (re)initialise when tenant and tenant user are loaded and the tenant changed.
  ///
  /// SOL_FIX15: without a tenant (logout, tenant cleared) the running
  /// activities end and the service is reset, so the next tenant – of this
  /// or another account – initialises again. An account change ([userId]
  /// differs from the account the tokens were registered for) resets too.
  Future<void> onTenantReady(
    int? tenantId, {
    required bool hasTenantUser,
    String? userId,
  }) async {
    if (tenantId == null) {
      if (_loadedTenantId != null || _started) await endSession();
      return;
    }
    if (_sessionUserId != null && userId != null && userId != _sessionUserId) {
      await endSession();
    }
    if (!hasTenantUser || tenantId == _loadedTenantId) return;
    _loadedTenantId = tenantId;
    _ownedKeys.clear();
    await init();
  }

  /// SOL_FIX15: logout / account switch. Ends every Live Activity and resets
  /// the session state so tokens are registered again for the next account.
  ///
  /// SOL_FIX19: the returned teardown is tracked; [init] (the next session)
  /// and [sync] wait for every running teardown.
  Future<void> endSession({String? removeTokensOf}) {
    late final Future<void> teardown;
    teardown = _endSession(removeTokensOf).whenComplete(() {
      _teardowns.remove(teardown);
    });
    _teardowns.add(teardown);
    return teardown;
  }

  Future<void> _awaitTeardowns() async {
    while (_teardowns.isNotEmpty) {
      try {
        await Future.wait(_teardowns.toList());
      } catch (e) {
        _log('teardown', e);
      }
    }
  }

  Future<void> _endSession(String? removeTokensOf) async {
    // SOL_FIX16: invalidate running init / sync calls and reset synchronously.
    _generation++;
    _registrationOpen = false;
    _syncing = false;
    stopLoop();
    _lifecycle?.dispose();
    _lifecycle = null;
    _lastKeys.clear();
    _ownedKeys.clear();
    _pendingUri = null;
    final sessionUserId = _sessionUserId;
    final savedTokens = {..._savedTokens};
    _savedTokens.clear();
    final inFlight = _pendingWrites.toList();
    _sessionUserId = null;
    _loadedTenantId = null;
    _started = false;
    _enabled = true;
    _orgPlansEnabled = true;
    await _setNativeRegistrationOpen(false);
    if (_platformSupported) {
      try {
        await _channel.invokeMethod<void>('endAll');
      } catch (e) {
        _log('endAll', e);
      }
    }
    final owner = removeTokensOf;
    if (owner != null && (sessionUserId == null || sessionUserId == owner)) {
      if (inFlight.isNotEmpty) await Future.wait(inFlight);
      final tokens = {...savedTokens, ...await _deviceTokens()}.toList();
      if (tokens.isNotEmpty) {
        try {
          await _host.removeTokens(userId: owner, tokens: tokens);
        } catch (e) {
          _log('Live Activity tokens not removed', e);
        }
      }
    }
  }

  /// Tokens the native side currently holds (start + activity tokens).
  Future<Set<String>> _deviceTokens() async {
    if (!_platformSupported) return {};
    try {
      final tokens = await _channel.invokeMapMethod<String, dynamic>('getTokens');
      return {
        if (tokens?['pushToStartToken'] case final String t when t.isNotEmpty) t,
        for (final raw in (tokens?['activityTokens'] as List?) ?? const [])
          if (raw is Map && raw['token'] is String) raw['token'] as String,
      };
    } catch (_) {
      return {};
    }
  }

  /// SOL_FIX18: opens / closes the native (iOS) token uploads.
  Future<void> _setNativeRegistrationOpen(bool open) async {
    if (!_platformSupported || _isAndroid) return;
    try {
      await _channel
          .invokeMethod<void>('setRegistrationOpen', {'open': open})
          .timeout(nativeCloseTimeout);
    } catch (e) {
      _log('setRegistrationOpen($open)', e);
    }
  }

  Future<void> init() async {
    if (!_platformSupported) return;
    final generation = _generation;
    if (_teardowns.isNotEmpty) {
      await _awaitTeardowns();
      if (_isStale(generation)) return;
    }
    final epoch = _enableEpoch;
    bool supported;
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('isAvailable');
      supported = result?['available'] == true;
    } catch (_) {
      supported = false;
    }
    if (_isStale(generation)) return;
    _supported = supported;
    if (!_supported) {
      await _flushPendingUri();
      return;
    }

    await LiveTimezone.ensureInitialized();
    if (_isStale(generation)) return;
    final enabled = await _loadEnabled();
    if (_isStale(generation)) return;
    final orgPlansEnabled = await _loadOrgPlansEnabled();
    if (_isStale(generation)) return;
    if (epoch == _enableEpoch) {
      _enabled = enabled;
      _orgPlansEnabled = orgPlansEnabled;
    }
    if (!_started) {
      _started = true;
      _registrationOpen = true;
      await _registerTokens(generation);
      if (_isStale(generation)) return;
      if (_listenToLifecycle) {
        try {
          _lifecycle = AppLifecycleListener(
            onResume: () => unawaited(startLoop()),
            onInactive: stopLoop,
          );
        } catch (e) {
          _log('lifecycle', e);
        }
      }
    }
    if (_isStale(generation)) return;
    await startLoop();
    await _flushPendingUri();
  }

  Future<bool> _loadEnabled() async {
    try {
      return await _host.loadEnabled();
    } catch (_) {
      return true;
    }
  }

  Future<bool> _loadOrgPlansEnabled() async {
    try {
      return await _host.loadOrgPlansEnabled();
    } catch (_) {
      return true;
    }
  }

  Future<void> _registerTokens(int generation) async {
    if (_isAndroid) {
      await _saveToken('start', 'android', generation: generation);
    } else {
      if (_isStale(generation)) return;
      await _setNativeRegistrationOpen(true);
      try {
        if (_isStale(generation)) return;
        await _channel.invokeMethod<void>(
          'configure',
          {'url': _host.apiUrl, 'key': _host.apiKey},
        );
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'live_activity_service');
      }
    }
    try {
      if (_isStale(generation)) return;
      final tokens = await _channel.invokeMapMethod<String, dynamic>('getTokens');
      final start = tokens?['pushToStartToken'];
      if (start is String && start.isNotEmpty) {
        await _saveToken('start', start, generation: generation);
      }
      for (final raw in (tokens?['activityTokens'] as List?) ?? const []) {
        final target = LiveActivityTarget.fromMap(raw);
        final token = raw is Map ? raw['token'] : null;
        if (token is String) {
          await _saveToken(
            'update',
            token,
            target: target,
            generation: generation,
          );
        }
      }
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'live_activity_service');
    }
  }

  /// [generation]: the session the registration started in (SOL_FIX16);
  /// native token events pass none and use the current session.
  Future<void> _saveToken(
    String kind,
    String token, {
    LiveActivityTarget? target,
    int? generation,
  }) async {
    if (!_registrationOpen) return;
    if (generation != null && _isStale(generation)) return;
    final userId = _host.userId;
    if (userId == null || token.isEmpty) return;
    if (_sessionUserId != null && _sessionUserId != userId) return;
    _sessionUserId = userId;
    if (kind != 'start' || token != 'android') _savedTokens.add(token);
    final write = _write(userId, kind, token, target);
    _pendingWrites.add(write);
    unawaited(write.whenComplete(() => _pendingWrites.remove(write)));
    await write;
  }

  Future<void> _write(
    String userId,
    String kind,
    String token,
    LiveActivityTarget? target,
  ) async {
    try {
      await _host.saveToken(
        userId: userId,
        kind: kind,
        token: token,
        attendanceId: target?.attendanceId ?? 0,
        planKey: target?.planKey ?? '',
      );
    } catch (e) {
      _log('Live Activity token not saved', e);
    }
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    final args = call.arguments;
    switch (call.method) {
      case 'pushToStartToken':
        final token = args is Map ? args['token'] : null;
        if (token is String) await _saveToken('start', token);
        return null;
      case 'activityToken':
        final token = args is Map ? args['token'] : null;
        final target = LiveActivityTarget.fromMap(args);
        if (token is String && target != null) {
          await _saveToken('update', token, target: target);
        }
        return null;
      case 'openUrl':
        if (args is String) await openFromUrl(Uri.parse(args));
        return null;
    }
    return null;
  }

  /// Handles attendix://live-plan?attendance=…&plan=… from a tap on the Live
  /// Activity. Returns true when handled.
  Future<bool> openFromUrl(Uri url) async {
    if (url.scheme != 'attendix' || url.host != 'live-plan') return false;
    final attendanceId = int.tryParse(url.queryParameters['attendance'] ?? '') ?? 0;
    final planKey = url.queryParameters['plan'] ?? '';
    final orgPlanId = attendanceId == 0 && planKey.startsWith('org-')
        ? planKey.substring(4)
        : null;
    if (attendanceId == 0 && (orgPlanId == null || orgPlanId.isEmpty)) {
      return true;
    }
    if (_host.tenantId == null) {
      _pendingUri = url;
      return true;
    }
    try {
      if (orgPlanId != null) {
        await _host.openSharedOrgPlan(orgPlanId);
      } else {
        await _host.openPlan(attendanceId, planKey: planKey);
      }
    } catch (e) {
      _log('openFromUrl', e);
    }
    return true;
  }

  Future<void> _flushPendingUri() async {
    final uri = _pendingUri;
    if (uri == null || _host.tenantId == null) return;
    _pendingUri = null;
    await openFromUrl(uri);
  }

  void dispose() {
    stopLoop();
    _lifecycle?.dispose();
    _lifecycle = null;
    if (_attached) {
      try {
        _channel.setMethodCallHandler(null);
      } catch (_) {}
    }
  }

  void _log(String what, Object error) {
    if (kDebugMode) debugPrint('[LiveActivity] $what failed: $error');
  }
}

/// Shows the currently running Ablaufplan as iOS Live Activity / Dynamic
/// Island. While the app is open it starts and updates them itself; with the
/// app closed the `live-activity-tick` Edge Function does it via push, using
/// the tokens registered here.
///
/// Talks to ios/Runner/LiveActivityPlugin.swift and (DB_REVIEW_REST F2)
/// android/.../liveplan/LiveActivityPlugin.kt (ongoing "Ablaufplan"
/// notification, Ionic LiveActivityPlugin.java) over [channelName]. No-op on
/// web; every native call is wrapped in try/catch, so builds without the
/// native side simply skip everything.
class LiveActivityService extends _LiveActivityServiceCore
    with _LiveActivitySyncMixin {
  LiveActivityService({
    required super.host,
    super.channel,
    super.platformSupported,
    super.isAndroid,
    super.now,
    super.listenToLifecycle,
    super.nativeCloseTimeout,
  });

  static const String channelName = 'de.attendix/live_activity';

  /// How often the open app re-checks running plans (the widget counts down on its own).
  static const Duration syncInterval = Duration(seconds: 20);

  /// Multi-day Termine can have started up to this many days ago.
  static const int lookbackDays = 14;

  /// Native iOS or Android app (not the PWA).
  static bool get isSupportedPlatform {
    try {
      return !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android);
    } catch (_) {
      return false;
    }
  }

  /// Native Android app: live plan notification instead of a Live Activity.
  static bool get isAndroidPlatform {
    try {
      return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    } catch (_) {
      return false;
    }
  }
}
