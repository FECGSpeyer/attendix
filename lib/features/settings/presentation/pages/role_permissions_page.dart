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
import '../../../../l10n/l10n.dart';
import '../widgets/ion_condense.dart'; // UX_SETTINGS (WAVE 8)
import '../widgets/settings_list.dart'; // UX_SETTINGS (WAVE 8)
import '../../../../core/utils/error_message.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonTranslucentAppBar, IonContentTopInset; // IOS_R6
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Konfigurierbare Rollen (Reihenfolge wie Ionic)
List<(Role, String)> _configurableRoles(AppLocalizations l10n) => [
      (Role.helper, l10n.rolesHelper),
      (Role.voiceLeaderHelper, l10n.rolesVoiceLeaderHelper),
      (Role.voiceLeader, l10n.rolesVoiceLeader),
      (Role.player, l10n.rolesMember),
      (Role.viewer, l10n.rolesViewer),
      (Role.parent, l10n.rolesParents),
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
    for (final (role, _) in _configurableRoles(context.l10n)) {
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
      ToastHelper.showSuccess(context, context.l10n.rolePermSaved);
    } else {
      ToastHelper.showError(context, context.l10n.rolePermSaveFailed);
    }
    return ok;
  }

  Future<void> _confirmLeave() async {
    final result = await showAppDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.rolePermUnsaved),
        content: Text(
            context.l10n.rolePermUnsavedMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(context.l10n.rolePermDiscard, style: const TextStyle(color: AppColors.danger)),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, 'save'), child: Text(context.l10n.commonSave)),
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
      // UX_SETTINGS (WAVE 8): role-permissions.page.html — arrow-back,
      // condense title, files toggle in an inset list, one accordion per
      // role (header item on the page background, toggles in an inset list).
      child: IonCondense(builder: (context, collapsed) => Scaffold(
        // IOS_R6: Ionic `ion-content fullscreen` under the translucent header
        extendBodyBehindAppBar: ionIsIos(context),
        // IOS_R6: `ion-header translucent` (blur once condensed)
        appBar: IonTranslucentAppBar(condensed: collapsed, child: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, semanticLabel: context.l10n.commonBack),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: IonCondenseTitle(context.l10n.rolePermTitle, collapsed: collapsed),
        )),
        floatingActionButton: FloatingActionButton(
          onPressed: saving ? null : _save,
          child: saving
              ? const SizedBox(width: 20, height: 20, child: AppSpinner(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined),
        ),
        body: permissionsAsync.when(
          loading: () => const Center(child: AppSpinner()),
          error: (e, _) => Center(child: Text(context.l10n.rolePermFlutterLoadFailed(friendlyErrorMessage(e)), textAlign: TextAlign.center)),
          data: (permissions) {
            _initFrom(permissions);
            final ios = ionIsIos(context);
            return ListView(
              padding: EdgeInsets.fromLTRB(
                  ionListMargin(context), ios ? 0 : AppDimensions.paddingM, ionListMargin(context), 96),
              children: [
                const IonContentTopInset(), // IOS_R6
                IonLargeTitle(context.l10n.rolePermTitle, padding: const EdgeInsets.only(bottom: 4)),
                if (ios) const SizedBox(height: 16),
                if (ios)
                  SettingsListSection(
                    title: context.l10n.rolePermFiles,
                    icons: false,
                    children: [
                      IonToggleItem(
                        title: context.l10n.rolePermFilesForAll,
                        helper: context.l10n.rolePermFilesHelper,
                        value: _filesShared,
                        onChanged: isAdmin ? (v) => setState(() => _filesShared = v) : null,
                      ),
                    ],
                  )
                else ...[
                  _sectionHeader(context.l10n.rolePermFiles),
                  Card(
                    child: IonToggleItem(
                      title: context.l10n.rolePermFilesForAll,
                      helper: context.l10n.rolePermFilesHelper,
                      value: _filesShared,
                      onChanged: isAdmin ? (v) => setState(() => _filesShared = v) : null,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                ],
                for (final (role, label) in _configurableRoles(context.l10n))
                  if (_permissions[role] != null && _hasAnyToggle(role)) _buildRoleCard(role, label),
              ],
            );
          },
        ),
      )),
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
    final toggles = <Widget>[
          if (_showHelperToggles(role)) ...[
            IonToggleItem(
              title: context.l10n.rolePermAllGroups,
              helper: context.l10n.rolePermAllGroupsHelper,
              value: p.attendanceAllGroups,
              onChanged: (v) => _update(role, (p) => p.copyWith(attendanceAllGroups: v)),
            ),
            IonToggleItem(
              title: context.l10n.rolePermCreateAttendance,
              helper: context.l10n.rolePermCreateHelper,
              value: p.attendanceCreate,
              onChanged: (v) => _update(role, (p) => p.copyWith(attendanceCreate: v)),
            ),
            IonToggleItem(
              title: context.l10n.rolePermSeeNotes,
              helper: context.l10n.rolePermNotesHelper,
              value: p.playerNotesView,
              onChanged: (v) => _update(role, (p) => p.copyWith(playerNotesView: v)),
            ),
            IonToggleItem(
              title: context.l10n.rolePermSeeChecklist,
              helper: context.l10n.rolePermChecklistHelper,
              value: p.checklistView,
              onChanged: (v) => _update(role, (p) => p.copyWith(checklistView: v)),
            ),
          ],
          if (_showSelfPauseToggle(role))
            IonToggleItem(
              title: context.l10n.rolePermAllowPause,
              helper: context.l10n.rolePermPauseHelper,
              value: p.playerSelfPause,
              onChanged: (v) => _update(role, (p) => p.copyWith(playerSelfPause: v)),
            ),
          if (_showPlannedAbsenceToggle(role))
            IonToggleItem(
              title: context.l10n.rolePermEnterAbsences,
              helper: context.l10n.rolePermAbsencesHelper,
              value: p.playerPlannedAbsence,
              onChanged: (v) => _update(role, (p) => p.copyWith(playerPlannedAbsence: v)),
            ),
    ];
    if (ionIsIos(context)) {
      // ion-accordion: header ion-item color="light" (page background),
      // content = inset list with the toggles.
      return ExpansionTile(
        tilePadding: const EdgeInsets.only(right: 2),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: IonIos.text(context).withValues(alpha: 0.4),
        collapsedIconColor: IonIos.text(context).withValues(alpha: 0.4),
        title: Text(label, style: TextStyle(fontSize: 16, color: IonIos.text(context))),
        childrenPadding: const EdgeInsets.only(top: 8, bottom: 16),
        children: [IonInsetGroup(children: toggles)],
      );
    }
    return Card(
      child: ExpansionTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        children: toggles,
      ),
    );
  }
}
