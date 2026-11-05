import '../../../core/config/supabase_config.dart';
import '../../../core/services/pdf_branding.dart';

/// Branding selectable on the public planning page (Ionic `PUBLIC_BRANDINGS`
/// in public-planning-templates.ts). Stored as `shared_plans.branding_id`
/// and drawn into PDF, image and Telegram exports of the plan instead of the
/// instance branding (the public planner has no instance context).
class PublicBranding {
  const PublicBranding(this.id, this.name, {this.text, this.hasLogo = false});
  final String id;
  final String name;
  final String? text;
  final bool hasLogo;
}

const publicBrandings = [
  PublicBranding('none', 'Kein Branding'),
  PublicBranding('fecg-speyer', 'FECG Speyer', text: 'FECG Speyer', hasLogo: true),
  PublicBranding('fecg-schwegenheim', 'FECG Schwegenheim', text: 'FECG Schwegenheim', hasLogo: true),
];

/// Ionic `FECG_LOGO`: both FECG brandings share this logo.
String get fecgLogoUrl =>
    '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/public_files/fecg_speyer.png';

/// Ionic `buildBranding()` of public-planning / shared-plan: logo + text of
/// the chosen branding, null for "Kein Branding" or an unknown id.
Future<PdfBranding?> publicPdfBranding(String? brandingId) async {
  final b = publicBrandings.where((x) => x.id == brandingId).firstOrNull;
  if (b == null || b.id == 'none') return null;
  try {
    return await PdfBranding.fromSource(logoUrl: b.hasLogo ? fecgLogoUrl : null, text: b.text);
  } catch (_) {
    return null;
  }
}
