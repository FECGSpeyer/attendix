import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/organisation/organisation.dart';
import '../../data/models/plan/plan.dart';
import '../../data/repositories/org_plan_repository.dart';
import '../../data/repositories/plan_repository.dart';
import '../utils/attendance_percentage_utils.dart' show attendanceListStartDate;
import '../utils/plan_utils.dart';
import 'organisation_providers.dart';
import 'tenant_providers.dart';
import '../../l10n/l10n.dart';

// ORG_PLANS: providers for Ablaufpläne, Org-Pläne and planning templates.

/// PlanRepository with tenant set
final planRepositoryWithTenantProvider = Provider<PlanRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(planRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [PlanRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
final planRepositoryForTenantProvider =
    Provider.family<PlanRepository, int?>((ref, tenantId) {
  final repo = PlanRepository(ref);
  if (tenantId != null) repo.bindTenantId(tenantId);
  return repo;
});

/// Termine of the current season with their plans (newest first)
final planAttendancesProvider = FutureProvider<List<PlanAttendance>>((ref) async {
  final repo = ref.watch(planRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  final seasonStart = ref.watch(currentTenantProvider.select((t) => t?.seasonStart));
  return repo.getPlanAttendances(since: attendanceListStartDate(seasonStart));
});

/// One Termin with its plans
final planAttendanceByIdProvider = FutureProvider.family<PlanAttendance?, int>((ref, id) async {
  final repo = ref.watch(planRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  return repo.getPlanAttendanceById(id);
});

/// Attendance types with their planning settings
final planAttendanceTypesProvider = FutureProvider<List<PlanAttendanceType>>((ref) async {
  final repo = ref.watch(planRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getPlanAttendanceTypes();
});

/// Saved Programmblock templates of the instance
final planBlockTemplatesProvider = FutureProvider<List<PlanBlockTemplate>>((ref) async {
  final repo = ref.watch(planRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getBlockTemplates();
});

/// Ad-hoc plans created by the current user ("Meine Pläne")
final mySharedPlansProvider = FutureProvider<List<SharedPlan>>((ref) async {
  final repo = ref.watch(planRepositoryWithTenantProvider);
  return repo.getMySharedPlans();
});

/// One entry of the Org-Pläne list: a Termin flagged as org plan or an ad-hoc plan.
class OrgPlanEntry {
  const OrgPlanEntry.attendance(PlanAttendance this.attendance)
      : sharedPlan = null;
  const OrgPlanEntry.adHoc(SharedPlan this.sharedPlan) : attendance = null;

  final PlanAttendance? attendance;
  final SharedPlan? sharedPlan;

  bool get isAdHoc => sharedPlan != null;

  String get date => attendance?.date ?? sharedPlan?.date ?? '';

  DateTime? get dateTime => DateTime.tryParse(date);

  Plan get plan => attendance?.plan ??
      Plan(
        time: sharedPlan?.time ?? '',
        end: sharedPlan?.endTime ?? '',
        fields: sharedPlan?.fields ?? const [],
        title: sharedPlan?.planTitle,
      );

  String get title {
    if (attendance != null) {
      final t = attendance!.plan?.title;
      if (t != null && t.isNotEmpty) return t;
      final info = attendance!.typeInfo;
      if (info != null && info.isNotEmpty) return info;
      return 'Plan';
    }
    final t = sharedPlan?.planTitle;
    return (t != null && t.isNotEmpty) ? t : 'Plan';
  }

  String get tenantLabel =>
      attendance != null ? (attendance!.tenantName ?? '') : l10nWithoutContext.plansOrgPlan;

  int get fieldCount => plan.fields.length;

  /// Same entry? (for realtime updates)
  String get key => attendance != null ? 'att-${attendance!.id}' : 'adhoc-${sharedPlan!.id}';
}

/// Splits org plan entries into upcoming (today or later, ascending) and past (descending).
({List<OrgPlanEntry> upcoming, List<OrgPlanEntry> past}) splitOrgPlanEntries(
  List<OrgPlanEntry> entries, [
  DateTime? now,
]) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final sorted = [...entries]
    ..sort((a, b) => (a.dateTime ?? DateTime(0)).compareTo(b.dateTime ?? DateTime(0)));
  bool isPast(OrgPlanEntry e) {
    final d = e.dateTime;
    if (d == null) return false;
    return DateTime(d.year, d.month, d.day).isBefore(today);
  }

  return (
    upcoming: sorted.where((e) => !isPast(e)).toList(),
    past: sorted.where(isPast).toList().reversed.toList(),
  );
}

/// Org plans of the current organisation (Termine + ad-hoc plans)
final orgPlansProvider = FutureProvider<List<OrgPlanEntry>>((ref) async {
  final org = await ref.watch(currentOrganisationProvider.future);
  if (org?.id == null) return [];
  final repo = ref.watch(orgPlanRepositoryProvider);
  final results = await Future.wait([
    repo.getOrgPlans(org!.id!),
    repo.getAdHocOrgPlans(org.id!).catchError((_) => <SharedPlan>[]),
  ]);
  final attendances = results[0] as List<PlanAttendance>;
  final adHoc = results[1] as List<SharedPlan>;
  return [
    ...attendances.where((a) => a.plan != null).map(OrgPlanEntry.attendance),
    ...adHoc.map(OrgPlanEntry.adHoc),
  ];
});

/// Mutations for planning settings (block templates, org templates, org settings)
class PlanSettingsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> _run(Future<void> Function() action, {List<ProviderOrFamily> invalidate = const []}) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
      for (final p in invalidate) {
        ref.invalidate(p);
      }
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Saves the block templates of the instance (admins only)
  Future<bool> saveBlockTemplates(List<PlanBlockTemplate> templates) {
    return _saveBlockTemplatesWith(
        ref.read(planRepositoryWithTenantProvider), templates);
  }

  /// SOL_FIX7: writes [templates] through the repository [repo] that was
  /// bound before the caller's first await, so the read (current templates)
  /// and the write always hit the same tenant even if the user switches
  /// tenants in between.
  Future<bool> _saveBlockTemplatesWith(
      PlanRepository repo, List<PlanBlockTemplate> templates) {
    return _run(
      () => repo.saveBlockTemplates(templates),
      invalidate: [planBlockTemplatesProvider],
    );
  }

  /// Saves (or replaces by name) a block of [fields] as template.
  Future<bool> saveBlockAsTemplate(List<PlanField> fields, String headId) async {
    final repo = ref.read(planRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return false;
    final existing = await repo.getBlockTemplates();
    final template = PlanUtils.blockTemplateFrom(fields, headId);
    final others = existing.where((t) => t.name != template.name).toList();
    return _saveBlockTemplatesWith(repo, [...others, template]);
  }

  Future<bool> deleteBlockTemplate(String id) async {
    final repo = ref.read(planRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return false;
    final existing = await repo.getBlockTemplates();
    return _saveBlockTemplatesWith(
        repo, existing.where((t) => t.id != id).toList());
  }

  Future<bool> setTypeDefaultOrgPlan(String typeId, bool value) {
    return _run(
      () => ref.read(planRepositoryWithTenantProvider).setTypeDefaultOrgPlan(typeId, value),
      invalidate: [planAttendanceTypesProvider],
    );
  }

  Future<bool> _updateOrg(Future<Organisation> Function(OrgPlanRepository repo, int orgId) action) async {
    final org = await ref.read(currentOrganisationProvider.future);
    if (org?.id == null) return false;
    return _run(
      () => action(ref.read(orgPlanRepositoryProvider), org!.id!),
      invalidate: [currentOrganisationProvider],
    );
  }

  Future<bool> updatePlanningTemplates(List<Plan> templates) =>
      _updateOrg((repo, id) => repo.updatePlanningTemplates(id, templates));

  Future<bool> updateDefaultFields(List<PlanField> fields) =>
      _updateOrg((repo, id) => repo.updateDefaultFields(id, fields));

  Future<bool> updateOrgName(String name) => _updateOrg((repo, id) => repo.updateOrgName(id, name));

  /// Saves org person fields and removes values of deleted fields.
  Future<bool> updateOrgExtraFields(List<OrgExtraField> fields, List<String> deletedFieldIds) =>
      _updateOrg((repo, id) async {
        final org = await repo.updateOrgExtraFields(id, fields);
        await repo.deletePersonFieldValues(id, deletedFieldIds);
        return org;
      });

  Future<String?> generatePublicPlanKey() async {
    final org = await ref.read(currentOrganisationProvider.future);
    if (org?.id == null) return null;
    final key = PlanUtils.randomKey(16);
    final ok = await _run(
      () => ref.read(orgPlanRepositoryProvider).generatePublicPlanKey(org!.id!, key),
      invalidate: [currentOrganisationProvider],
    );
    return ok ? key : null;
  }

  Future<bool> revokePublicPlanKey() async {
    final org = await ref.read(currentOrganisationProvider.future);
    if (org?.id == null) return false;
    return _run(
      () => ref.read(orgPlanRepositoryProvider).revokePublicPlanKey(org!.id!),
      invalidate: [currentOrganisationProvider],
    );
  }

  Future<bool> deleteAdHocOrgPlan(String planId) async {
    final org = await ref.read(currentOrganisationProvider.future);
    if (org?.id == null) return false;
    return _run(
      () => ref.read(orgPlanRepositoryProvider).deleteAdHocOrgPlan(org!.id!, planId),
      invalidate: [orgPlansProvider],
    );
  }
}

final planSettingsNotifierProvider =
    NotifierProvider<PlanSettingsNotifier, AsyncValue<void>>(PlanSettingsNotifier.new);
