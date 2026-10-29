import 'dart:async';
import 'dart:io';

import 'package:attendix/core/utils/error_message.dart';
import 'package:attendix/data/repositories/base_repository.dart';
import 'package:attendix/shared/widgets/common/error_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

void main() {
  group('friendlyErrorMessage', () {
    const offline = 'Keine Internetverbindung vorhanden';

    test('maps http ClientException (Failed to fetch) to no-connection', () {
      final e = http.ClientException(
        'Failed to fetch',
        Uri.parse('http://127.0.0.1:54321/rest/v1/tenants?select=*'),
      );
      expect(isNetworkError(e), isTrue);
      expect(friendlyErrorMessage(e), offline);
    });

    test('unwraps RepositoryException around a network error', () {
      final e = RepositoryException(
        message: 'ClientException: Failed to fetch, uri=http://x/rest/v1/t',
        operation: 'getTenantBySongSharingId',
        originalError: http.ClientException('Failed to fetch'),
      );
      expect(friendlyErrorMessage(e), offline);
    });

    test('maps SocketException and TimeoutException to no-connection', () {
      expect(friendlyErrorMessage(const SocketException('Connection refused')),
          offline);
      expect(friendlyErrorMessage(TimeoutException('t')), offline);
    });

    test('shows Supabase messages without technical wrapping', () {
      expect(
        friendlyErrorMessage(const PostgrestException(message: 'Duplicate key')),
        'Duplicate key',
      );
      expect(friendlyErrorMessage(const AuthException('Invalid login')),
          'Invalid login');
      expect(
        friendlyErrorMessage(const RepositoryException(
          message: 'Name fehlt',
          operation: 'create',
        )),
        'Name fehlt',
      );
    });

    test('strips the Exception: prefix', () {
      expect(friendlyErrorMessage(Exception('HTTP 404')), 'HTTP 404');
    });

    test('falls back to a generic text for technical dumps', () {
      expect(friendlyErrorMessage(null), 'Unbekannter Fehler');
      expect(
        friendlyErrorMessage(
            "type 'Null' is not a subtype of type 'String' in type cast"),
        'Unbekannter Fehler',
      );
      expect(
        friendlyErrorMessage(const RepositoryException(
          message: 'boom',
          operation: 'x',
          originalError: 'something uri=http://a/b failed',
        )),
        'Unbekannter Fehler',
      );
    });
  });

  group('ErrorStateView', () {
    testWidgets('shows friendly text and retry button, never the raw error',
        (tester) async {
      var retried = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ErrorStateView(
            error: http.ClientException('Failed to fetch',
                Uri.parse('http://127.0.0.1:54321/rest/v1/tenants')),
            onRetry: () => retried++,
          ),
        ),
      ));
      expect(find.text('Keine Internetverbindung vorhanden'), findsOneWidget);
      expect(find.textContaining('ClientException'), findsNothing);
      expect(find.textContaining('uri='), findsNothing);
      await tester.tap(find.text('ERNEUT VERSUCHEN')); // MD_BUTTONS: md uppercase
      expect(retried, 1);
    });
  });

  group('Source guards', () {
    final keyWithRawError = RegExp(
      r"l10n(?:WithoutContext)?\.[a-zA-Z0-9]*(?:Error|Failed)[a-zA-Z0-9]*\(\s*"
      r"(?:e|error|err|e\.toString\(\)|error\.toString\(\)|'\$e'|'\$error')\s*\)",
    );

    test('UI never passes raw exceptions to error l10n messages', () {
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.contains('l10n/generated')) continue;
        final src = f.readAsStringSync();
        for (final m in keyWithRawError.allMatches(src)) {
          offenders.add('${f.path}: ${m.group(0)}');
        }
      }
      expect(offenders, isEmpty,
          reason: 'wrap the error in friendlyErrorMessage(...)');
    });

    test('pdf.js setup in web/index.html is guarded', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, isNot(contains('var { pdfjsLib } = globalThis;')));
      expect(html, contains('if (pdfjsLib && pdfjsLib.GlobalWorkerOptions)'));
    });
  });
}
