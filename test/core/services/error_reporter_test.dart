import 'dart:io';

import 'package:attendix/core/services/error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';

void main() {
  group('ErrorReporter', () {
    test('without DSN it stays off and report is a no-op', () async {
      await ErrorReporter.init(dsn: '', release: '0.0.0');
      expect(ErrorReporter.isEnabled, isFalse);
      ErrorReporter.report(StateError('x'), StackTrace.current, where: 'test');
    });

    test('scrub removes user, request, breadcrumbs and server name', () {
      final event = SentryEvent(
        user: SentryUser(id: 'u1', email: 'a@b.de'),
        request: SentryRequest(url: 'https://x', data: {'pw': 'secret'}),
        breadcrumbs: [Breadcrumb(message: 'tap')],
        serverName: 'host',
      );
      final out = ErrorReporter.scrub(event, Hint())!;
      expect(out.user, isNull);
      expect(out.request, isNull);
      expect(out.breadcrumbs, isNull);
      expect(out.serverName, isNull);
    });

    test('network failures are not reported', () {
      expect(ErrorReporter.isExpected(const SocketException('Failed host lookup')), isTrue);
      expect(ErrorReporter.isExpected(Exception('ClientException: XMLHttpRequest error')), isTrue);
      expect(ErrorReporter.isExpected(StateError('Bad state')), isFalse);
    });

    test('repositories report every handled error', () {
      final base = File('lib/data/repositories/base_repository.dart').readAsStringSync();
      expect(base, contains('ErrorReporter.report(error, stack'));
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('FlutterError.onError'));
      expect(main, contains('PlatformDispatcher.instance.onError'));
    });
  });
}
