import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-analysis security tests for LegalRepository and AccountRepository.
///
/// Both are intentionally NOT tenant-aware:
///   - `legal_content` is a global single-row table (id = 1) without tenantId.
///   - Account operations act on the authenticated user only (edge function
///     derives the user from the JWT).
void main() {
  late String legalSource;
  late String accountSource;

  setUpAll(() {
    legalSource =
        File('lib/data/repositories/legal_repository.dart').readAsStringSync();
    accountSource = File('lib/data/repositories/account_repository.dart')
        .readAsStringSync();
  });

  group('LegalRepository', () {
    test('reads the fixed legal_content row id = 1', () {
      expect(legalSource, contains("tableName = 'legal_content'"));
      expect(legalSource, contains('legalRowId = 1'));
      expect(legalSource, contains(".eq('id', legalRowId)"));
      expect(legalSource, contains(".select('content_html')"));
    });

    test('is read-only (no insert/update/upsert/delete)', () {
      for (final op in ['.insert(', '.update(', '.upsert(', '.delete(']) {
        expect(legalSource, isNot(contains(op)), reason: 'found $op');
      }
    });

    test('documents why no tenantId filter is applied', () {
      expect(legalSource, contains('Multi-Tenant'));
      expect(legalSource, isNot(contains('TenantAwareRepository {')));
    });

    test('uses handleError + rethrow', () {
      expect(legalSource, contains("handleError(e, stack, 'getLegalContent')"));
      expect(legalSource, contains('rethrow'));
    });
  });

  group('AccountRepository', () {
    test('deletes via the delete-account edge function (like Ionic)', () {
      expect(accountSource, contains("deleteAccountFunction = 'delete-account'"));
      expect(accountSource, contains('functions.invoke(deleteAccountFunction)'));
    });

    test('never passes a user id to the edge function (JWT-derived)', () {
      expect(
        accountSource,
        isNot(matches(RegExp(r'invoke\(\s*deleteAccountFunction\s*,\s*body'))),
      );
    });

    test('does not touch any table directly', () {
      expect(accountSource, isNot(contains('.from(')));
    });

    test('signs out after deletion', () {
      final deleteBody = accountSource.substring(
        accountSource.indexOf('Future<void> deleteAccount()'),
        accountSource.indexOf('bool get hasAcceptedTerms'),
      );
      expect(deleteBody, contains('auth.signOut()'));
    });

    test('stamps terms_accepted_at in user metadata', () {
      expect(accountSource, contains("termsAcceptedAtKey = 'terms_accepted_at'"));
      expect(accountSource, contains('UserAttributes(data:'));
    });
  });
}
