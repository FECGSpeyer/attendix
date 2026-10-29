import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-analysis security tests for UserLanguageRepository.
///
/// `notifications` has no tenantId (one row per auth user), so every query
/// must be scoped to the user id instead.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/data/repositories/user_language_repository.dart')
        .readAsStringSync();
  });

  test('targets the Ionic notifications table', () {
    expect(source, contains("tableName = 'notifications'"));
  });

  test('every query is scoped to the user id', () {
    final queries = '.from(tableName)'.allMatches(source).length;
    final scoped = ".eq('id', userId)".allMatches(source).length;
    expect(queries, greaterThan(0));
    expect(scoped, queries);
  });

  test('only reads/updates the language column, never inserts or deletes',
      () {
    expect(source, isNot(contains('.insert(')));
    expect(source, isNot(contains('.delete(')));
    expect(source, isNot(contains('.upsert(')));
    expect(source, contains(".update({'language': language})"));
    expect(source, contains(".select('language')"));
  });

  test('documents why no tenantId filter is applied', () {
    expect(source, contains('Multi-Tenant'));
    expect(source, isNot(contains('TenantAwareRepository')));
  });

  test('uses handleError + rethrow', () {
    expect(source, contains("handleError(e, stack, 'getAccountLanguage')"));
    expect(source, contains("handleError(e, stack, 'saveAccountLanguage')"));
    expect('rethrow'.allMatches(source).length, 2);
  });
}
