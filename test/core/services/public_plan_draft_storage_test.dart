import 'dart:io';

import 'package:attendix/core/services/public_plan_draft_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SOL_FIX12: Ablaufplanung drafts (plan content + plan id + edit key) are
/// bound to the auth user and removed on sign-out / account switch.
void main() {
  test('drafts are keyed per user, anonymous separately, never the legacy key', () {
    expect(PublicPlanDraftStorage.keyFor('user-a'), isNot(PublicPlanDraftStorage.keyFor('user-b')));
    expect(PublicPlanDraftStorage.keyFor(null), PublicPlanDraftStorage.anonymousKey);
    for (final id in [null, 'user-a']) {
      expect(PublicPlanDraftStorage.keyFor(id), isNot(PublicPlanDraftStorage.legacyKey));
    }
  });

  test('sign-out removes the previous user draft and the legacy entry only', () async {
    SharedPreferences.setMockInitialValues({
      PublicPlanDraftStorage.keyFor('user-a'): '{"currentEditKey":"a"}',
      PublicPlanDraftStorage.keyFor('user-b'): '{"currentEditKey":"b"}',
      PublicPlanDraftStorage.anonymousKey: '{"planTitle":"anon"}',
      PublicPlanDraftStorage.legacyKey: '{"currentEditKey":"legacy"}',
    });
    await clearPublicPlanDrafts('user-a');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PublicPlanDraftStorage.keyFor('user-a')), isNull);
    expect(prefs.getString(PublicPlanDraftStorage.legacyKey), isNull);
    expect(prefs.getString(PublicPlanDraftStorage.keyFor('user-b')), isNotNull);
    expect(prefs.getString(PublicPlanDraftStorage.anonymousKey), isNotNull);
  });

  test('the account listener clears the draft of the previous user', () {
    final main = File('lib/main.dart').readAsStringSync();
    final listener = main.substring(main.indexOf('ref.listen(currentUserProvider'));
    expect(listener, contains('clearPublicPlanDrafts(previous?.valueOrNull?.id)'));
  });

  test('the planning page reads and writes only the key of its user', () {
    final page = File('lib/features/planning/presentation/pages/public_planning_page.dart').readAsStringSync();
    expect(page, contains('PublicPlanDraftStorage.keyFor(_draftUserId)'));
    expect(page, contains('if (_currentUserId != _draftUserId) return;'));
    expect(page, isNot(contains("'attendix-public-plan'")));
  });
}
