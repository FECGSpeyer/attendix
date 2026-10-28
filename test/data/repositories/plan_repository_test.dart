import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Security tests for the Ablaufplan repositories (ORG_PLANS).
///
/// - PlanRepository: instance data, every query scoped by the current tenant
///   (`attendance.tenantId`, `attendance_types.tenant_id`, `tenants.id`) or,
///   for `shared_plans`, by `creator_user_id`.
/// - OrgPlanRepository: organisation data, scoped by the organisation id.
/// - PublicPlanRepository: no login, every query scoped by a secret key.
void main() {
  late String planRepo;
  late String orgRepo;
  late String publicRepo;

  setUpAll(() {
    planRepo = File('lib/data/repositories/plan_repository.dart').readAsStringSync();
    orgRepo = File('lib/data/repositories/org_plan_repository.dart').readAsStringSync();
    publicRepo = File('lib/data/repositories/public_plan_repository.dart').readAsStringSync();
  });

  Iterable<String> queries(String source, String table) => RegExp(
        "\\.from\\('$table'\\)[^;]+;",
        multiLine: true,
      ).allMatches(source).map((m) => m.group(0)!);

  group('Multi-Tenant Security - PlanRepository', () {
    test('extends BaseRepository with TenantAwareRepository', () {
      expect(planRepo, contains('extends BaseRepository with TenantAwareRepository'));
    });

    test('all attendance queries filter by tenantId', () {
      final q = queries(planRepo, 'attendance').toList();
      expect(q, isNotEmpty);
      for (final query in q) {
        // SOL_FIX1: getPlanAttendances uses its captured tenant id.
        expect(
            query.contains(".eq('tenantId', currentTenantId)") ||
                query.contains(".eq('tenantId', tenantId)"),
            isTrue,
            reason: query);
      }
    });

    test('SOL_FIX1: captured tenant id is the current tenant', () {
      expect(planRepo, contains('final tenantId = currentTenantId;'));
    });

    test('attendance update filters by id AND tenantId', () {
      final body = _extractMethodBody(planRepo, 'updateAttendancePlanFields');
      expect(body, isNotNull);
      expect(body, contains(".eq('id', id)"));
      expect(body, contains(".eq('tenantId', currentTenantId)"));
    });

    test('attendance update only allows plan columns', () {
      final body = _extractMethodBody(planRepo, 'updateAttendancePlanFields');
      expect(body, contains('_allowedAttendanceKeys.contains'));
      for (final column in ['plan', 'extra_plans', 'share_plan', 'is_org_plan', 'share_key', 'share_edit_key']) {
        expect(planRepo, contains("'$column',"));
      }
    });

    test('all attendance_types queries filter by tenant_id', () {
      final q = queries(planRepo, 'attendance_types').toList();
      expect(q, isNotEmpty);
      for (final query in q) {
        expect(query, contains(".eq('tenant_id', currentTenantId)"), reason: query);
      }
    });

    test('tenants queries are scoped to the current tenant row', () {
      final q = queries(planRepo, 'tenants').toList();
      expect(q, hasLength(2));
      for (final query in q) {
        expect(query, contains(".eq('id', currentTenantId)"), reason: query);
      }
    });

    test('shared_plans queries are scoped to the current user', () {
      final q = queries(planRepo, 'shared_plans').toList();
      expect(q, isNotEmpty);
      for (final query in q) {
        final scoped = query.contains(".eq('creator_user_id', userId)") || query.contains('.upsert(');
        expect(scoped, isTrue, reason: query);
      }
      // upsert always writes the current user as creator
      expect(_extractMethodBody(planRepo, 'upsertMySharedPlan'), contains('creatorUserId: userId'));
    });
  });

  group('Multi-Tenant Security - OrgPlanRepository', () {
    test('attendance reads are limited to org instances and org plans', () {
      final q = queries(orgRepo, 'attendance').toList();
      expect(q, isNotEmpty);
      for (final query in q) {
        expect(query, contains(".inFilter('tenantId', tenantIds)"), reason: query);
        expect(query, contains(".eq('is_org_plan', true)"), reason: query);
        expect(query, isNot(contains('.update(')));
        expect(query, isNot(contains('.delete(')));
      }
    });

    test('tenant_groups queries filter by organisation id', () {
      final q = queries(orgRepo, 'tenant_groups').toList();
      expect(q, isNotEmpty);
      for (final query in q) {
        expect(query, contains(".eq('id', orgId)"), reason: query);
      }
    });

    test('shared_plans queries filter by org_id', () {
      final q = queries(orgRepo, 'shared_plans').toList();
      expect(q, isNotEmpty);
      for (final query in q) {
        expect(query, contains(".eq('org_id', orgId)"), reason: query);
      }
    });

    test('tenant_group_person_fields queries are scoped to the organisation', () {
      final q = queries(orgRepo, 'tenant_group_person_fields').toList();
      expect(q, hasLength(3));
      for (final query in q) {
        final scoped = query.contains(".eq('tenant_group', orgId)") ||
            query.contains("onConflict: 'tenant_group,person_key,field_id'");
        expect(scoped, isTrue, reason: query);
      }
      expect(_extractMethodBody(orgRepo, 'updatePersonFieldValues'), contains("'tenant_group': orgId"));
    });

    test('tenant_group_tenants queries filter by organisation', () {
      for (final query in queries(orgRepo, 'tenant_group_tenants')) {
        expect(query, contains(".eq('tenant_group', orgId)"), reason: query);
      }
    });
  });

  group('Public Access Security - PublicPlanRepository', () {
    test('shared Termin plans require id AND share_key', () {
      final body = _extractMethodBody(publicRepo, 'getSharedAttendancePlan');
      expect(body, contains(".eq('id', id)"));
      expect(body, contains(".eq('share_key', key)"));
    });

    test('editing a shared Termin plan requires the edit key', () {
      final body = _extractMethodBody(publicRepo, 'updateSharedAttendancePlan');
      expect(body, contains(".eq('id', id)"));
      expect(body, contains(".eq('share_key', key)"));
      expect(body, contains(".eq('share_edit_key', editKey)"));
      // only plan columns may be written anonymously
      expect(body, contains("e.key == 'plan' || e.key == 'extra_plans'"));
    });

    test('editing an ad-hoc plan requires its edit_key', () {
      final body = _extractMethodBody(publicRepo, 'updateSharedPlan');
      expect(body, contains(".eq('id', key)"));
      expect(body, contains(".eq('edit_key', editKey)"));
    });

    test('anonymous inserts carry no creator or organisation', () {
      final body = _extractMethodBody(publicRepo, 'insertAnonymousSharedPlan');
      expect(body, contains("..remove('creator_user_id')"));
      expect(body, contains("..remove('org_id')"));
    });

    test('public org plans only expose flagged Termine of the org instances', () {
      final body = _extractMethodBody(publicRepo, 'getPublicOrgPlans');
      expect(body, contains(".eq('tenant_group', orgId)"));
      expect(body, contains(".inFilter('tenantId', names.keys.toList())"));
      expect(body, contains(".eq('is_org_plan', true)"));
      expect(body, contains(".eq('org_id', orgId)"));
    });

    test('organisation lookup uses the public plan key', () {
      final body = _extractMethodBody(publicRepo, 'getOrgByPublicKey');
      expect(body, contains(".eq('public_plan_key', key)"));
      expect(body, contains(".select('id, name')"));
    });

    test('no public query reads attendance without a key or org filter', () {
      for (final query in queries(publicRepo, 'attendance')) {
        final scoped = query.contains(".eq('share_key', key)") || query.contains(".inFilter('tenantId'");
        expect(scoped, isTrue, reason: query);
      }
    });
  });
}

/// Extract method body from source code
String? _extractMethodBody(String source, String methodName) {
  // Declaration: return type (ends with '>' or a word) followed by the name.
  final methodStart = RegExp(
    '[>\\w]\\s+$methodName\\s*\\(',
  ).firstMatch(source);
  if (methodStart == null) return null;

  final startIndex = methodStart.start;
  var depth = 0;
  var bodyStart = -1;
  for (var i = methodStart.end - 1; i < source.length; i++) {
    final c = source[i];
    if (c == '(') depth++;
    if (c == ')') depth--;
    if (c == '{' && depth == 0) {
      bodyStart = i;
      break;
    }
  }
  if (bodyStart < 0) return null;

  var braces = 0;
  for (var i = bodyStart; i < source.length; i++) {
    if (source[i] == '{') braces++;
    if (source[i] == '}') {
      braces--;
      if (braces == 0) return source.substring(startIndex, i + 1);
    }
  }
  return null;
}
