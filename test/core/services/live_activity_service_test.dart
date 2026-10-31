import 'dart:async';
import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/services/live_activity_service.dart';
import 'package:attendix/core/utils/live_plan.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/data/repositories/org_plan_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// LIVE_ACTIVITY: LiveActivityService against a mocked MethodChannel.
class FakeHost implements LiveActivityHost {
  FakeHost({this.attendances = const [], this.role = Role.admin});

  List<PlanAttendance> attendances;
  @override
  Role role;
  @override
  int? tenantId = 7;
  bool enabled = true;
  final saved = <Map<String, Object?>>[];
  final opened = <int>[];

  @override
  String get timezone => 'Europe/Berlin';
  @override
  String? userId = 'user-1';
  final removed = <Map<String, Object?>>[];
  @override
  String get apiUrl => 'https://example.supabase.co';
  @override
  String get apiKey => 'anon';
  /// SOL_FIX16: when set, the next call waits for it (one-shot).
  Completer<void>? enabledGate;
  Completer<void>? attendancesGate;

  /// SOL_FIX17: when set, the next saveToken waits for it (one-shot), and
  /// [log] records the order of finished upserts and deletes.
  Completer<void>? saveGate;
  final log = <String>[];

  @override
  Future<bool> loadEnabled() async {
    final gate = enabledGate;
    enabledGate = null;
    if (gate != null) await gate.future;
    return enabled;
  }

  @override
  Future<List<PlanAttendance>> loadAttendances(DateTime from, DateTime to) async {
    final gate = attendancesGate;
    attendancesGate = null;
    if (gate != null) await gate.future;
    return attendances;
  }
  @override
  Future<Map<String, LiveTermType>> termTypes() async => {
        't1': (name: 'Probe', color: typeColor),
      };
  String? typeColor;

  /// Ionic 4.17.8: ORG plans of the organisation (null = no organisation).
  LiveOrgPlans? orgPlans;
  Object? orgPlansError;
  final orgRanges = <List<DateTime>>[];
  final openedOrgPlans = <String>[];

  @override
  Future<LiveOrgPlans?> loadOrgPlans(DateTime from, DateTime to) async {
    orgRanges.add([from, to]);
    final error = orgPlansError;
    if (error != null) throw error;
    return orgPlans;
  }

  @override
  Future<void> openSharedOrgPlan(String id) async => openedOrgPlans.add(id);
  @override
  Future<void> saveToken({
    required String userId,
    required String kind,
    required String token,
    int attendanceId = 0,
    String planKey = '',
  }) async {
    final gate = saveGate;
    saveGate = null;
    if (gate != null) await gate.future;
    saved.add({'userId': userId, 'kind': kind, 'token': token, 'attendanceId': attendanceId, 'planKey': planKey});
    log.add('upsert:$token');
  }

  @override
  Future<void> removeTokens({required String userId, required List<String> tokens}) async {
    removed.add({'userId': userId, 'tokens': [...tokens]..sort()});
    log.add('delete');
  }

  @override
  Future<void> openPlan(int attendanceId) async => opened.add(attendanceId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(LiveActivityService.channelName);
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late List<Map<String, Object?>> running;
  late bool available;
  late String? pendingUrl;

  /// SOL_FIX18: when set, the native close (`setRegistrationOpen` false)
  /// answers only after it completes (uploads still running on iOS).
  Completer<void>? closeGate;

  // 2026-10-21 19:00 Europe/Berlin = 17:00 UTC
  final planStart = DateTime.utc(2026, 10, 21, 17).millisecondsSinceEpoch;
  const min = 60000;

  PlanAttendance attendance({bool shared = true, int id = 11}) => PlanAttendance(
        id: id,
        date: '2026-10-21T10:00:00+00:00',
        typeId: 't1',
        sharePlan: shared,
        plan: const Plan(time: '19:00', fields: [
          PlanField(id: 'a', name: 'Einspielen', time: '15'),
          PlanField(id: 'b', name: 'Probe', time: '45'),
        ]),
      );

  setUpAll(() async {
    await LiveTimezone.ensureInitialized();
  });

  setUp(() {
    calls = [];
    running = [];
    available = true;
    pendingUrl = null;
    closeGate = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'setRegistrationOpen':
          final gate = closeGate;
          if ((call.arguments as Map)['open'] == false && gate != null) {
            await gate.future;
          }
          return null;
        case 'isAvailable':
          return {'available': available, 'pushToStart': true};
        case 'list':
          return {'activities': running};
        case 'getTokens':
          return {
            'pushToStartToken': 'abc123',
            'activityTokens': [
              {'attendanceId': 11, 'planKey': 'main', 'token': 'def456'},
            ],
          };
        case 'takePendingUrl':
          return pendingUrl;
        default:
          return null;
      }
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  LiveActivityService service(
    FakeHost host, {
    int? now,
    bool platform = true,
    bool android = false,
    Duration nativeCloseTimeout = const Duration(seconds: 10),
  }) =>
      LiveActivityService(
        host: host,
        channel: channel,
        platformSupported: platform,
        isAndroid: android,
        now: () => now ?? planStart + 20 * min,
        listenToLifecycle: false,
        nativeCloseTimeout: nativeCloseTimeout,
      );

  List<String> methods() => calls.map((c) => c.method).toList();

  test('no-op without the native platform (web)', () async {
    final s = service(FakeHost(attendances: [attendance()]), platform: false);
    await s.attach();
    await s.init();
    await s.sync();
    expect(s.hasNativePlugin, isFalse);
    expect(calls, isEmpty);
  });

  test('missing native plugin is swallowed', () async {
    messenger.setMockMethodCallHandler(channel, null);
    final s = service(FakeHost(attendances: [attendance()]));
    await s.init();
    expect(s.isSupported, isFalse);
    s.dispose();
  });

  test('init configures, registers tokens like Ionic and starts the running plan', () async {
    final host = FakeHost(attendances: [attendance()]);
    final s = service(host);
    await s.init();
    await s.sync();
    s.dispose();

    expect(methods().take(4), ['isAvailable', 'setRegistrationOpen', 'configure', 'getTokens']);
    expect(calls[1].arguments, {'open': true});
    final configure = calls.firstWhere((c) => c.method == 'configure');
    expect(configure.arguments, {'url': 'https://example.supabase.co', 'key': 'anon'});
    expect(host.saved, [
      {'userId': 'user-1', 'kind': 'start', 'token': 'abc123', 'attendanceId': 0, 'planKey': ''},
      {'userId': 'user-1', 'kind': 'update', 'token': 'def456', 'attendanceId': 11, 'planKey': 'main'},
    ]);

    final start = calls.firstWhere((c) => c.method == 'start');
    final args = start.arguments as Map;
    expect(args['attendanceId'], 11);
    expect(args['planKey'], 'main');
    expect(args['title'], 'Probe');
    expect((args['state'] as Map)['phase'], 'running');
    expect((args['state'] as Map)['title'], 'Probe');
  });

  test('updates a running activity only when its state changed', () async {
    running = [
      {'id': 'x', 'attendanceId': 11, 'planKey': 'main'},
    ];
    final s = service(FakeHost(attendances: [attendance()]));
    await s.init();
    s.stopLoop();
    calls.clear();
    await s.sync();
    expect(methods().where((m) => m == 'update' || m == 'start'), isEmpty);
  });

  test('before the start the widget gets "Beginnt in"', () async {
    final s = service(FakeHost(attendances: [attendance()]), now: planStart - 5 * min);
    await s.init();
    s.stopLoop();
    final start = calls.firstWhere((c) => c.method == 'start');
    final state = (start.arguments as Map)['state'] as Map;
    expect(state['phase'], 'before');
    expect(state['title'], 'Beginnt in');
  });

  test('players only get shared plans; viewers never', () async {
    final player = FakeHost(attendances: [attendance(shared: false)], role: Role.player);
    final s1 = service(player);
    expect((await s1.runningPlans()).candidates, isEmpty);

    final shared = FakeHost(attendances: [attendance()], role: Role.player);
    expect((await service(shared).runningPlans()).candidates.length, 1);

    final viewer = FakeHost(attendances: [attendance()], role: Role.viewer);
    expect((await service(viewer).runningPlans()).candidates, isEmpty);
  });

  test('ends activities of plans that are no longer running in this tenant', () async {
    running = [
      {'id': 'x', 'attendanceId': 11, 'planKey': 'main'},
      {'id': 'y', 'attendanceId': 999, 'planKey': 'main'}, // other tenant: left alone
    ];
    final s = service(FakeHost(attendances: [attendance()]), now: planStart + 3 * 60 * min);
    await s.init();
    s.stopLoop();
    final ends = calls.where((c) => c.method == 'end').toList();
    expect(ends.length, 1);
    expect(ends.single.arguments, {'attendanceId': 11, 'planKey': 'main', 'immediate': true});
  });

  test('setEnabled(false) ends all activities', () async {
    final s = service(FakeHost(attendances: [attendance()]));
    await s.init();
    s.stopLoop();
    await s.setEnabled(false);
    expect(methods(), contains('endAll'));
    expect(s.isEnabled, isFalse);
  });

  test('disabled in notifications: nothing is started', () async {
    final host = FakeHost(attendances: [attendance()])..enabled = false;
    final s = service(host);
    await s.init();
    s.stopLoop();
    expect(methods(), isNot(contains('start')));
  });

  Future<void> sendNative(String method, Object args) async {
    await messenger.handlePlatformMessage(
      LiveActivityService.channelName,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
  }

  test('native token events are stored', () async {
    final host = FakeHost();
    final s = service(host);
    await s.attach();
    // SOL_FIX17: registration opens with the session's init.
    await s.init();
    s.stopLoop();
    host.saved.clear();
    Future<void> send(String method, Object args) async {
      await messenger.handlePlatformMessage(
        LiveActivityService.channelName,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );
    }

    await send('pushToStartToken', {'token': 'aa11'});
    await send('activityToken', {'attendanceId': 5, 'planKey': 'p2', 'token': 'bb22'});
    expect(host.saved, [
      {'userId': 'user-1', 'kind': 'start', 'token': 'aa11', 'attendanceId': 0, 'planKey': ''},
      {'userId': 'user-1', 'kind': 'update', 'token': 'bb22', 'attendanceId': 5, 'planKey': 'p2'},
    ]);
    s.dispose();
  });

  test('deep link attendix://live-plan opens the plan viewer', () async {
    final host = FakeHost();
    final s = service(host);
    expect(await s.openFromUrl(Uri.parse('https://attendix.de/x')), isFalse);
    expect(await s.openFromUrl(Uri.parse('attendix://live-plan?attendance=42&plan=main')), isTrue);
    expect(host.opened, [42]);
  });

  test('cold start link is taken from the native side and opened after init', () async {
    pendingUrl = 'attendix://live-plan?attendance=8&plan=main';
    final host = FakeHost()..tenantId = null;
    final s = service(host);
    await s.attach();
    expect(host.opened, isEmpty);
    host.tenantId = 7;
    await s.onTenantReady(7, hasTenantUser: true);
    s.dispose();
    expect(host.opened, [8]);
  });
  group('ORG plans (Ionic 4.17.8)', () {
    const fields = [
      PlanField(id: 'a', name: 'Einsingen', time: '15'),
      PlanField(id: 'b', name: 'Auftritt', time: '45'),
    ];
    OrgLiveAttendance orgAttendance(int id, {String? color}) => (
          attendance: PlanAttendance(
            id: id,
            date: '2026-10-21T10:00:00+00:00',
            plan: const Plan(time: '19:00', fields: fields),
          ),
          typeName: 'Konzert',
          typeColor: color,
        );
    SharedPlan sharedPlan({String id = 'sp1', String? title = ' Chortag ', String? time = '19:00'}) =>
        SharedPlan(id: id, editKey: 'k', planTitle: title, date: '2026-10-21', time: time, fields: fields);

    test('admins get org Termine and ad-hoc ORG plans (attendance 0, plan "org-<id>")', () async {
      final host = FakeHost(attendances: [attendance()])
        ..orgPlans = (
          attendances: [orgAttendance(11), orgAttendance(55, color: 'mint')],
          sharedPlans: [
            sharedPlan(),
            sharedPlan(id: 'sp2', title: null),
            sharedPlan(id: 'sp3', time: null),
          ],
        );
      final r = await service(host).runningPlans();
      // 11 is already a plan of this tenant: not added twice.
      expect(r.candidates.map((c) => c.key), ['11:main', '55:main', '0:org-sp1', '0:org-sp2']);
      expect(r.candidates[1].title, 'Konzert');
      expect(r.candidates[1].state.color, '#36c2c4');
      expect(r.candidates[2].title, 'Chortag');
      expect(r.candidates[2].state.color, isNull); // ad-hoc plans stay teal
      expect(r.candidates[3].title, 'ORG-Plan');
      expect(r.attendanceIds, containsAll([11, 55, 0]));
      // Yesterday to the end of tomorrow.
      final range = host.orgRanges.single;
      expect(range[0], DateTime(2026, 10, 20));
      expect(range[1], DateTime(2026, 10, 22, 23, 59, 59, 999));
    });

    test('players never load ORG plans', () async {
      final host = FakeHost(attendances: [attendance()], role: Role.player)
        ..orgPlans = (attendances: [orgAttendance(55)], sharedPlans: [sharedPlan()]);
      final r = await service(host).runningPlans();
      expect(r.candidates.map((c) => c.key), ['11:main']);
      expect(r.attendanceIds, {11});
      expect(host.orgRanges, isEmpty);
    });

    test('a failing ORG query leaves their activities alone', () async {
      running = [
        {'id': 'y', 'attendanceId': 0, 'planKey': 'org-sp1'},
      ];
      final host = FakeHost(attendances: [attendance()])..orgPlansError = Exception('offline');
      final s = service(host);
      await s.init();
      s.stopLoop();
      expect(methods(), isNot(contains('end')));
    });

    test('ad-hoc ORG plans that are over are ended', () async {
      running = [
        {'id': 'y', 'attendanceId': 0, 'planKey': 'org-old'},
      ];
      final host = FakeHost(attendances: [attendance()])
        ..orgPlans = (attendances: <OrgLiveAttendance>[], sharedPlans: <SharedPlan>[]);
      final s = service(host);
      await s.init();
      s.stopLoop();
      final ends = calls.where((c) => c.method == 'end').toList();
      expect(ends.single.arguments, {'attendanceId': 0, 'planKey': 'org-old', 'immediate': true});
    });

    test('tap on an ad-hoc ORG plan opens it', () async {
      final host = FakeHost();
      final s = service(host);
      expect(await s.openFromUrl(Uri.parse('attendix://live-plan?attendance=0&plan=org-abc')), isTrue);
      expect(host.openedOrgPlans, ['abc']);
      expect(host.opened, isEmpty);
      expect(await s.openFromUrl(Uri.parse('attendix://live-plan?attendance=0&plan=main')), isTrue);
      expect(host.openedOrgPlans, ['abc']);
    });
  });

  test('the activity gets the colour of the Termin type (Ionic 4.17.22)', () async {
    final host = FakeHost(attendances: [attendance()])..typeColor = 'danger';
    final s = service(host);
    await s.init();
    s.stopLoop();
    final start = calls.firstWhere((c) => c.method == 'start');
    expect(((start.arguments as Map)['state'] as Map)['color'], '#ff4961');
  });

  // SOL_FIX15: logout / account switch.
  group('logout and account switch', () {
    test('logout ends the activities and removes this device\'s tokens', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host);
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      expect(s.isLoopRunning, isTrue);
      expect(s.sessionUserId, 'user-1');
      calls.clear();

      await endLiveActivitiesBeforeSignOut(s, 'user-1');
      expect(methods(), contains('endAll'));
      expect(s.isLoopRunning, isFalse);
      expect(host.removed, [
        {'userId': 'user-1', 'tokens': ['abc123', 'def456']},
      ]);
      expect(s.sessionUserId, isNull);
      s.dispose();
    });

    test('a missing tenant (logout) is not ignored', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host);
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      calls.clear();
      host.tenantId = null;
      await s.onTenantReady(null, hasTenantUser: false);
      expect(methods(), contains('endAll'));
      expect(s.isLoopRunning, isFalse);

      // Same tenant again (e.g. next login) initialises again.
      host.tenantId = 7;
      calls.clear();
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      expect(methods(), contains('isAvailable'));
      expect(methods(), contains('start'));
      s.dispose();
    });

    test('sync without a tenant ends the shown activities', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host);
      await s.init();
      s.stopLoop();
      calls.clear();
      host.tenantId = null;
      await s.sync();
      expect(methods(), ['endAll']);
      calls.clear();
      await s.sync(); // nothing shown any more
      expect(methods(), isEmpty);
    });

    test('account switch in the same tenant re-registers for the new account', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host);
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      expect(host.saved.map((e) => e['userId']).toSet(), {'user-1'});
      calls.clear();
      host.saved.clear();

      host.userId = 'user-2';
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-2');
      expect(methods().take(2), ['setRegistrationOpen', 'endAll']);
      expect(host.saved, isNotEmpty);
      expect(host.saved.map((e) => e['userId']).toSet(), {'user-2'});
      expect(s.sessionUserId, 'user-2');
      // B never deletes A's rows (RLS) – A's are removed before sign-out.
      expect(host.removed, isEmpty);
      s.dispose();
    });

    test('tokens of another account are never removed', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host);
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      await s.endSession(removeTokensOf: 'user-2');
      expect(host.removed, isEmpty);
      s.dispose();
    });

    // SOL_FIX16: a fetch that returns after logout must not touch the
    // lock screen or register tokens for the ended session.
    test('a sync returning after logout starts nothing again', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host);
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      s.stopLoop();
      expect(methods(), contains('start'));

      final gate = Completer<void>();
      host.attendancesGate = gate;
      final pending = s.sync(); // waits for A's plans
      await pumpEventQueue();
      await endLiveActivitiesBeforeSignOut(s, 'user-1');
      calls.clear();

      gate.complete();
      await pending;
      expect(methods(), isEmpty);
      expect(s.isLoopRunning, isFalse);
    });

    test('the next session syncs while a stale sync is still running', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host);
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      s.stopLoop();

      final gate = Completer<void>();
      host.attendancesGate = gate;
      final stale = s.sync();
      await pumpEventQueue();

      host.userId = 'user-2';
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-2');
      s.stopLoop();
      expect(methods().where((m) => m == 'start').length, 2);
      calls.clear();

      gate.complete();
      await stale;
      expect(methods(), isEmpty);
      s.dispose();
    });

    test('an init returning after logout registers no tokens', () async {
      final host = FakeHost(attendances: [attendance()]);
      final gate = Completer<void>();
      host.enabledGate = gate;
      final s = service(host);
      final pending = s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      await pumpEventQueue();
      await s.endSession();
      calls.clear();

      gate.complete();
      await pending;
      expect(host.saved, isEmpty);
      expect(methods(), isEmpty);
      expect(s.isLoopRunning, isFalse);
      expect(s.sessionUserId, isNull);
    });

    test('logout is wired before sign-out', () {
      final push = File('lib/core/providers/push_providers.dart').readAsStringSync();
      final fn = push.substring(push.indexOf('Future<void> removePushTokenBeforeSignOut('));
      expect(fn.substring(0, fn.indexOf('\n}\n')), contains('endLiveActivitiesBeforeSignOut('));
      final repo = File('lib/data/repositories/live_activity_repository.dart').readAsStringSync();
      final rm = repo.substring(repo.indexOf('Future<void> removeTokens('));
      expect(rm, contains(".from('live_activity_tokens')"));
      expect(rm, contains(".eq('user_id', userId)"));
      expect(rm, contains(".inFilter('token', tokens)"));
    });
  });

  // DB_REVIEW_REST (F2): Android live plan notification (Ionic LiveActivityPlugin.java)
  // SOL_FIX17: Sol review of 2c0550c – token writes racing the logout and
  // syncs racing the disable toggle.
  group('SOL_FIX17', () {
    test('an upsert in flight finishes before the logout deletes the tokens', () async {
      final host = FakeHost();
      final s = service(host);
      final gate = Completer<void>();
      host.saveGate = gate; // first token upsert of init hangs
      final initializing = s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      await pumpEventQueue();
      expect(host.saved, isEmpty);

      final ending = endLiveActivitiesBeforeSignOut(s, 'user-1');
      await pumpEventQueue();
      expect(host.removed, isEmpty, reason: 'delete waits for the running upsert');

      gate.complete();
      await ending;
      await initializing;
      // The in-flight upsert landed first, then the delete; the stale init
      // registered nothing else afterwards.
      expect(host.log, ['upsert:abc123', 'delete']);
      expect(host.removed.single['tokens'], containsAll(['abc123', 'def456']));
      expect(s.sessionUserId, isNull);
    });

    test('native token callbacks after the session ended are dropped', () async {
      final host = FakeHost();
      final s = service(host);
      await s.attach();
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      s.stopLoop();
      await endLiveActivitiesBeforeSignOut(s, 'user-1');
      host.saved.clear();
      host.log.clear();

      await sendNative('pushToStartToken', {'token': 'late1'});
      await sendNative('activityToken', {'attendanceId': 5, 'planKey': 'p2', 'token': 'late2'});
      expect(host.saved, isEmpty);
      expect(s.sessionUserId, isNull);

      // The next session opens registration again.
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      s.stopLoop();
      await sendNative('pushToStartToken', {'token': 'next1'});
      expect(host.saved.map((r) => r['token']), contains('next1'));
      s.dispose();
    });

    test('native callbacks before any session init are dropped', () async {
      final host = FakeHost();
      final s = service(host);
      await s.attach();
      await sendNative('pushToStartToken', {'token': 'early'});
      expect(host.saved, isEmpty);
      s.dispose();
    });

    test('setEnabled(false) while a sync loads plans: nothing is started', () async {
      final host = FakeHost();
      final s = service(host);
      await s.init(); // no running plan yet
      s.stopLoop();
      calls.clear();

      host.attendances = [attendance()];
      final gate = Completer<void>();
      host.attendancesGate = gate;
      final pending = s.sync(); // delayed plan query
      await pumpEventQueue();
      await s.setEnabled(false);
      expect(methods(), ['endAll']);

      gate.complete();
      await pending;
      expect(methods(), ['endAll'], reason: 'the old sync must not restart activities');

      // Enabling again syncs normally (the stale sync released its flag).
      await s.setEnabled(true);
      expect(methods(), contains('start'));
    });

    test('disabled: a sync never starts an activity', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host);
      await s.init();
      s.stopLoop();
      await s.setEnabled(false);
      calls.clear();
      await s.sync();
      expect(methods(), isNot(contains('start')));
    });
  });

  // SOL_FIX18: Sol review of 1c9b642.
  group('SOL_FIX18', () {
    test('logout closes the native uploads and waits for them before deleting', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host);
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      s.stopLoop();
      calls.clear();

      final gate = Completer<void>();
      closeGate = gate; // an iOS upload is still running
      final ending = endLiveActivitiesBeforeSignOut(s, 'user-1');
      await pumpEventQueue();
      expect(methods(), ['setRegistrationOpen']);
      expect(calls.single.arguments, {'open': false});
      expect(host.removed, isEmpty, reason: 'rows are deleted after the native uploads');

      gate.complete();
      await ending;
      expect(methods(), ['setRegistrationOpen', 'endAll', 'getTokens']);
      expect(host.removed.single['tokens'], ['abc123', 'def456']);
      s.dispose();
    });

    test('the next session re-opens the native uploads', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host);
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      s.stopLoop();
      await endLiveActivitiesBeforeSignOut(s, 'user-1');
      calls.clear();

      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      s.stopLoop();
      final opens = calls.where((c) => c.method == 'setRegistrationOpen').toList();
      expect(opens.single.arguments, {'open': true});
      expect(methods().indexOf('setRegistrationOpen'), lessThan(methods().indexOf('configure')));
      s.dispose();
    });

    test('a native close that never answers does not block the logout', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host, nativeCloseTimeout: const Duration(milliseconds: 20));
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      s.stopLoop();
      closeGate = Completer<void>(); // never completes
      await endLiveActivitiesBeforeSignOut(s, 'user-1');
      expect(host.removed, hasLength(1));
      s.dispose();
    });

    test('a build without the native call still logs out', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host);
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      s.stopLoop();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'setRegistrationOpen') {
          throw MissingPluginException();
        }
        if (call.method == 'getTokens') return {'pushToStartToken': 'abc123'};
        return null;
      });
      await endLiveActivitiesBeforeSignOut(s, 'user-1');
      expect(host.removed, hasLength(1));
      s.dispose();
    });

    test('setEnabled(false) while init loads the setting: the late true is ignored', () async {
      final host = FakeHost(attendances: [attendance()]); // DB still says enabled
      final gate = Completer<void>();
      host.enabledGate = gate;
      final s = service(host);
      final initializing = s.init();
      await pumpEventQueue();

      await s.setEnabled(false); // user switches it off meanwhile
      gate.complete();
      await initializing;
      s.stopLoop();
      expect(s.isEnabled, isFalse);
      expect(methods(), isNot(contains('start')));

      await s.sync();
      expect(methods(), isNot(contains('start')));
    });

    test('setEnabled(true) while init loads a stale false: activities start', () async {
      final host = FakeHost(attendances: [attendance()])..enabled = false;
      final gate = Completer<void>();
      host.enabledGate = gate;
      final s = service(host);
      final initializing = s.init();
      await pumpEventQueue();

      await s.setEnabled(true);
      gate.complete();
      await initializing;
      s.stopLoop();
      expect(s.isEnabled, isTrue);
      expect(methods(), contains('start'));
    });
  });

  // SOL_FIX19: Sol review of afa5b15 – the next session must not start
  // while the previous teardown still waits for the native uploads; its
  // global endAll would end the new activities.
  group('SOL_FIX19', () {
    test('init waits for the running logout teardown (delayed native close)', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host);
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      s.stopLoop();
      calls.clear();
      host.saved.clear();
      host.log.clear();

      final gate = Completer<void>();
      closeGate = gate; // native uploads still running
      final ending = endLiveActivitiesBeforeSignOut(s, 'user-1');
      await pumpEventQueue();

      // Next login lands in a tenant while the teardown still waits.
      host.userId = 'user-2';
      host.tenantId = 8;
      final next = s.onTenantReady(8, hasTenantUser: true, userId: 'user-2');
      await pumpEventQueue();
      expect(methods(), ['setRegistrationOpen'], reason: 'init held back');
      expect(host.saved, isEmpty);

      gate.complete();
      await ending;
      await next;
      s.stopLoop();
      final m = methods();
      final endAll = m.indexOf('endAll');
      expect(endAll, greaterThan(0));
      expect(m.lastIndexOf('endAll'), endAll, reason: 'only the old endAll');
      expect(m.indexOf('isAvailable'), greaterThan(endAll));
      expect(m.indexOf('start'), greaterThan(endAll));
      expect(host.log.first, 'delete');
      expect(host.log.indexOf('delete'), lessThan(host.log.indexOf('upsert:abc123')),
          reason: 'old rows deleted before the new session registers');
      expect(host.removed.single['userId'], 'user-1');
      expect(host.saved.map((e) => e['userId']).toSet(), {'user-2'});
      expect(s.sessionUserId, 'user-2');
      expect(s.isLoopRunning, isFalse);
      s.dispose();
    });

    test('a sync during the teardown changes nothing native', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host);
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      s.stopLoop();
      final gate = Completer<void>();
      closeGate = gate;
      final ending = s.endSession(removeTokensOf: 'user-1');
      await pumpEventQueue();
      calls.clear();

      await s.sync();
      expect(methods(), isEmpty);
      gate.complete();
      await ending;
      s.dispose();
    });

    test('a logout during the waiting init keeps the next session closed', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host);
      await s.onTenantReady(7, hasTenantUser: true, userId: 'user-1');
      s.stopLoop();
      final gate = Completer<void>();
      closeGate = gate;
      final ending = s.endSession(removeTokensOf: 'user-1');
      await pumpEventQueue();
      final waiting = s.init();
      await pumpEventQueue();
      closeGate = null;
      final second = s.endSession();
      gate.complete();
      await Future.wait([ending, second, waiting]);
      calls.clear();
      await pumpEventQueue();
      expect(methods(), isEmpty);
      expect(s.isLoopRunning, isFalse);
      expect(s.sessionUserId, isNull);
      s.dispose();
    });
  });

  group('Android', () {
    test('registers the "android" start token instead of configure', () async {
      final host = FakeHost(attendances: [attendance()]);
      final s = service(host, android: true);
      await s.init();
      s.stopLoop();
      expect(methods(), isNot(contains('configure')));
      // SOL_FIX18: no native uploads on Android.
      expect(methods(), isNot(contains('setRegistrationOpen')));
      expect(host.saved.first,
          {'userId': 'user-1', 'kind': 'start', 'token': 'android', 'attendanceId': 0, 'planKey': ''});
      expect(methods(), contains('start'));
    });

    test('gets the raw state (no iOS "Beginnt in" rewrite)', () async {
      final s = service(FakeHost(attendances: [attendance()]), now: planStart - 5 * min, android: true);
      await s.init();
      s.stopLoop();
      final start = calls.firstWhere((c) => c.method == 'start');
      final state = (start.arguments as Map)['state'] as Map;
      expect(state['phase'], 'before');
      expect(state['title'], 'Einspielen');
    });
  });
}
