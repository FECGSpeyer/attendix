import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PUSH: source analysis of the user-scoped push queries (Ionic PushService).
void main() {
  group('DeviceTokenRepository - Security', () {
    late String source;

    setUpAll(() {
      source = File('lib/data/repositories/device_token_repository.dart')
          .readAsStringSync();
    });

    List<String> queries(String table) =>
        RegExp("\\.from\\('$table'\\)[^;]*;", dotAll: true)
            .allMatches(source)
            .map((m) => m.group(0)!)
            .toList();

    test('documents the multi-tenant exception (no tenantId column)', () {
      expect(source, contains('MULTI-TENANT EXCEPTION'));
      expect(source, contains('RLS'));
    });

    test('device_tokens deletes are scoped by token or user like Ionic', () {
      final deletes =
          queries('device_tokens').where((q) => q.contains('.delete()')).toList();
      expect(deletes, hasLength(3));
      for (final q in deletes) {
        final scoped = q.contains(".eq('token', token)") ||
            q.contains(".eq('user_id', userId)");
        expect(scoped, isTrue, reason: q);
      }
      // saveToken: token of other users + other tokens of this user
      expect(source, contains(".eq('token', token)\n          .neq('user_id', userId)"));
      expect(source, contains(".eq('user_id', userId)\n          .neq('token', token)"));
    });

    test('SOL_FIX18: logout delete is scoped by token AND user', () {
      final start = source.indexOf('Future<void> removeToken(String token) async');
      final body = source.substring(start, source.indexOf('\n  }\n', start));
      expect(body, contains('if (userId == null) return;'));
      final delete = RegExp("\\.from\\('device_tokens'\\)[^;]*;", dotAll: true)
          .firstMatch(body)!
          .group(0)!;
      expect(delete, contains('.delete()'));
      expect(delete, contains(".eq('token', token)"));
      expect(delete, contains(".eq('user_id', userId)"));
    });

    test('upsert writes the Ionic columns', () {
      final upsert =
          queries('device_tokens').where((q) => q.contains('.upsert(')).single;
      for (final col in ['user_id', 'token', 'platform', 'updated_at']) {
        expect(upsert, contains("'$col'"), reason: col);
      }
    });

    test('SOL_FIX17: the session guard is re-checked right before the upsert', () {
      final save = source.substring(
          source.indexOf('Future<void> saveToken(\n'), source.indexOf('Future<void> removeToken(String token) async'));
      final upsertAt = save.indexOf("await supabase.from('device_tokens').upsert(");
      final lastCheck = save.lastIndexOf('if (stale()) return;', upsertAt);
      expect(lastCheck, greaterThan(0));
      expect(save.substring(lastCheck, upsertAt), isNot(contains('await')));
      expect('if (stale()) return;'.allMatches(save).length, 3);
    });

    test('push_enabled is only updated on the own notifications row', () {
      final q = queries('notifications').single;
      expect(q, contains("{'push_enabled': enabled}"));
      expect(q, contains(".eq('id', userId)"));
    });

    test('no unfiltered select / update', () {
      expect(source, isNot(contains('.select(')));
    });
  });

  test('UserNotificationRepository.markMatchingRead is user + tenant scoped', () {
    final src = File('lib/data/repositories/user_notification_repository.dart')
        .readAsStringSync();
    final start = src.indexOf('Future<void> markMatchingRead(');
    expect(start, greaterThan(-1));
    final body = src.substring(start, src.indexOf('\n  }\n', start));
    expect(body, contains(".eq('user_id', _userId)"));
    expect(body, contains(".eq('tenantId', currentTenantId)"));
    expect(body, contains(".eq('type', type)"));
    expect(body, contains(".eq('read', false)"));
    expect(body, contains(".eq('data->>attendanceId', attendanceId)"));
  });

  test('logout removes the push token before signing out', () {
    for (final path in [
      'lib/features/settings/presentation/pages/settings_page.dart',
      'lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart',
    ]) {
      final src = File(path).readAsStringSync();
      final remove = src.indexOf('removePushTokenBeforeSignOut(ref)');
      final signOut = src.indexOf('auth.signOut()', remove);
      expect(remove, greaterThan(-1), reason: path);
      expect(signOut, greaterThan(remove), reason: path);
    }
  });

  test('native push config is present (Ionic parity)', () {
    expect(File('ios/Runner/Info.plist').readAsStringSync(),
        contains('<string>remote-notification</string>'));
    expect(File('ios/Runner/Runner.entitlements').readAsStringSync(),
        contains('aps-environment'));
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('default_notification_channel_id'));
    expect(File('android/app/build.gradle.kts').readAsStringSync(),
        contains('file("google-services.json").exists()'));
  });
}
