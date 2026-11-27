import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart' show currentAuthUserIdProvider;
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/admin_providers.dart' show tenantUsersProvider;
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/parent_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/viewer_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/role_permission/tenant_role_permission.dart';
import '../../../../data/repositories/role_permission_repository.dart';
import '../../../../data/repositories/user_registration_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../data/account_provisioning_actions.dart' show playersOfCurrentTenant;
import '../../data/rd_manage_logic.dart' show RdManageEntry, rdManageVisible;
import '../../../../core/redesign/rd_roles_logic.dart';
import 'rd_general_settings_page.dart' show RdTenantSettings, RdTenantSettingsBlock;
import '../../../people/presentation/pages/rd_person_edit_page.dart' show rdBaseRole;
import '../../../../core/redesign/rd_words.dart';
import '../widgets/manage/rd_manage_entries.dart' show rdManageAccessProvider, rdManageTitle;
import '../widgets/manage/rd_manage_list.dart' show rdLoadedValue;
import '../widgets/manage/rd_settings_sheets.dart' show RdListNote;
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../../shared/widgets/redesign/rd_split_view.dart' show RdManageBackLink, RdSplitScope, rdManageSplitOpen;
import '../../../today/presentation/widgets/rd_today_common.dart' show RdInfoCard;

part 'rd_role_permissions_matrix.dart';

/// Verwaltung › Rollen und Rechte: lists all roles and opens per-role
/// detail pages ([view]) showing fixed capabilities, editable switches, and
/// assigned members. Each switch saves immediately and reverts on failure.
/// Stimmführer are an add-on of Helfer and Mitglied, so toggles on those base
/// roles update their Stimmführer counterparts as well.
class RdRolePermissionsPage extends ConsumerStatefulWidget {
  const RdRolePermissionsPage({super.key, this.view = RdRoleView.list});

  /// The list of roles or the page of one role.
  final RdRoleView view;

  @override
  ConsumerState<RdRolePermissionsPage> createState() => _RdRolePermissionsPageState();
}

/// The accounts of the open group with their role, null until loaded (and
/// after a group or account switch until the new list is there).
final rdRoleAccountsProvider = Provider.autoDispose(
  (ref) => rdLoadedValue(ref.watch(tenantUsersProvider)),
);

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

/// The confirmed rights of one group, shared by the list and the pages of
/// its roles: a role is written by more than one page (a Stimmführer-Helfer
/// by Helfer and Stimmführer), each write is a whole row. So the saves of
/// all pages run in one queue and build their rows on one confirmed state.
class _RdRoleSaves {
  Map<Role, TenantRolePermission> saved = {};
  List<TenantRolePermission>? loadedFrom;
  int pending = 0;
  Future<void> queue = Future.value();
}

/// One per group and account (a switch gives a new repository).
final _rdRoleSavesProvider = Provider<_RdRoleSaves>((ref) {
  ref.watch(rolePermissionRepositoryWithTenantProvider);
  return _RdRoleSaves();
});

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

  /// The queue and confirmed state shared with the other role pages of the
  /// group: saves run one after another, so the last switch always wins.
  _RdRoleSaves _saves = _RdRoleSaves();

  /// The right column of the Verwaltung on wide screens.
  bool _inSplit = false;

  void _initFrom(List<TenantRolePermission> permissions, RolePermissionRepository repo) {
    _initialized = true;
    _repo = repo;
    _loadedFrom = permissions;
    _edits.clear();
    final saves = _saves = ref.read(_rdRoleSavesProvider);
    // While a save of another role page waits, or when this is the load
    // that page started from, its confirmed state is the newer one.
    if (saves.pending == 0 && !identical(saves.loadedFrom, permissions)) {
      saves.loadedFrom = permissions;
      saves.saved = {
        for (final (role, _) in rdConfigurableRoles(context.l10n))
          if (permissions.where((p) => p.role == role.value).firstOrNull case final p?) role: p,
      };
    }
    _saved = saves.saved;
    _permissions.addAll(_saved);
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
    final saves = _saves;
    _pending++;
    saves.pending++;
    saves.queue = saves.queue.then((_) async {
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
        saves.pending--;
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

  String _title(AppLocalizations l10n) => switch (widget.view) {
    RdRoleView.list => rdManageTitle(l10n, RdManageEntry.rolesPermissions),
    RdRoleView.admin => l10n.commonRolesAdmin,
    RdRoleView.responsible => l10n.rdRolesResponsible,
    RdRoleView.helper => l10n.commonRolesHelper,
    RdRoleView.leader => l10n.rolesVoiceLeader,
    RdRoleView.member => l10n.commonRolesMember,
  };

  /// Line below the title: how many have the role, and what the page is.
  String _intro(AppLocalizations l10n) {
    final view = widget.view;
    if (view == RdRoleView.list) return l10n.rdRolesIntro;
    final accounts = ref.watch(rdRoleAccountsProvider);
    return [
      if (accounts != null) '${l10n.rdRolesCount(rdRoleAccounts(accounts, view).length)}.',
      if (view == RdRoleView.leader) l10n.rdRolesLeaderAddOn else if (view.hasSwitches) l10n.rdRolesSavedHint,
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final view = widget.view;
    _inSplit = RdSplitScope.of(context)?.isDetail ?? false;
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

    final intro = _intro(l10n);
    final header = <Widget>[
      if (view == RdRoleView.list)
        RdManageBackLink(
          label: rdBackLabel(context, fallback: l10n.redesignMeAdmin),
          onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.manage),
        )
      else
        // Also on wide screens: the list on the left is the Verwaltung, not
        // the roles.
        RdBackLink(
          label: rdManageTitle(l10n, RdManageEntry.rolesPermissions),
          onTap: () => rdBack(context, RedesignRoutes.rolePermissions),
        ),
      const SizedBox(height: 4),
      Semantics(header: true, child: Text(_title(l10n), style: RdType.largeTitle(p))),
      if (intro.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(intro, style: RdType.meta(p, size: 15)),
      ],
      const SizedBox(height: 20),
    ];

    // Pages with switches wait for the stored rights of this group.
    if (view.hasSwitches && !_initialized) {
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
        ...switch (view) {
          RdRoleView.list => _listPage(isAdmin: isAdmin),
          RdRoleView.member => _memberPage(),
          RdRoleView.helper => _helperPage(),
          RdRoleView.leader => _leaderPage(),
          RdRoleView.admin || RdRoleView.responsible => _leadPage(),
        },
      ],
    );
  }
}

/// One switch change of a role's rights.
typedef _PermEdit = TenantRolePermission Function(TenantRolePermission p);
