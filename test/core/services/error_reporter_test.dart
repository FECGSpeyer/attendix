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

  test('redact removes e-mails, ids and quoted values from database errors', () {
    final text = ErrorReporter.redact(
      'duplicate key: Key (email)=(leon@example.de) already exists for 1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed',
    );
    expect(text, isNot(contains('leon@example.de')));
    expect(text, isNot(contains('1b9d6bcd')));
    expect(text, contains('Key (email)=(<value>)'));
    expect(ErrorReporter.redact('mail an a.b+c@x.org'), 'mail an <email>');
  });

  test('scrub redacts exception values', () {
    final event = SentryEvent(
      exceptions: [SentryException(type: 'PostgrestException', value: 'Key (email)=(a@b.de) exists')],
    );
    final out = ErrorReporter.scrub(event, Hint())!;
    expect(out.exceptions!.single.value, 'Key (email)=(<value>) exists');
  });

  test('database errors keep only message and code', () {
    const raw = 'PostgrestException(message: invalid input syntax for type uuid: "max-mustermann", '
        'code: 22P02, details: Failing row contains (12, Max, Mustermann, max@x.de), hint: null)';
    final text = ErrorReporter.redact(raw);
    expect(text, 'PostgrestException(message: invalid input syntax for type uuid: "<value>", code: 22P02)');
  });

  test('web offline errors are expected', () {
    expect(ErrorReporter.isExpected(Exception('ClientException: Failed to fetch')), isTrue);
  });
}
