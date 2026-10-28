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
  Future<void> onTenantReady(int? tenantId, {required bool hasTenantUser}) async {
    if (tenantId == null || !hasTenantUser || tenantId == _loadedTenantId) return;
    _loadedTenantId = tenantId;
    await init();
  }

  Future<void> init() async {
    if (!_platformSupported) return;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('isAvailable');
      _supported = result?['available'] == true;
    } catch (_) {
      _supported = false;
    }
    if (!_supported) {
      await _flushPendingUri();
      return;
    }

    await LiveTimezone.ensureInitialized();
    _enabled = await _loadEnabled();
    if (!_started) {
      _started = true;
      await _registerTokens();
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
    if (!_supported || _host.tenantId == null || _syncing) return;
    _syncing = true;
    try {
      final running = _enabled ? await runningPlans() : null;
      final candidates = running?.candidates ?? const <LivePlanCandidate>[];
      final attendanceIds = running?.attendanceIds;
      final listed = await _channel.invokeMapMethod<String, dynamic>('list');
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
      _syncing = false;
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

  Future<void> _registerTokens() async {
    if (_isAndroid) {
      // Tells the server this build can show live plan notifications (no
      // ActivityKit token on Android) – Ionic registerTokenListeners.
      await _saveToken('start', 'android');
    } else {
      // Lets the native side register update tokens itself while the app only runs in the background.
      try {
        await _channel.invokeMethod<void>('configure', {'url': _host.apiUrl, 'key': _host.apiKey});
      } catch (_) {}
    }
    try {
      final tokens = await _channel.invokeMapMethod<String, dynamic>('getTokens');
      final start = tokens?['pushToStartToken'];
      if (start is String && start.isNotEmpty) await _saveToken('start', start);
      for (final raw in (tokens?['activityTokens'] as List?) ?? const []) {
        final target = LiveActivityTarget.fromMap(raw);
        final token = raw is Map ? raw['token'] : null;
        if (token is String) await _saveToken('update', token, target);
      }
    } catch (_) {}
  }

  Future<void> _saveToken(String kind, String token, [LiveActivityTarget? target]) async {
    final userId = _host.userId;
    if (userId == null || token.isEmpty) return;
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
        if (token is String && target != null) await _saveToken('update', token, target);
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
    ));
  }, fireImmediately: true);
});
