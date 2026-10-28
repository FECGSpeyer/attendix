import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/pdf_branding.dart';
import 'files_providers.dart';

/// Branding source of the current instance (org branding first, then the
/// instance's own logo/text — Ionic `db.getBrandingSource()`).
final brandingSourceProvider =
    FutureProvider<({String? logoUrl, String? text})?>((ref) async {
  final repo = ref.watch(organisationSettingsRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  try {
    return await repo.getBrandingSource();
  } catch (_) {
    return null;
  }
});

/// True when a logo and/or branding text is configured. Gates the
/// "Branding einbeziehen" toggle in the planning page.
final hasBrandingProvider = Provider<bool>((ref) {
  final source = ref.watch(brandingSourceProvider).valueOrNull;
  return (source?.logoUrl?.isNotEmpty ?? false) || (source?.text?.trim().isNotEmpty ?? false);
});

/// Resolved export branding (logo downloaded + downscaled) or null when
/// nothing is configured / no tenant is selected. Never throws.
final pdfBrandingProvider = FutureProvider<PdfBranding?>((ref) async {
  final source = await ref.watch(brandingSourceProvider.future);
  if (source == null) return null;
  return PdfBranding.fromSource(logoUrl: source.logoUrl, text: source.text);
});

/// Session-wide "Branding einbeziehen" toggle of the planning page
/// (Ionic planning.page `includeBranding`, default true).
final includeBrandingProvider = StateProvider<bool>((ref) => true);

/// Resolves the export branding for a one-off export; null on any failure
/// so branding never breaks an export.
Future<PdfBranding?> resolvePdfBranding(WidgetRef ref) async {
  try {
    return await ref.read(pdfBrandingProvider.future);
  } catch (_) {
    return null;
  }
}
