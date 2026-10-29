import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// LIVE_ACTIVITY: source checks for the Live Activity repository, service
/// and the native iOS side.
void main() {
  late String repo;
  late String service;
  late String page;

  setUpAll(() {
    repo = File('lib/data/repositories/live_activity_repository.dart').readAsStringSync();
    service = File('lib/core/services/live_activity_service.dart').readAsStringSync();
    page = File('lib/features/notifications/presentation/pages/notifications_page.dart').readAsStringSync();
  });

  Iterable<String> queries(String source, String table) => RegExp(
        "\\.from\\('$table'\\)[^;]+;",
        multiLine: true,
      ).allMatches(source).map((m) => m.group(0)!);

  group('Multi-Tenant Security - LiveActivityRepository', () {
    test('extends BaseRepository with TenantAwareRepository', () {
      expect(repo, contains('extends BaseRepository with TenantAwareRepository'));
    });

    test('attendance queries filter by tenantId', () {
      final q = queries(repo, 'attendance').toList();
      expect(q, isNotEmpty);
      for (final query in q) {
        expect(query, contains(".eq('tenantId', currentTenantId)"), reason: query);
        expect(query, contains(".not('plan', 'is', null)"));
      }
    });

    test('notifications are read by the user id only', () {
      final q = queries(repo, 'notifications').single;
      expect(q, contains(".eq('id', userId)"));
    });

    test('tokens are upserted like Ionic (user_id, kind, attendance_id, plan_key)', () {
      final q = queries(repo, 'live_activity_tokens')
          .singleWhere((q) => q.contains('.upsert('));
      expect(q, contains("'user_id': userId"));
      expect(q, contains("onConflict: 'user_id,kind,attendance_id,plan_key'"));
    });

    test('every method uses handleError', () {
      expect('handleError('.allMatches(repo).length, 4);
    });

    test('logout deletes only this device\'s tokens of the user (SOL_FIX15)', () {
      final q = queries(repo, 'live_activity_tokens')
          .singleWhere((q) => q.contains('.delete()'));
      expect(q, contains(".eq('user_id', userId)"));
      expect(q, contains(".inFilter('token', tokens)"));
    });
  });

  group('LiveActivityService', () {
    test('uses the WithTenant repositories', () {
      expect(service, contains('liveActivityRepositoryWithTenantProvider'));
      expect(service, contains('planRepositoryWithTenantProvider'));
      expect(service, isNot(contains('ref.read(liveActivityRepositoryProvider)')));
    });

    // DB_REVIEW_REST (F2): native iOS and Android (live plan notification).
    test('is a no-op outside the native iOS / Android app', () {
      expect(service, contains('return !kIsWeb &&'));
      expect(service, contains('defaultTargetPlatform == TargetPlatform.iOS'));
      expect(service, contains('defaultTargetPlatform == TargetPlatform.android'));
    });

    test('channel name matches the Swift plugin', () {
      final swift = File('ios/Runner/LiveActivityPlugin.swift').readAsStringSync();
      expect(service, contains("'de.attendix/live_activity'"));
      expect(swift, contains('"de.attendix/live_activity"'));
      for (final method in ['isAvailable', 'start', 'update', 'end', 'endAll', 'list', 'getTokens', 'configure', 'takePendingUrl']) {
        expect(swift, contains('case "$method"'), reason: method);
      }
    });

    test('SOL_FIX18: native uploads are gated and awaited on close', () {
      final swift = File('ios/Runner/LiveActivityPlugin.swift').readAsStringSync();
      expect(swift, contains('case "setRegistrationOpen": setRegistrationOpen(args, result)'));
      expect(swift, contains('LiveActivityTokenReporter.shared.setUploadsOpen(open)'));
      // upload() bails out while closed and tracks every request.
      final upload = swift.substring(swift.indexOf('private func upload('));
      expect(upload, contains('guard uploadsOpen,'));
      expect(upload, contains('group.enter()'));
      expect(upload, contains('group.leave()'));
      expect(swift, contains('uploads.notify(queue: .main, execute: completion)'));
      // Balanced braces / parentheses as a cheap syntax sanity check.
      expect('{'.allMatches(swift).length, '}'.allMatches(swift).length);
      expect('('.allMatches(swift).length, ')'.allMatches(swift).length);
      // Dart closes before it deletes rows and re-opens on init.
      final end = service.substring(service.indexOf('Future<void> endSession('));
      expect(end.indexOf('_setNativeRegistrationOpen(false)'),
          lessThan(end.indexOf('_host.removeTokens(')));
      expect(service, contains('await _setNativeRegistrationOpen(true);'));
    });
  });

  group('Notifications page toggle', () {
    test('only shown with the native side, Ionic keys', () {
      expect(page, contains('hasNativePlugin'));
      expect(page, contains('context.l10n.notifLiveActivity'));
      expect(page, contains('context.l10n.notifLiveActivityHelperIos'));
      expect(page, contains('config.liveActivity != false'));
    });
  });

  group('iOS project', () {
    test('Info.plist declares Live Activities and the attendix scheme', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<key>NSSupportsLiveActivities</key>'));
      expect(plist, contains('<key>NSSupportsLiveActivitiesFrequentUpdates</key>'));
      expect(plist, contains('<string>attendix</string>'));
    });

    test('AppDelegate registers the plugin and starts the token reporter', () {
      final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(delegate, contains('LiveActivityPlugin.register(with: registrar)'));
      expect(delegate, contains('LiveActivityTokenReporter.shared.start()'));
    });

    test('Runner target compiles the plugin and the shared attributes', () {
      final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(pbx, contains('LiveActivityPlugin.swift in Sources'));
      expect(pbx, contains('PlanActivityAttributes.swift in Sources'));
      expect('{'.allMatches(pbx).length, '}'.allMatches(pbx).length);
      expect('('.allMatches(pbx).length, ')'.allMatches(pbx).length);
    });

    test('widget extension sources are present', () {
      for (final f in [
        'AttendixLiveActivityBundle.swift',
        'PlanLiveActivity.swift',
        'PlanActivityAttributes.swift',
        'Info.plist',
      ]) {
        expect(File('ios/AttendixLiveActivity/$f').existsSync(), isTrue, reason: f);
      }
    });
  });
}
