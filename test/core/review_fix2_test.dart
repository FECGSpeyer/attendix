import 'dart:io';

import 'package:attendix/features/auth/data/auth_redirect_path.dart';
import 'package:flutter_test/flutter_test.dart';

/// REVIEW_FIX2: review findings waves 4+5.
void main() {
  String src(String path) => File(path).readAsStringSync();

  String body(String source, String signature) {
    final start = source.indexOf(signature);
    expect(start, isNot(-1), reason: 'missing $signature');
    final next = source.indexOf(RegExp(r'\n  (Future|///)'), start + 1);
    return source.substring(start, next < 0 ? source.length : next);
  }

  group('cleanedAuthHash', () {
    test('keeps the hash route without auth params', () {
      expect(cleanedAuthHash('#/login?token_hash=abc&type=recovery'),
          '#/login');
      expect(cleanedAuthHash('#/open-attendance?id=4&code=x'),
          '#/open-attendance?id=4');
      expect(cleanedAuthHash('#/tenants'), '#/tenants');
    });

    test('drops token fragments and empty hashes', () {
      expect(cleanedAuthHash('#access_token=a&refresh_token=b'), '');
      expect(cleanedAuthHash(''), '');
    });
  });

  test('auth URL is only cleared when the link was handled', () {
    final s = src('lib/features/auth/data/auth_link_listener.dart');
    expect(s,
        contains('if (outcome != AuthLinkOutcome.none) clearAuthParamsFromBrowserUrl();'));
  });

  group('demo guard', () {
    test('MessageRepository.send', () {
      final s = src('lib/data/repositories/message_repository.dart');
      expect(body(s, 'Future<String> send('), contains("ensureNotDemo('sendMessage')"));
    });

    test('DutyRepository.assign / notify / setDutyView', () {
      final s = src('lib/data/repositories/duty_repository.dart');
      expect(body(s, 'Future<void> assign('), contains("ensureNotDemo('assignDuty')"));
      expect(body(s, 'Future<void> notify('), contains('if (isDemo) return;'));
      final setView = body(s, 'Future<void> setDutyView(');
      expect(setView, contains("ensureNotDemo('setDutyView')"));
      expect(setView, contains(".eq('id', currentTenantId)"));
    });

    test('type edit page no longer writes tenants directly', () {
      final s = src(
          'lib/features/settings/presentation/pages/attendance_type_edit_page.dart');
      expect(s, isNot(contains(".from('tenants')")));
      expect(s, contains('setDutyView(true)'));
    });
  });

  test('pending link survives the terms gate', () {
    final s = src('lib/core/router/app_router.dart');
    final authBlock = s.indexOf('if (isLoggedIn && isAuthRoute) {');
    final termsCheck = s.indexOf("return '/terms';", authBlock);
    final consume = s.indexOf('PendingFileLink.consume()', authBlock);
    expect(termsCheck, greaterThan(authBlock));
    expect(consume, greaterThan(termsCheck));
    expect(s, contains("return PendingFileLink.consume() ?? '/tenants';"));
    expect(src('lib/features/legal/presentation/pages/terms_page.dart'),
        contains("PendingFileLink.consume() ?? '/tenants'"));
  });

  test('main: Teams init not awaited, update toast uses root messenger', () {
    final s = src('lib/main.dart');
    expect(s, isNot(contains('await TeamsService.instance.init()')));
    expect(s, contains('unawaited(TeamsService.instance.init())'));
    expect(s, contains('rootScaffoldMessengerKey.currentState'));
  });

  test('web/_headers allows Teams framing', () {
    final rules = src('web/_headers')
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('#'))
        .join('\n');
    expect(rules, contains('frame-ancestors'));
    expect(rules, contains('teams.microsoft.com'));
    expect(rules, isNot(contains('X-Frame-Options')));
  });

  test('locale-dependent provider labels watch localeProvider', () {
    // REVIEW_FIX3: the statistics group labels are no longer localized
    // (computeGroupAttendanceRates / computeAverageAgePerGroup), so the
    // statistics providers must not watch localeProvider any more.
    final stats = src('lib/core/providers/statistics_providers.dart');
    expect(stats, isNot(contains('ref.watch(localeProvider)')));
    final songs = src('lib/core/providers/song_providers.dart');
    expect(songs, contains('ref.watch(localeProvider)'));
    expect(songs, contains('conductorsLabel ?? l10nWithoutContext.songsConductors'));
  });
}
