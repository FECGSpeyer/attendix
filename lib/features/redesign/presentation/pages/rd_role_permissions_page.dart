import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart' show currentAuthUserIdProvider;
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/role_permission/tenant_role_permission.dart';
import '../../../../data/repositories/role_permission_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../data/rd_manage_logic.dart' show RdManageEntry;
import 'rd_general_settings_page.dart' show RdTenantSettings, RdTenantSettingsBlock;
import '../widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../widgets/manage/rd_settings_sheets.dart' show RdListNote;
import '../widgets/rd_widgets.dart';
import '../widgets/rd_split_view.dart' show RdManageBackLink;
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: Verwaltung › Rollen und Rechte as a settings page of the Beta
/// (replaces `/settings/role-permissions` while the Beta is on). Same
/// rights as the old page, but each switch saves right away (no
/// "Speichern", no leave warning) and jumps back when saving fails.
/// Stimmführer are no own sections: Helfer and Mitglied also set their
/// Stimmführer roles (thread "Einstellungen verständlich benennen").
/// "Dateiablage für alle" only for Admins, like the old page.
class RdRolePermissionsPage extends ConsumerStatefulWidget {
  const RdRolePermissionsPage({super.key});

  @override
  ConsumerState<RdRolePermissionsPage> createState() => _RdRolePermissionsPageState();
}

/// Roles whose rights are stored, in the order of the old page (Ionic).
/// The page shows two of them: Stimmführer are a Zusatz of Helfer and
/// Mitglied, their rows follow the base role ([rdLeaderVariant]).
List<(Role, String)> rdConfigurableRoles(AppLocalizations l10n) => [
  (Role.helper, l10n.rolesHelper),
  (Role.voiceLeaderHelper, l10n.rolesVoiceLeaderHelper),
  (Role.voiceLeader, l10n.rolesVoiceLeader),
  (Role.player, l10n.rolesMember),
  (Role.viewer, l10n.rolesViewer),
  (Role.parent, l10n.rolesParents),
];

/// The Stimmführer role that follows [base] (Helfer → Stimmführer-Helfer,
/// Mitglied → Stimmführer); null for other roles.
Role? rdLeaderVariant(Role base) => switch (base) {
  Role.helper => Role.voiceLeaderHelper,
  Role.player => Role.voiceLeader,
  _ => null,
};

class _RdRolePermissionsPageState extends ConsumerState<RdRolePermissionsPage> {
  /// What the switches show (may hold changes still being saved).
  final Map<Role, TenantRolePermission> _permissions = {};

  /// What is confirmed saved; a failed save jumps back to this. One map per
  /// loaded group: queued saves keep confirming into theirs, also after the
  /// page was left or switched to another group.
  Map<Role, TenantRolePermission> _saved = {};
  bool _filesShared = false;
  bool _savedFilesShared = false;
  bool _initialized = false;

  /// Switch changes not confirmed yet, oldest first, each as edits per
  /// role. The page shows [_saved] with these applied, so a failed save
  /// takes back only its own switch, never a newer one of the same role.
  final List<Map<Role, _PermEdit>> _edits = [];

  /// Counts the changes of the Dateiablage: a failed save only jumps back
  /// while no newer change follows.
  int _filesChanges = 0;

  /// Saves still queued or running; while there are none, a freshly loaded
  /// state of the group replaces what the page shows.
  int _pending = 0;
  List<TenantRolePermission>? _loadedFrom;

  /// The repository (bound to one group and account) the shown data was
  /// loaded with. Every save goes through it, also after a group switch.
  RolePermissionRepository? _repo;

  /// Raised on a group or account switch: saves queued before it no longer
  /// touch what the page shows.
  int _generation = 0;

  /// Saves run one after another, so the last switch always wins.
  Future<void> _queue = Future.value();

  void _initFrom(List<TenantRolePermission> permissions, RolePermissionRepository repo) {
    _initialized = true;
    _repo = repo;
    _loadedFrom = permissions;
    _edits.clear();
    _saved = {};
    for (final (role, _) in rdConfigurableRoles(context.l10n)) {
      final p = permissions.where((p) => p.role == role.value).firstOrNull;
      if (p != null) _permissions[role] = _saved[role] = p;
    }
    final tenant = ref.read(currentTenantProvider);
    _filesShared = _savedFilesShared = tenant?.id == repo.currentTenantId && (tenant?.filesShared ?? false);
  }

  void _reset() {
    _initialized = false;
    _repo = null;
    _loadedFrom = null;
    _generation++;
    _permissions.clear();
    _saved = {};
    _edits.clear();
  }

  void _failed() {
    if (mounted) ToastHelper.showError(context, context.l10n.rolePermSaveFailed);
  }

  /// Queues [save] for the group and account the page shows. [done] gets
  /// the result unless the page was left or switched to another group;
  /// after an account switch nothing more is written (the shared client
  /// already carries the other account's session): [save] checks
  /// `sameAccount` before each of its writes.
  void _enqueue(Future<bool> Function(bool Function() sameAccount) save, void Function(bool ok) done) {
    final container = ProviderScope.containerOf(context, listen: false);
    final account = container.read(currentAuthUserIdProvider);
    bool sameAccount() => container.read(currentAuthUserIdProvider) == account;
    final generation = _generation;
    _pending++;
    _queue = _queue.then((_) async {
      try {
        if (!sameAccount()) return;
        bool ok;
        try {
          ok = await save(sameAccount);
        } catch (_) {
          ok = false; // never break the queue
        }
        if (!mounted || generation != _generation) return;
        done(ok);
      } finally {
        _pending--;
        if (mounted) setState(() {});
      }
    });
  }

  /// Shows the confirmed rights with the changes still waiting.
  void _showEdits() {
    for (final MapEntry(key: role, value: saved) in _saved.entries) {
      var shown = saved;
      for (final edit in _edits) {
        shown = edit[role]?.call(shown) ?? shown;
      }
      _permissions[role] = shown;
    }
  }

  /// Changes the rights of one or more roles (a base role and its
  /// Stimmführer role). The rows are built when the save runs, on what is
  /// confirmed then: a failed earlier save never rides along. One row per
  /// write, each confirmed as soon as it landed (the page shows a partly
  /// saved change as such, e.g. "Bei Stimmführern … anders").
  void _setPermissions(Map<Role, _PermEdit> edit) {
    final repo = _repo;
    if (repo == null) return;
    final saved = _saved;
    final change = {
      for (final e in edit.entries)
        if (saved[e.key] != null) e.key: e.value,
    };
    if (change.isEmpty) return;
    _edits.add(change);
    setState(_showEdits);
    final notifier = ref.read(rolePermissionNotifierProvider.notifier);
    _enqueue((sameAccount) async {
      for (final MapEntry(key: role, value: apply) in change.entries) {
        if (!sameAccount()) return false;
        final row = apply(saved[role]!);
        if (!await notifier.save([row], repo: repo)) return false;
        saved[role] = row;
      }
      return true;
    }, (ok) {
      _edits.remove(change);
      setState(_showEdits);
      if (!ok) _failed();
    });
  }

  void _setFilesShared(bool value) {
    final repo = _repo;
    if (repo == null || value == _filesShared) return;
    final change = ++_filesChanges;
    setState(() => _filesShared = value);
    final notifier = ref.read(rolePermissionNotifierProvider.notifier);
    _enqueue((_) => notifier.save(const [], filesShared: value, repo: repo), (ok) {
      if (ok) {
        _savedFilesShared = value;
        return;
      }
      if (_filesChanges == change) setState(() => _filesShared = _savedFilesShared);
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

  /// A switch of [base] that also sets its Stimmführer role ([rdLeaderVariant]).
  /// Shows the base role's value; when the Stimmführer still differ (set
  /// apart on the old page), the hint says so and the next change aligns them.
  Widget _merged(
    Role base,
    String title,
    String hint,
    bool Function(TenantRolePermission p) get,
    TenantRolePermission Function(TenantRolePermission p, bool v) set,
  ) {
    final leader = rdLeaderVariant(base);
    final value = get(_permissions[base]!);
    final other = leader == null ? null : _permissions[leader];
    final differs = other != null && get(other) != value;
    return _switch(
      title,
      differs ? '$hint\n${context.l10n.rdSettingsPermLeaderDiffers}' : hint,
      value,
      (v) => _setPermissions({
        base: (p) => set(p, v),
        if (other != null) leader!: (p) => set(p, v),
      }),
    );
  }

  /// Helfer (also for Helfer who are Stimmführer). "Alle Register" sets
  /// both roles; while it is on, Stimmführer-Helfer can be limited to their
  /// own Stimme. Notizen and Checkliste only apply to Helfer: Stimmführer-
  /// Helfer always see them (Ionic `role === HELPER`).
  List<Widget> _helperSection() {
    final l10n = context.l10n;
    final helper = _permissions[Role.helper]!;
    final leader = _permissions[Role.voiceLeaderHelper];
    final allGroups = helper.attendanceAllGroups;
    final leaderOwnOnly = leader != null && allGroups && !leader.attendanceAllGroups;
    final allDiffers = leader != null && !allGroups && leader.attendanceAllGroups;
    return [
      RdGroupLabel(l10n.rdSettingsPermHelperLabel),
      RdGroupedList(
        children: [
          _switch(
            l10n.rdSettingsPermAllGroups,
            allDiffers
                ? '${l10n.rdSettingsPermAllGroupsHint}\n${l10n.rdSettingsPermLeaderDiffers}'
                : l10n.rdSettingsPermAllGroupsHint,
            allGroups,
            (v) => _setPermissions({
              Role.helper: (p) => p.copyWith(attendanceAllGroups: v),
              // Turned off: Stimmführer-Helfer neither; turned on: all Register.
              if (leader != null) Role.voiceLeaderHelper: (p) => p.copyWith(attendanceAllGroups: v),
            }),
          ),
          if (allGroups && leader != null)
            _switch(
              l10n.rdSettingsPermLeaderOwnOnly,
              l10n.rdSettingsPermLeaderOwnOnlyHint,
              leaderOwnOnly,
              (v) => _setPermissions({Role.voiceLeaderHelper: (p) => p.copyWith(attendanceAllGroups: !v)}),
            ),
          _merged(
            Role.helper,
            l10n.rdSettingsPermCreate,
            l10n.rdSettingsPermCreateHint,
            (p) => p.attendanceCreate,
            (p, v) => p.copyWith(attendanceCreate: v),
          ),
          _switch(
            l10n.rdSettingsPermNotes,
            l10n.rdSettingsPermNotesHint,
            helper.playerNotesView,
            (v) => _setPermissions({Role.helper: (p) => p.copyWith(playerNotesView: v)}),
          ),
          _switch(
            l10n.rdSettingsPermChecklist,
            l10n.rdSettingsPermChecklistHint,
            helper.checklistView,
            (v) => _setPermissions({Role.helper: (p) => p.copyWith(checklistView: v)}),
          ),
          _merged(
            Role.helper,
            l10n.rdSettingsPermAbsence,
            l10n.rdSettingsPermAbsenceHint,
            (p) => p.playerPlannedAbsence,
            (p, v) => p.copyWith(playerPlannedAbsence: v),
          ),
        ],
      ),
      RdListNote(l10n.rdSettingsPermHelperNote),
      const SizedBox(height: 22),
    ];
  }

  /// Mitglied (also for Mitglieder who are Stimmführer). Selbst pausieren is
  /// read from the Mitglied role for everyone with an own profile
  /// ([canSelfPauseProvider]), so it only sets that role.
  List<Widget> _memberSection() {
    final l10n = context.l10n;
    final player = _permissions[Role.player]!;
    return [
      RdGroupLabel(l10n.rdSettingsPermMemberLabel),
      RdGroupedList(
        children: [
          _switch(
            l10n.rdSettingsPermPause,
            l10n.rdSettingsPermPauseHint,
            player.playerSelfPause,
            (v) => _setPermissions({Role.player: (p) => p.copyWith(playerSelfPause: v)}),
          ),
          _merged(
            Role.player,
            l10n.rdSettingsPermAbsence,
            l10n.rdSettingsPermAbsenceHint,
            (p) => p.playerPlannedAbsence,
            (p, v) => p.copyWith(playerPlannedAbsence: v),
          ),
        ],
      ),
      RdListNote(l10n.rdSettingsPermMemberNote),
      const SizedBox(height: 22),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final async = ref.watch(rolePermissionsProvider);
    final isAdmin = ref.watch(effectiveRoleProvider).isAdmin;
    // A group or account switch gives a new repository: start over with the
    // data of the new group instead of keeping the old switches.
    final repo = ref.watch(rolePermissionRepositoryWithTenantProvider);
    if (_initialized && !identical(repo, _repo)) _reset();
    // Only fully loaded data of this group (no old value during a reload).
    // A newer load (e.g. after a save) is taken over once no save waits.
    if (repo.hasTenantId &&
        permissionsConfirmed(async) &&
        (!_initialized || (_pending == 0 && !identical(async.requireValue, _loadedFrom)))) {
      _permissions.clear();
      _initFrom(async.requireValue, repo);
    }

    final header = <Widget>[
      RdManageBackLink(
        label: rdBackLabel(context, fallback: l10n.redesignMeAdmin),
        onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.manage),
      ),
      const SizedBox(height: 4),
      Semantics(header: true, child: Text(rdManageTitle(l10n, RdManageEntry.rolesPermissions), style: RdType.largeTitle(p))),
      const SizedBox(height: 6),
      Text(l10n.redesignRolePermIntro, style: RdType.meta(p, size: 15)),
      const SizedBox(height: 20),
      // Mitglieder first: what they see (from the old "Allgemein"), then what
      // they may do; Helfer after them.
      RdTenantSettingsBlock(sections: const [RdTenantSettings.visibility], label: l10n.rdAdminVisibility),
      const SizedBox(height: 22),
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
        if (_permissions[Role.player] != null) ..._memberSection(),
        if (_permissions[Role.helper] != null) ..._helperSection(),
        RdGroupLabel(l10n.rolePermFiles),
        RdGroupedList(
          children: [
            _switch(
              l10n.rdSettingsFilesForAll,
              l10n.rdSettingsFilesForAllHint,
              _filesShared,
              isAdmin ? _setFilesShared : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// One switch change of a role's rights.
typedef _PermEdit = TenantRolePermission Function(TenantRolePermission p);
