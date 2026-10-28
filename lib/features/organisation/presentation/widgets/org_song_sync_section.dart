import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/song_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import '../../../settings/presentation/widgets/settings_list.dart'; // UX_SETTINGS (WAVE 8)

/// SETTINGS2: Ionic org-settings "Werk-Synchronisierung" (super admin only).
///
/// Picks the source instance whose song library this instance uses
/// (`tenants.song_source_tenant_id`), or "Keine (eigene Werke)".
class OrgSongSyncSection extends ConsumerStatefulWidget {
  const OrgSongSyncSection({super.key, required this.linkedTenants});

  /// Other instances of the organisation (current tenant excluded).
  final List<Tenant> linkedTenants;

  @override
  ConsumerState<OrgSongSyncSection> createState() => _OrgSongSyncSectionState();
}

class _OrgSongSyncSectionState extends ConsumerState<OrgSongSyncSection> {
  bool _saving = false;

  Future<bool> _confirmDeactivation() async {
    final result = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.orgDisableSync),
        content: Text(context.l10n.orgDisableSyncMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.orgDisable),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _save(int? current, int? newSourceId) async {
    if (newSourceId == current) return;
    if (current != null && newSourceId == null) {
      if (!await _confirmDeactivation()) return;
    }
    setState(() => _saving = true);
    try {
      final tenantId = ref.read(currentTenantIdProvider);
      if (tenantId == null) return;
      // SOL_FIX1: per-tenant instance instead of mutating the shared one.
      final repo = ref.read(songRepositoryForTenantProvider(
          (tenantId: tenantId, songSourceTenantId: null)));
      await repo.updateSongSourceTenantId(newSourceId);
      ref.invalidate(songTenantSettingsProvider);
      ref.invalidate(currentTenantProvider);
      if (mounted) ToastHelper.showSuccess(context, context.l10n.orgSyncSaved);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.plansSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(songTenantSettingsProvider);
    final current = settings.valueOrNull?.songSourceTenantId;

    final items = <Widget>[
              ListTile(
                leading: const Icon(Icons.sync),
                title: Text(context.l10n.orgSongSyncIntro),
              ),
              ListTile(
                title: Text(context.l10n.orgSourceTenant),
                trailing: _saving || settings.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: AppSpinner(strokeWidth: 2),
                      )
                    : DropdownButton<int?>(
                        value: widget.linkedTenants.any((t) => t.id == current) ||
                                current == null
                            ? current
                            : null,
                        underline: const SizedBox.shrink(),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(context.l10n.orgNoneOwnSongs),
                          ),
                          for (final t in widget.linkedTenants)
                            DropdownMenuItem<int?>(value: t.id, child: Text(t.shortName)),
                        ],
                        onChanged: (v) => _save(current, v),
                      ),
              ),
    ];
    // UX_SETTINGS (WAVE 8): Ionic inset list with list header on iOS.
    if (ionIsIos(context)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SettingsListSection(title: context.l10n.orgSongSync, children: items),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            context.l10n.orgSongSync.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.medium),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: items),
        ),
      ],
    );
  }
}
