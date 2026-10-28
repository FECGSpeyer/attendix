import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/song_repository.dart';

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
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Synchronisierung deaktivieren?'),
        content: const Text(
          'Die Werke dieser Instanz sind danach leer, bis eigene Werke angelegt werden. '
          'Historieneinträge auf Werke der Quellinstanz können nicht mehr aufgelöst werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deaktivieren'),
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
      final repo = ref.read(songRepositoryProvider);
      final tenantId = ref.read(currentTenantIdProvider);
      if (tenantId == null) return;
      repo.setTenantId(tenantId);
      await repo.updateSongSourceTenantId(newSourceId);
      ref.invalidate(songTenantSettingsProvider);
      ref.invalidate(currentTenantProvider);
      if (mounted) ToastHelper.showSuccess(context, 'Werk-Synchronisierung gespeichert.');
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Fehler beim Speichern');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(songTenantSettingsProvider);
    final current = settings.valueOrNull?.songSourceTenantId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'WERK-SYNCHRONISIERUNG',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.medium),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.sync),
                title: Text(
                  'Werke einer anderen Instanz verwenden. Alle Änderungen werden dort gespeichert.',
                ),
              ),
              ListTile(
                title: const Text('Quellinstanz'),
                trailing: _saving || settings.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : DropdownButton<int?>(
                        value: widget.linkedTenants.any((t) => t.id == current) ||
                                current == null
                            ? current
                            : null,
                        underline: const SizedBox.shrink(),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Keine (eigene Werke)'),
                          ),
                          for (final t in widget.linkedTenants)
                            DropdownMenuItem<int?>(value: t.id, child: Text(t.shortName)),
                        ],
                        onChanged: (v) => _save(current, v),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
