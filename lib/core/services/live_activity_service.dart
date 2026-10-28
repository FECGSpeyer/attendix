import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/plan/plan.dart';
import '../../features/planning/presentation/pages/plan_viewer_page.dart';
import '../config/supabase_config.dart';
import '../constants/enums.dart';
import '../providers/live_activity_providers.dart';
import '../providers/plan_providers.dart';
import '../providers/tenant_providers.dart';
import '../router/app_router.dart';
import '../utils/live_plan.dart';
import '../utils/plan_utils.dart';

// LIVE_ACTIVITY: port of Ionic src/app/services/live-activity/*.

/// A Live Activity of one plan of a Termin.
class LiveActivityTarget {
  const LiveActivityTarget({required this.attendanceId, required this.planKey});

  final int attendanceId;
  final String planKey;

  String get key => '$attendanceId:$planKey';

  static LiveActivityTarget? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['attendanceId'];
    final planKey = raw['planKey'];
    if (id is! num || planKey is! String) return null;
    return LiveActivityTarget(attendanceId: id.toInt(), planKey: planKey);
  }
}

/// A plan that should show a Live Activity right now.
class LivePlanCandidate extends LiveActivityTarget {
  const LivePlanCandidate({
    required super.attendanceId,
    required super.planKey,
    required this.title,
    required this.state,
  });

  final String title;
  final LivePlanState state;
}

/// What the service needs from the app (tenant, role, data access, navigation).
abstract class LiveActivityHost {
  int? get tenantId;

  /// IANA time zone of the tenant's plan times.
  String get timezone;
  Role get role;
  String? get userId;

  /// Supabase URL and anon key, for the native background token upload.
  String get apiUrl;
  String get apiKey;

  Future<bool> loadEnabled();
  Future<List<PlanAttendance>> loadAttendances(DateTime from, DateTime to);

  /// Names of the tenant's Termin types by id.
  Future<Map<String, String>> typeNames();
  Future<void> saveToken({
    required String userId,
    required String kind,
    required String token,
    int attendanceId = 0,
    String planKey = '',
  });

  /// SOL_FIX15: deletes this device's token rows ([tokens]) of [userId]
  /// (logout). Must run while [userId] is still signed in (RLS owner only).
  Future<void> removeTokens({required String userId, required List<String> tokens});

  /// Opens the plan viewer of a Termin in live mode.
  Future<void> openPlan(int attendanceId);
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
class LiveActivityService {
  LiveActivityService({
    required LiveActivityHost host,
    MethodChannel? channel,
    bool? platformSupported,
    bool? isAndroid,
    int Function()? now,
    bool listenToLifecycle = true,
  })  : _host = host,
        _channel = channel ?? const MethodChannel(channelName),
        _platformSupported = platformSupported ?? isSupportedPlatform,
        _isAndroid = isAndroid ?? isAndroidPlatform,
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
        _listenToLifecycle = listenToLifecycle;

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
  bool _syncing = false;
  int? _loadedTenantId;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  Uri? _pendingUri;

  /// Last state pushed per plan, to skip no-op updates.
  final Map<String, String> _lastKeys = {};

  /// SOL_FIX15: account the tokens were registered for, and the tokens this
  /// device saved for it (removed again on logout).
  String? _sessionUserId;
  final Set<String> _savedTokens = {};

  /// Account whose tokens are registered on this device (null = none).
  String? get sessionUserId => _sessionUserId;

  /// SOL_FIX16: session generation, bumped synchronously by [endSession]
  /// (logout / account switch). Every running init / sync captures it at
  /// its start and re-checks it before each native change and token
  /// registration, so a fetch that returns after logout never starts
  /// activities with the previous account's plans again.
  int _generation = 0;

  bool _isStale(int generation) => generation != _generation;

  /// True when this build has the native side (Ionic `hasNativePlugin`);
  /// controls the toggle in the notification settings.
  bool get hasNativePlugin => _platformSupported;

  /// Live Activities are allowed on this device (iOS 16.2+, user setting).
  bool get isSupported => _supported;
  bool get isEnabled => _enabled;
  bool get isLoopRunning => _timer != null;

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
    await init();
  }

  /// SOL_FIX15: logout / account switch. Ends every Live Activity (running
  /// Ablaufpläne must not stay on the lock screen), and resets the session
  /// state so tokens are registered again for the next account.
  ///
  /// With [removeTokensOf] (call BEFORE `auth.signOut()`, RLS needs the
  /// session) this device's token rows of that account are deleted as
  /// well, so the server stops pushing that account's plans to it.
  Future<void> endSession({String? removeTokensOf}) async {
    // SOL_FIX16: invalidate running init / sync calls and reset the session
    // state synchronously, before the first await, so neither a stale fetch
    // nor a late reset can touch the next session.
    _generation++;
    _syncing = false;
    stopLoop();
    _lifecycle?.dispose();
    _lifecycle = null;
    _lastKeys.clear();
    _pendingUri = null;
    final sessionUserId = _sessionUserId;
    final savedTokens = {..._savedTokens};
    _savedTokens.clear();
    _sessionUserId = null;
    _loadedTenantId = null;
    _started = false;
    _enabled = true;
    if (_platformSupported) {
      try {
        await _channel.invokeMethod<void>('endAll');
      } catch (e) {
        _log('endAll', e);
      }
    }
    final owner = removeTokensOf;
    if (owner != null && (sessionUserId == null || sessionUserId == owner)) {
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

  Future<void> init() async {
    if (!_platformSupported) return;
    final generation = _generation;
    bool supported;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('isAvailable');
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
    final enabled = await _loadEnabled();
    if (_isStale(generation)) return;
    _enabled = enabled;
    if (!_started) {
      _started = true;
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

  /// Called from the notification settings toggle.
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (!_supported) return;
    if (!enabled) {
      _lastKeys.clear();
      try {
        await _channel.invokeMethod<void>('endAll');
      } catch (_) {}
    } else {
      await sync();
    }
  }

  /// Syncs now and every [syncInterval]; completes after the first sync.
  Future<void> startLoop() {
    stopLoop();
    _timer = Timer.periodic(syncInterval, (_) => sync());
    return sync();
  }

  void stopLoop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Starts, updates and ends Live Activities to match the plans running right now.
  Future<void> sync() async {
    if (!_supported || _syncing) return;
    final generation = _generation;
    if (_host.tenantId == null) {
      // SOL_FIX15: no tenant (logged out / cleared) → nothing may stay
      // on the lock screen.
      if (_lastKeys.isNotEmpty) {
        _lastKeys.clear();
        try {
          await _channel.invokeMethod<void>('endAll');
        } catch (_) {}
      }
      return;
    }
    _syncing = true;
    try {
      final running = _enabled ? await runningPlans() : null;
      // SOL_FIX16: plans loaded for a session that has ended meanwhile.
      if (_isStale(generation)) return;
      final candidates = running?.candidates ?? const <LivePlanCandidate>[];
      final attendanceIds = running?.attendanceIds;
      final listed = await _channel.invokeMapMethod<String, dynamic>('list');
      if (_isStale(generation)) return;
      final activities = ((listed?['activities'] as List?) ?? const [])
          .map(LiveActivityTarget.fromMap)
          .whereType<LiveActivityTarget>()
          .toList();
      final wanted = candidates.map((c) => c.key).toSet();

      for (final c in candidates) {
        final k = c.key;
        final stateKey = liveStateKey(c.state);
        final isRunning = activities.any((a) => a.key == k);
        if (isRunning && _lastKeys[k] == stateKey) continue;
        // Ionic: iOS gets iosLiveState, Android the raw state.
        final shown = (_isAndroid ? c.state : iosLiveState(c.state)).toMap();
        // SOL_FIX16: re-checked before every native change.
        if (_isStale(generation)) return;
        if (c.state.phase == 'ended') {
          if (isRunning) {
            await _channel.invokeMethod<void>('end', {
              'attendanceId': c.attendanceId,
              'planKey': c.planKey,
              'state': shown,
            });
          }
        } else if (isRunning) {
          await _channel.invokeMethod<void>('update', {
            'attendanceId': c.attendanceId,
            'planKey': c.planKey,
            'state': shown,
          });
        } else {
          await _channel.invokeMethod<void>('start', {
            'attendanceId': c.attendanceId,
            'planKey': c.planKey,
            'title': c.title,
            'state': shown,
          });
        }
        _lastKeys[k] = stateKey;
      }
      // Plans that are over or no longer visible to this user. Activities of the
      // user's other tenants are left alone (the server keeps those up to date).
      for (final a in activities) {
        if (!wanted.contains(a.key) &&
            (attendanceIds == null || attendanceIds.contains(a.attendanceId))) {
          if (_isStale(generation)) return;
          await _channel.invokeMethod<void>('end', {
            'attendanceId': a.attendanceId,
            'planKey': a.planKey,
            'immediate': true,
          });
          _lastKeys.remove(a.key);
        }
      }
    } catch (e) {
      _log('sync', e);
    } finally {
      // A stale sync must not release the flag of the next session's sync.
      if (!_isStale(generation)) _syncing = false;
    }
  }

  /// Plans of the current tenant whose live window contains now.
  Future<({List<LivePlanCandidate> candidates, Set<int> attendanceIds})> runningPlans() async {
    final role = _host.role;
    final isLeader = role.isAdmin || role.isResponsible;
    final timezone = _host.timezone.isNotEmpty ? _host.timezone : 'Europe/Berlin';
    final now = _now();
    final today = DateTime.fromMillisecondsSinceEpoch(now);
    final from = DateTime(today.year, today.month, today.day - lookbackDays);
    final to = DateTime(today.year, today.month, today.day + 1, 23, 59, 59, 999);
    final attendances = await _host.loadAttendances(from, to);
    final typeNames = await _host.typeNames();

    final result = <LivePlanCandidate>[];
    for (final att in attendances) {
      final id = att.id;
      if (id == null) continue;
      // Beobachter never see the plan; others only when it is shared.
      if (role.isViewer || (!isLeader && !att.sharePlan)) continue;
      final plans = PlanUtils.allPlans(att);
      final typeName = typeNames[att.typeId] ?? '';
      for (var index = 0; index < plans.length; index++) {
        final state = liveStateAt(liveSchedule(att, index, timezone, plans), now);
        if (state == null) continue;
        result.add(LivePlanCandidate(
          attendanceId: id,
          planKey: livePlanKey(plans[index]),
          title: liveTitle(att, typeName, index, plans),
          state: state,
        ));
      }
    }
    return (
      candidates: result,
      attendanceIds: attendances.map((a) => a.id).whereType<int>().toSet(),
    );
  }

  Future<void> _registerTokens(int generation) async {
    if (_isAndroid) {
      // Tells the server this build can show live plan notifications (no
      // ActivityKit token on Android) – Ionic registerTokenListeners.
      await _saveToken('start', 'android', generation: generation);
    } else {
      // Lets the native side register update tokens itself while the app only runs in the background.
      try {
        if (_isStale(generation)) return;
        await _channel.invokeMethod<void>('configure', {'url': _host.apiUrl, 'key': _host.apiKey});
      } catch (_) {}
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
          await _saveToken('update', token, target: target, generation: generation);
        }
      }
    } catch (_) {}
  }

  /// [generation]: the session the registration started in (SOL_FIX16);
  /// native token events pass none and use the current session.
  Future<void> _saveToken(
    String kind,
    String token, {
    LiveActivityTarget? target,
    int? generation,
  }) async {
    if (generation != null && _isStale(generation)) return;
    final userId = _host.userId;
    if (userId == null || token.isEmpty) return;
    // SOL_FIX15: tokens belong to the account of this session only.
    if (_sessionUserId != null && _sessionUserId != userId) return;
    _sessionUserId = userId;
    try {
      await _host.saveToken(
        userId: userId,
        kind: kind,
        token: token,
        attendanceId: target?.attendanceId ?? 0,
        planKey: target?.planKey ?? '',
      );
      if (kind != 'start' || token != 'android') _savedTokens.add(token);
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
    if (attendanceId == 0) return true;
    if (_host.tenantId == null) {
      // Opened before the tenant was loaded (cold start): open after init.
      _pendingUri = url;
      return true;
    }
    try {
      await _host.openPlan(attendanceId);
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

/// [LiveActivityHost] backed by the app's providers.
class RiverpodLiveActivityHost implements LiveActivityHost {
  RiverpodLiveActivityHost(this._ref);

  final Ref _ref;

  @override
  int? get tenantId => _ref.read(currentTenantIdProvider);

  @override
  String get timezone => _ref.read(currentTenantProvider)?.timezone ?? 'Europe/Berlin';

  @override
  Role get role => _ref.read(currentRoleProvider);

  @override
  String? get userId => _ref.read(supabaseClientProvider).auth.currentUser?.id;

  @override
  String get apiUrl => SupabaseConfig.supabaseUrl;

  @override
  String get apiKey => SupabaseConfig.supabaseAnonKey;

  @override
  Future<bool> loadEnabled() async {
    final id = userId;
    if (id == null) return true;
    return _ref.read(liveActivityRepositoryWithTenantProvider).isLiveActivityEnabled(id);
  }

  @override
  Future<List<PlanAttendance>> loadAttendances(DateTime from, DateTime to) async {
    final repo = _ref.read(liveActivityRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return [];
    return repo.getPlanAttendancesBetween(from, to);
  }

  @override
  Future<Map<String, String>> typeNames() async {
    try {
      final types = await _ref.read(planAttendanceTypesProvider.future);
      return {for (final t in types) t.id: t.name};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveToken({
    required String userId,
    required String kind,
    required String token,
    int attendanceId = 0,
    String planKey = '',
  }) {
    return _ref.read(liveActivityRepositoryWithTenantProvider).saveToken(
          userId: userId,
          kind: kind,
          token: token,
          // Ionic Capacitor.getPlatform() (DB_REVIEW_REST F2)
          platform: LiveActivityService.isAndroidPlatform ? 'android' : 'ios',
          attendanceId: attendanceId,
          planKey: planKey,
        );
  }

  @override
  Future<void> removeTokens({required String userId, required List<String> tokens}) {
    return _ref
        .read(liveActivityRepositoryWithTenantProvider)
        .removeTokens(userId: userId, tokens: tokens);
  }

  @override
  Future<void> openPlan(int attendanceId) async {
    final repo = _ref.read(planRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return;
    final attendance = await repo.getPlanAttendanceById(attendanceId);
    if (attendance?.plan == null) return;
    final context = _ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await showPlanViewer(context, attendance: attendance!, defaultLive: true);
  }
}

/// The app's LiveActivityService.
final liveActivityServiceProvider = Provider<LiveActivityService>((ref) {
  final service = LiveActivityService(host: RiverpodLiveActivityHost(ref));
  ref.onDispose(service.dispose);
  return service;
});

/// Read once at app start (main.dart): attaches the native channel and
/// (re)initialises the service whenever the tenant changes.
final liveActivityBootstrapProvider = Provider<void>((ref) {
  final service = ref.watch(liveActivityServiceProvider);
  if (!service.hasNativePlugin) return;
  unawaited(service.attach());
  ref.listen(currentTenantUserProvider, (_, next) {
    unawaited(service.onTenantReady(
      ref.read(currentTenantIdProvider),
      hasTenantUser: next.valueOrNull != null,
      userId: ref.read(currentAuthUserIdProvider),
    ));
  }, fireImmediately: true);
  // SOL_FIX15: logout / account switch – end the activities and reset, so
  // the next account registers its own tokens (the previous account's
  // rows are removed before sign-out, see endLiveActivitiesBeforeSignOut).
  ref.listen<String?>(currentAuthUserIdProvider, (previous, next) {
    if (previous != null && previous != next) {
      unawaited(service.endSession());
    }
  });
  // Tenant cleared without a tenant-user change.
  ref.listen<int?>(currentTenantIdProvider, (previous, next) {
    if (next == null && previous != null) {
      unawaited(service.onTenantReady(null, hasTenantUser: false));
    }
  });
});

/// SOL_FIX15: ends the Live Activities and deletes this device's Live
/// Activity tokens of the signed-in account. Call before `auth.signOut()`
/// (RLS needs the session); never blocks the logout.
Future<void> endLiveActivitiesBeforeSignOut(LiveActivityService service, String? userId) async {
  try {
    await service.endSession(removeTokensOf: userId);
  } catch (_) {}
}
