import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/organisation/organisation.dart';
import '../../../planning/presentation/widgets/plan_field_dialogs.dart';
import '../widgets/org_song_sync_section.dart'; // SETTINGS2

/// Organisation settings (Ionic `OrgSettingsPage`, route `/settings/org-settings`).
class OrgSettingsPage extends ConsumerWidget {
  const OrgSettingsPage({super.key});

  Future<void> _rename(BuildContext context, WidgetRef ref, Organisation org) async {
    final name = await showPlanTextPrompt(
      context,
      title: 'Organisation umbenennen',
      initialValue: org.name,
      hint: 'Name eingeben...',
    );
    if (name == null) return;
    if (name.trim().isEmpty) {
      if (context.mounted) ToastHelper.showWarning(context, 'Bitte gib einen gültigen Namen ein.');
      return;
    }
    final ok = await ref.read(planSettingsNotifierProvider.notifier).updateOrgName(name.trim());
    if (!context.mounted) return;
    ok ? ToastHelper.showSuccess(context, 'Organisation umbenannt') : ToastHelper.showError(context, 'Fehler beim Speichern');
  }

  Future<void> _unlink(BuildContext context, WidgetRef ref, Organisation org) async {
    final ok = await showPlanConfirm(
      context,
      title: 'Organisation von Instanz trennen?',
      message: 'Möchtest du die Organisation „${org.name}“ wirklich von der Instanz trennen?',
      confirmText: 'Trennen',
      destructive: true,
    );
    if (!ok || org.id == null) return;
    final success = await ref.read(organisationNotifierProvider.notifier).unlinkCurrentTenant(org.id!);
    if (!context.mounted) return;
    success
        ? ToastHelper.showSuccess(context, 'Die Organisation wurde erfolgreich von der Instanz getrennt.')
        : ToastHelper.showError(context, 'Fehler beim Trennen');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(effectiveRoleProvider);
    final isSuperAdmin = role == Role.admin;
    final orgAsync = ref.watch(currentOrganisationProvider);
    final tenant = ref.watch(currentTenantProvider);
    final linked = ref.watch(linkedTenantsProvider).valueOrNull ?? const [];
    final others = linked.where((t) => t.id != tenant?.id).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Organisation')),
      body: orgAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (org) {
          if (org == null) {
            return ListView(
              children: [
                _Section(children: [
                  ListTile(
                    title: const Text('Keine Organisation verknüpft'),
                    subtitle: Text(isSuperAdmin
                        ? 'Erstelle eine neue Organisation oder verknüpfe diese Instanz mit einer bestehenden, um Personen organisationsweit zu verbinden und gemeinsame Pläne zu nutzen.'
                        : 'Diese Instanz ist keiner Organisation zugewiesen. Nur Administratoren können Organisationen verwalten.'),
                  ),
                  if (isSuperAdmin)
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                      title: const Text('Organisation erstellen / verknüpfen',
                          style: TextStyle(color: AppColors.primary)),
                      onTap: () => context.push('/settings/general'),
                    ),
                ]),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _Section(title: 'Organisation', children: [
                ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: Text(org.name),
                  subtitle: isSuperAdmin ? const Text('Tippen zum Umbenennen') : null,
                  trailing: isSuperAdmin ? const Icon(Icons.chevron_right) : null,
                  onTap: isSuperAdmin ? () => _rename(context, ref, org) : null,
                ),
                if (isSuperAdmin)
                  ListTile(
                    leading: const Icon(Icons.link_off, color: AppColors.danger),
                    title: const Text('Instanz trennen', style: TextStyle(color: AppColors.danger)),
                    onTap: () => _unlink(context, ref, org),
                  ),
              ]),
              _Section(title: 'Darstellung & Pläne', children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Planvorlagen & Felder'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/org-settings/planning-templates'),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Org-Pläne'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/org-plans'),
                ),
              ]),
              if (isSuperAdmin)
                _Section(title: 'Personen', children: [
                  ListTile(
                    leading: const Icon(Icons.list_alt),
                    title: const Text('Personen-Zusatzfelder'),
                    subtitle: const Text('Felder und Werte für verknüpfte Personen gemeinsam verwalten'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/org-settings/person-fields'),
                  ),
                ]),
              // SETTINGS2: Werk-Synchronisierung (Ionic: super admin + linked tenants)
              if (isSuperAdmin && others.isNotEmpty)
                OrgSongSyncSection(linkedTenants: others),
              if (others.isNotEmpty)
                _Section(title: 'Instanzen', children: [
                  ListTile(
                    leading: const Icon(Icons.layers_outlined),
                    title: Text(tenant?.shortName ?? ''),
                    subtitle: const Text('Diese Instanz'),
                  ),
                  for (final t in others)
                    ListTile(
                      leading: const Icon(Icons.layers_outlined, color: AppColors.medium),
                      title: Text(t.shortName),
                      subtitle: Text(t.longName),
                    ),
                ]),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(title!.toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.medium)),
          ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: children),
        ),
      ],
    );
  }
}
