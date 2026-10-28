import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/organisation/organisation.dart';
import '../../data/repositories/extra_fields_repository.dart';
import '../../data/repositories/files_repository.dart';
import '../../data/repositories/organisation_settings_repository.dart';
import 'tenant_providers.dart';

// SETTINGS_EXT: Dateiablage, Zusatzfelder, Branding, Personen verknüpfen

/// Dateiablage-Repository mit Tenant-Kontext
final filesRepositoryWithTenantProvider = Provider<FilesRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(filesRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [FilesRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
final filesRepositoryForTenantProvider =
    Provider.family<FilesRepository, int?>((ref, tenantId) {
  final repo = FilesRepository(ref);
  if (tenantId != null) repo.bindTenantId(tenantId);
  return repo;
});

/// Belegter Speicher der Dateiablage (Bytes), null bei Fehler / ohne Tenant
final filesUsedBytesProvider = FutureProvider.autoDispose<int?>((ref) async {
  final repo = ref.watch(filesRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  try {
    return await repo.getUsedBytes();
  } catch (_) {
    return null;
  }
});

/// Zusatzfelder-Repository mit Tenant-Kontext
final extraFieldsRepositoryWithTenantProvider = Provider<ExtraFieldsRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(extraFieldsRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [ExtraFieldsRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
final extraFieldsRepositoryForTenantProvider =
    Provider.family<ExtraFieldsRepository, int?>((ref, tenantId) {
  final repo = ExtraFieldsRepository(ref);
  if (tenantId != null) repo.bindTenantId(tenantId);
  return repo;
});

/// Organisations-Einstellungen (Branding, Personen verknüpfen) mit Tenant-Kontext
final organisationSettingsRepositoryWithTenantProvider = Provider<OrganisationSettingsRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(organisationSettingsRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [OrganisationSettingsRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
final organisationSettingsRepositoryForTenantProvider =
    Provider.family<OrganisationSettingsRepository, int?>((ref, tenantId) {
  final repo = OrganisationSettingsRepository(ref);
  if (tenantId != null) repo.bindTenantId(tenantId);
  return repo;
});

/// Organisation der aktuellen Instanz inkl. Branding-Feldern
final brandingOrganisationProvider = FutureProvider.autoDispose<Organisation?>((ref) async {
  final repo = ref.watch(organisationSettingsRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  return repo.getCurrentOrganisation();
});

/// Formatierung wie FilesPage.formatFileSize in Ionic
String formatFileSize(int? size) {
  if (size == null || size < 0) return '';
  if (size < 1024) return '$size B';
  final kb = size / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}
