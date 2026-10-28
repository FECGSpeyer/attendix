import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/role_permission/tenant_role_permission.dart';

/// Konfigurierbare Rollen (Reihenfolge wie Ionic)
const _configurableRoles = <(Role, String)>[
  (Role.helper, 'Helfer'),
  (Role.voiceLeaderHelper, 'Stimmführer-Helfer'),
  (Role.voiceLeader, 'Stimmführer'),
  (Role.player, 'Mitglied'),
  (Role.viewer, 'Beobachter'),
  (Role.parent, 'Eltern'),
];

bool _showHelperToggles(Role role) => role == Role.helper || role == Role.voiceLeaderHelper;
bool _showSelfPauseToggle(Role role) => role == Role.player;
bool _showPlannedAbsenceToggle(Role role) =>
    role == Role.player || role == Role.helper || role == Role.voiceLeaderHelper;
bool _hasAnyToggle(Role role) =>
    _showHelperToggles(role) || _showSelfPauseToggle(role) || _showPlannedAbsenceToggle(role);

/// Rollen & Berechtigungen (Ionic: settings/role-permissions)
class RolePermissionsPage extends ConsumerStatefulWidget {
  const RolePermissionsPage({super.key});

  @override
  ConsumerState<RolePermissionsPage> createState() => _RolePermissionsPageState();
}

class _RolePermissionsPageState extends ConsumerState<RolePermissionsPage> {
  final Map<Role, TenantRolePermission> _permissions = {};
  Map<Role, TenantRolePermission> _original = {};
  bool _filesShared = false;
  bool _originalFilesShared = false;
  bool _initialized = false;

  bool get _hasUnsavedChanges {
    if (_filesShared != _originalFilesShared) return true;
    for (final entry in _permissions.entries) {
      if (_original[entry.key] != entry.value) return true;
    }
    return false;
  }

  void _initFrom(List<TenantRolePermission> permissions) {
    if (_initialized) return;
    _initialized = true;
    for (final (role, _) in _configurableRoles) {
      final p = permissions.where((p) => p.role == role.value).firstOrNull;
      if (p != null) _permissions[role] = p;
    }
    _original = Map.of(_permissions);
    _filesShared = ref.read(currentTenantProvider)?.filesShared ?? false;
    _originalFilesShared = _filesShared;
  }

  Future<bool> _save() async {
    final canEditFilesShared = ref.read(effectiveRoleProvider).isAdmin;
    final changed = _permissions.entries
        .where((e) => _original[e.key] != e.value)
        .map((e) => e.value)
        .toList();
    final ok = await ref.read(rolePermissionNotifierProvider.notifier).save(
          changed,
          filesShared: canEditFilesShared && _filesShared != _originalFilesShared ? _filesShared : null,
        );
    if (!mounted) return ok;
    if (ok) {
      setState(() {
        _original = Map.of(_permissions);
        _originalFilesShared = _filesShared;
      });
      ToastHelper.showSuccess(context, 'Rollenberechtigungen gespeichert');
    } else {
      ToastHelper.showError(context, 'Fehler beim Speichern der Rollenberechtigungen');
    }
    return ok;
  }

  Future<void> _confirmLeave() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ungespeicherte Änderungen'),
        content: const Text(
            'Du hast ungespeicherte Änderungen. Möchtest du sie speichern bevor du die Seite verlässt?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Verwerfen', style: TextStyle(color: AppColors.danger)),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Speichern')),
        ],
      ),
    );
    if (!mounted || result == null) return;
    if (result == 'save' && !await _save()) return;
    if (result == 'discard') {
      setState(() {
        _permissions
          ..clear()
          ..addAll(_original);
        _filesShared = _originalFilesShared;
      });
    }
    if (mounted) context.pop();
  }

  void _update(Role role, TenantRolePermission Function(TenantRolePermission) change) {
    final p = _permissions[role];
    if (p == null) return;
    setState(() => _permissions[role] = change(p));
  }

  @override
  Widget build(BuildContext context) {
    final permissionsAsync = ref.watch(rolePermissionsProvider);
    final isAdmin = ref.watch(effectiveRoleProvider).isAdmin;
    final saving = ref.watch(rolePermissionNotifierProvider).isLoading;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Rollen & Berechtigungen')),
        floatingActionButton: FloatingActionButton(
          onPressed: saving ? null : _save,
          child: saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined),
        ),
        body: permissionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Fehler beim Laden der Rollenberechtigungen\n$e', textAlign: TextAlign.center)),
          data: (permissions) {
            _initFrom(permissions);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, 96),
              children: [
                _sectionHeader('Dateiablage'),
                Card(
                  child: SwitchListTile(
                    title: const Text('Dateiablage für alle Mitglieder'),
                    subtitle: const Text(
                      'Admins, Verantwortliche und Helfer sehen die Dateiablage immer. Wenn aktiviert, '
                      'können auch alle anderen Mitglieder außer Bewerber sie lesen. Hochladen bleibt '
                      'Admins und Verantwortlichen vorbehalten.',
                    ),
                    value: _filesShared,
                    onChanged: isAdmin ? (v) => setState(() => _filesShared = v) : null,
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingM),
                for (final (role, label) in _configurableRoles)
                  if (_permissions[role] != null && _hasAnyToggle(role)) _buildRoleCard(role, label),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
        ),
      );

  Widget _buildRoleCard(Role role, String label) {
    final p = _permissions[role]!;
    return Card(
      child: ExpansionTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        children: [
          if (_showHelperToggles(role)) ...[
            SwitchListTile(
              title: const Text('Alle Gruppen pflegen'),
              subtitle: const Text(
                  'Wenn deaktiviert, können Personen mit dieser Rolle nur Anwesenheiten der ihnen zugeordneten Gruppe pflegen.'),
              value: p.attendanceAllGroups,
              onChanged: (v) => _update(role, (p) => p.copyWith(attendanceAllGroups: v)),
            ),
            SwitchListTile(
              title: const Text('Anwesenheiten erstellen'),
              subtitle: const Text('Wenn deaktiviert, können Personen mit dieser Rolle keine neuen Anwesenheiten anlegen.'),
              value: p.attendanceCreate,
              onChanged: (v) => _update(role, (p) => p.copyWith(attendanceCreate: v)),
            ),
            SwitchListTile(
              title: const Text('Spielernotizen sehen'),
              subtitle: const Text(
                  'Wenn aktiviert, können Personen mit dieser Rolle die Notizen der Mitglieder in der Anwesenheitsansicht sehen.'),
              value: p.playerNotesView,
              onChanged: (v) => _update(role, (p) => p.copyWith(playerNotesView: v)),
            ),
            SwitchListTile(
              title: const Text('Checkliste sehen'),
              subtitle: const Text(
                  'Wenn aktiviert, können Personen mit dieser Rolle die Checkliste in der Anwesenheitsansicht sehen.'),
              value: p.checklistView,
              onChanged: (v) => _update(role, (p) => p.copyWith(checklistView: v)),
            ),
          ],
          if (_showSelfPauseToggle(role))
            SwitchListTile(
              title: const Text('Eigene Pausierung erlauben'),
              subtitle: const Text('Wenn aktiviert, können Spieler sich selbst pausieren und reaktivieren.'),
              value: p.playerSelfPause,
              onChanged: (v) => _update(role, (p) => p.copyWith(playerSelfPause: v)),
            ),
          if (_showPlannedAbsenceToggle(role))
            SwitchListTile(
              title: const Text('Geplante Abwesenheiten eintragen'),
              subtitle: const Text(
                  'Wenn aktiviert, können Personen mit dieser Rolle geplante Abwesenheiten für sich selbst eintragen.'),
              value: p.playerPlannedAbsence,
              onChanged: (v) => _update(role, (p) => p.copyWith(playerPlannedAbsence: v)),
            ),
        ],
      ),
    );
  }
}
