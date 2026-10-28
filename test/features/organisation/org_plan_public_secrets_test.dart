// SOL_FIX7: public plan pages must never receive edit keys over realtime.
// `postgres_changes` payloads carry the full row (share_key, share_edit_key,
// edit_key), so the anonymous org page polls the whitelisted select instead.
import 'dart:io';

import 'package:attendix/core/providers/plan_providers.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/features/organisation/presentation/pages/org_plan_public_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Multi-Tenant Security: public plan secrets', () {
    test('org public page does not subscribe to postgres_changes rows', () {
      final src = File(
              'lib/features/organisation/presentation/pages/org_plan_public_page.dart')
          .readAsStringSync()
          .replaceAll(RegExp(r'//[^\n]*'), '');
      expect(src, isNot(contains('watchSharedAttendancePlan')));
      expect(src, isNot(contains('watchSharedPlan')));
      expect(src, isNot(contains('onPostgresChanges')));
      expect(src, isNot(contains('.channel(')));
      expect(src, contains('getPublicOrgPlans'));
      expect(src, contains('Timer.periodic'));
    });

    test('shared plan page subscribes only after the edit key was verified', () {
      final src = File(
              'lib/features/planning/presentation/pages/shared_plan_page.dart')
          .readAsStringSync();
      for (final (watch, verify) in [
        ('watchSharedAttendancePlan(', 'verifySharedAttendanceEditKey('),
        ('watchSharedPlan(', 'verifySharedPlanEditKey('),
      ]) {
        final w = src.indexOf(watch);
        expect(w, greaterThan(0));
        final v = src.lastIndexOf(verify, w);
        expect(v, greaterThan(0), reason: '$watch must follow $verify');
        // The watch call sits in the block guarded by the verify call.
        expect(src.substring(v, w), contains('_editMode = true'));
      }
    });

    test('no other public page opens a realtime channel', () {
      for (final path in [
        'lib/features/planning/presentation/pages/public_planning_page.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src, isNot(contains('onPostgresChanges')), reason: path);
        expect(src, isNot(contains('watchShared')), reason: path);
      }
    });

    test('public reads never select the secret columns', () {
      final src = File('lib/data/repositories/public_plan_repository.dart')
          .readAsStringSync();
      final selects = RegExp(r"\.select\(([^)]*)\)").allMatches(src);
      for (final m in selects) {
        final arg = m.group(1)!;
        expect(arg, isNot(contains('edit_key')), reason: arg);
        expect(arg, isNot(contains('share_key')), reason: arg);
        expect(arg, isNot(contains("'*'")), reason: arg);
      }
    });

    test('mergeOrgPlanUpdates only updates entries already shown', () {
      const a1 = PlanAttendance(id: 1, date: '2026-11-01', plan: Plan(time: '18:00'));
      const a1New = PlanAttendance(id: 1, date: '2026-11-01', plan: Plan(time: '19:00'));
      const a2 = PlanAttendance(id: 2, date: '2026-11-02', plan: Plan(time: '10:00'));
      final shown = [OrgPlanEntry.attendance(a1)];
      final fresh = {
        const OrgPlanEntry.attendance(a1New).key: const OrgPlanEntry.attendance(a1New),
        const OrgPlanEntry.attendance(a2).key: const OrgPlanEntry.attendance(a2),
      };
      final merged = mergeOrgPlanUpdates(shown, fresh);
      expect(merged, hasLength(1));
      expect(merged.single.plan.time, '19:00');
      // Missing in the fresh result (e.g. network partial) keeps the old entry.
      expect(mergeOrgPlanUpdates(shown, const {}).single.plan.time, '18:00');
    });
  });
}
