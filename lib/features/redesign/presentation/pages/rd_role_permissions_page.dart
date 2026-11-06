import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/role_permission/tenant_role_permission.dart';
import '../../../../l10n/l10n.dart';
import '../../data/rd_manage_logic.dart' show RdManageEntry;
import '../widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: Verwaltung › Rollen und Rechte as a settings page of the Beta
/// (replaces `/settings/role-permissions` while the Beta is on). Same
/// switches and rights as the old page, but each switch saves right away
/// (no "Speichern", no leave warning) and jumps back when saving fails.
/// "Dateiablage für alle Mitglieder" only for Admins, like the old page.
class RdRolePermissionsPage extends ConsumerStatefulWidget {
  const RdRolePermissionsPage({super.key});

  @override
  ConsumerState<RdRolePermissionsPage> createState() => _RdRolePermissionsPageState();
}

/// Roles with switches, in the order of the old page (Ionic).
List<(Role, String)> rdConfigurableRoles(AppLocalizations l10n) => [
  (Role.helper, l10n.rolesHelper),
  (Role.voiceLeaderHelper, l10n.rolesVoiceLeaderHelper),
  (Role.voiceLeader, l10n.rolesVoiceLeader),
  (Role.player, l10n.rolesMember),
  (Role.viewer, l10n.rolesViewer),
  (Role.parent, l10n.rolesParents),
];

bool _helperSwitches(Role role) => role == Role.helper || role == Role.voiceLeaderHelper;
bool _selfPauseSwitch(Role role) => role == Role.player;
bool _absenceSwitch(Role role) => role == Role.player || role == Role.helper || role == Role.voiceLeaderHelper;
bool _hasSwitches(Role role) => _helperSwitches(role) || _selfPauseSwitch(role) || _absenceSwitch(role);

class _RdRolePermissionsPageState extends ConsumerState<RdRolePermissionsPage> {
  final Map<Role, TenantRolePermission> _permissions = {};
  bool _filesShared = false;
  bool _initialized = false;

  /// Saves run one after another, so the last switch always wins.
  Future<void> _queue = Future.value();

  void _initFrom(List<TenantRolePermission> permissions) {
    if (_initialized) return;
    _initialized = true;
    for (final (role, _) in rdConfigurableRoles(context.l10n)) {
      final p = permissions.where((p) => p.role == role.value).firstOrNull;
      if (p != null) _permissions[role] = p;
    }
    _filesShared = ref.read(currentTenantProvider)?.filesShared ?? false;
  }

  void _failed() {
    if (mounted) ToastHelper.showError(context, context.l10n.rolePermSaveFailed);
  }

  void _setPermission(Role role, TenantRolePermission next) {
    final before = _permissions[role];
    if (before == null || before == next) return;
    setState(() => _permissions[role] = next);
    // Bound now: the save still belongs to this group after a switch.
    final notifier = ref.read(rolePermissionNotifierProvider.notifier);
    _queue = _queue.then((_) async {
      if (await notifier.save([next])) return;
      if (!mounted) return;
      setState(() {
        if (_permissions[role] == next) _permissions[role] = before;
      });
      _failed();
    });
  }

  void _setFilesShared(bool value) {
    if (value == _filesShared) return;
    setState(() => _filesShared = value);
    final notifier = ref.read(rolePermissionNotifierProvider.notifier);
    _queue = _queue.then((_) async {
      if (await notifier.save(const [], filesShared: value)) return;
      if (!mounted) return;
      setState(() {
        if (_filesShared == value) _filesShared = !value;
      });
      _failed();
    });
  }

  Widget _switch(String title, String helper, bool value, ValueChanged<bool>? onChanged) {
    final p = context.rd;
    return RdListRow(
      title: title,
      subtitle: helper,
      showChevron: false,
      trailing: Switch.adaptive(value: value, activeTrackColor: p.primary, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged(!value),
    );
  }

  List<Widget> _roleSection(Role role, String label) {
    final l10n = context.l10n;
    final p = _permissions[role]!;
    void set(TenantRolePermission Function(TenantRolePermission) change) => _setPermission(role, change(_permissions[role]!));
    return [
      RdGroupLabel(label),
      RdGroupedList(
        children: [
          if (_helperSwitches(role)) ...[
            _switch(
              l10n.rolePermAllGroups,
              l10n.rolePermAllGroupsHelper,
              p.attendanceAllGroups,
              (v) => set((p) => p.copyWith(attendanceAllGroups: v)),
            ),
            _switch(
              l10n.rolePermCreateAttendance,
              l10n.rolePermCreateHelper,
              p.attendanceCreate,
              (v) => set((p) => p.copyWith(attendanceCreate: v)),
            ),
            _switch(
              l10n.rolePermSeeNotes,
              l10n.rolePermNotesHelper,
              p.playerNotesView,
              (v) => set((p) => p.copyWith(playerNotesView: v)),
            ),
            _switch(
              l10n.rolePermSeeChecklist,
              l10n.rolePermChecklistHelper,
              p.checklistView,
              (v) => set((p) => p.copyWith(checklistView: v)),
            ),
          ],
          if (_selfPauseSwitch(role))
            _switch(
              l10n.rolePermAllowPause,
              l10n.rolePermPauseHelper,
              p.playerSelfPause,
              (v) => set((p) => p.copyWith(playerSelfPause: v)),
            ),
          if (_absenceSwitch(role))
            _switch(
              l10n.rolePermEnterAbsences,
              l10n.rolePermAbsencesHelper,
              p.playerPlannedAbsence,
              (v) => set((p) => p.copyWith(playerPlannedAbsence: v)),
            ),
        ],
      ),
      const SizedBox(height: 22),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final async = ref.watch(rolePermissionsProvider);
    final isAdmin = ref.watch(effectiveRoleProvider).isAdmin;
    final permissions = async.valueOrNull;
    if (permissions != null) _initFrom(permissions);

    final header = <Widget>[
      RdBackLink(
        label: l10n.redesignMeAdmin,
        onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.manage),
      ),
      const SizedBox(height: 4),
      Semantics(header: true, child: Text(rdManageTitle(l10n, RdManageEntry.rolesPermissions), style: RdType.largeTitle(p))),
      const SizedBox(height: 6),
      Text(l10n.redesignRolePermIntro, style: RdType.meta(p, size: 15)),
      const SizedBox(height: 20),
    ];

    if (!_initialized) {
      return RdPage(
        onRefresh: () async => ref.invalidate(rolePermissionsProvider),
        children: [
          ...header,
          async.hasError
              ? RdInfoCard(
                text: l10n.redesignTodayLoadFailed,
                icon: Icons.cloud_off_outlined,
                action: RdOutlineButton(
                  label: l10n.redesignCommonRetry,
                  onPressed: () => ref.invalidate(rolePermissionsProvider),
                ),
              )
              : RdInfoCard(text: l10n.redesignTodayLoading, loading: true),
        ],
      );
    }

    return RdPage(
      children: [
        ...header,
        RdGroupLabel(l10n.rolePermFiles),
        RdGroupedList(
          children: [
            _switch(l10n.rolePermFilesForAll, l10n.rolePermFilesHelper, _filesShared, isAdmin ? _setFilesShared : null),
          ],
        ),
        const SizedBox(height: 22),
        for (final (role, label) in rdConfigurableRoles(l10n))
          if (_permissions[role] != null && _hasSwitches(role)) ..._roleSection(role, label),
      ],
    );
  }
}
