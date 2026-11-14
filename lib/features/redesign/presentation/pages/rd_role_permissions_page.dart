import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart' show currentAuthUserIdProvider;
import '../../../../core/constants/enums.dart';
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
import '../../../settings/presentation/pages/settings_page.dart' show playersOfCurrentTenant;
import '../../../settings/presentation/pages/user_management_page.dart' show tenantUsersProvider;
import '../../data/rd_manage_logic.dart' show RdManageEntry, rdManageVisible;
import '../../data/rd_roles_logic.dart';
import 'rd_general_settings_page.dart' show RdTenantSettings, RdTenantSettingsBlock;
import 'rd_person_edit_page.dart' show rdBaseRole;
import '../../data/rd_words.dart';
import '../widgets/manage/rd_manage_entries.dart' show rdManageAccessProvider, rdManageTitle;
import '../widgets/manage/rd_manage_list.dart' show rdLoadedValue;
import '../widgets/manage/rd_settings_sheets.dart' show RdListNote;
import '../widgets/rd_widgets.dart';
import '../widgets/rd_split_view.dart' show RdManageBackLink, RdSplitScope, rdManageSplitOpen;
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: Verwaltung › Rollen und Rechte of the Beta (replaces
/// `/settings/role-permissions` while the Beta is on): a list of the roles,
/// each role opens its own page ([view]) with what it always may, its
/// switches and the persons who have it (thread "Rollen und Rechte neu
/// aufziehen", Stufe A). Same rights and the same stored rows as the old
/// page: each switch saves right away (no "Speichern", no leave warning)
/// and jumps back when saving fails. Stimmführer stay a Zusatz: the
/// switches of Helfer and Mitglied also set their Stimmführer roles.
/// Admins, Eltern and Beobachter open their own pages from the list.
/// "Dateiablage für alle" only for Admins, like the old page.
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

  /// A right the role always has ([never]: one it never gets): a row
  /// without a switch, so the page also says what cannot be set.
  Widget _fixed(String title, {String? hint, bool never = false}) {
    final p = context.rd;
    return RdListRow(
      leading: Icon(never ? Icons.lock_outline : Icons.check, size: 20, color: never ? p.text2 : p.present),
      title: title,
      subtitle: hint,
      showChevron: false,
    );
  }

  List<Widget> _group(String label, List<Widget> rows, {String? note}) => [
    RdGroupLabel(label),
    RdGroupedList(children: rows),
    if (note != null) RdListNote(note),
    const SizedBox(height: 22),
  ];

  /// "Personen": the accounts with this role, each opens its person.
  /// Nothing while the accounts load (the switches do not wait for them).
  List<Widget> _people({String? note, bool baseRole = false}) {
    final l10n = context.l10n;
    final accounts = ref.watch(rdRoleAccountsProvider);
    if (accounts == null) return [if (note != null) RdListNote(note)];
    final players = playersOfCurrentTenant(ref.watch(playersProvider), ref.watch(currentTenantIdProvider));
    final groups = {for (final g in ref.watch(groupsProvider).valueOrNull ?? const []) g.id: g.name};
    final people = rdRolePeople(rdRoleAccounts(accounts, widget.view), players);
    String? subtitle(RdRolePerson r) {
      final parts = [
        if (groups[r.person?.instrument] case final String name when name.isNotEmpty) name,
        // Stimmführer: the role they are a Zusatz of.
        if (baseRole) UserRegistrationRepository.roleText(rdBaseRole(r.account.roleEnum)),
      ];
      return parts.isEmpty ? null : parts.join(' · ');
    }

    return [
      RdGroupLabel(l10n.rdRolesPeople),
      if (people.isEmpty)
        RdInfoCard(text: l10n.rdRolesNoPeople, icon: Icons.person_outline)
      else
        RdGroupedList(
          children: [
            for (final r in people)
              RdListRow(
                leading: RdInitials(r.person?.initials ?? '', size: 36),
                title: r.name,
                subtitle: subtitle(r),
                showChevron: r.person?.id != null,
                onTap: r.person?.id == null ? null : () => context.push(RedesignRoutes.person(r.person!.id!)),
              ),
          ],
        ),
      if (note != null) RdListNote(note),
    ];
  }

  /// Helfer (also for Helfer who are Stimmführer). "Alle Register" sets
  /// both roles; whether Stimmführer-Helfer are limited to their own Stimme
  /// is a switch of the Stimmführer page. Notizen and Checkliste only apply
  /// to Helfer: Stimmführer-Helfer always see them (Ionic `role === HELPER`).
  List<Widget> _helperPage() {
    final l10n = context.l10n;
    final kind = ref.watch(rdGroupKindProvider);
    final helper = _permissions[Role.helper];
    final leader = _permissions[Role.voiceLeaderHelper];
    return [
      ..._group(l10n.rdRolesAlways, [_fixed(l10n.rdRolesFixedAttendance), _fixed(l10n.rdRolesFixedSignup)]),
      if (helper != null)
        ..._group(
          l10n.rdRolesAdjustable,
          [
            _switch(
              l10n.rdSettingsPermAllGroups(kind),
              leader != null && !helper.attendanceAllGroups && leader.attendanceAllGroups
                  ? '${l10n.rdSettingsPermAllGroupsHint(kind)}\n${l10n.rdSettingsPermLeaderDiffers}'
                  : l10n.rdSettingsPermAllGroupsHint(kind),
              helper.attendanceAllGroups,
              (v) => _setPermissions({
                Role.helper: (p) => p.copyWith(attendanceAllGroups: v),
                // Turned off: Stimmführer-Helfer neither; turned on: all Register.
                if (leader != null) Role.voiceLeaderHelper: (p) => p.copyWith(attendanceAllGroups: v),
              }),
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
          note: l10n.rdSettingsPermHelperNote,
        ),
      ..._group(l10n.rdRolesNever, [_fixed(l10n.rdRolesNeverLead, hint: l10n.rdRolesNeverLeadHint, never: true)]),
      ..._people(note: l10n.rdRolesAssignNote),
    ];
  }

  /// Stimmführer: a Zusatz of Mitglied or Helfer (the switch at the
  /// person). Their own switch: Stimmführer-Helfer only record their own
  /// Stimme, offered while Helfer record all of them.
  List<Widget> _leaderPage() {
    final l10n = context.l10n;
    final kind = ref.watch(rdGroupKindProvider);
    final helper = _permissions[Role.helper];
    final leader = _permissions[Role.voiceLeaderHelper];
    return [
      ..._group(l10n.rdRolesAlways, [
        _fixed(l10n.rdRolesFixedOwnRole, hint: l10n.rdRolesFixedOwnRoleHint),
        _fixed(l10n.rdRolesFixedMyVoice, hint: l10n.rdRolesFixedMyVoiceHint(kind)),
      ]),
      if (helper != null && leader != null)
        if (helper.attendanceAllGroups)
          ..._group(l10n.rdRolesAdjustable, [
            _switch(
              l10n.rdSettingsPermLeaderOwnOnly,
              l10n.rdSettingsPermLeaderOwnOnlyHint,
              !leader.attendanceAllGroups,
              (v) => _setPermissions({Role.voiceLeaderHelper: (p) => p.copyWith(attendanceAllGroups: !v)}),
            ),
          ])
        else ...[
          RdInfoCard(text: l10n.rdRolesLeaderOwnAlready(kind), icon: Icons.info_outline),
          const SizedBox(height: 22),
        ],
      ..._people(note: l10n.rdRolesLeaderNote, baseRole: true),
    ];
  }

  /// Mitglied (also for Mitglieder who are Stimmführer): what members see
  /// (group settings) and may. Selbst pausieren is read from the Mitglied
  /// role for everyone with an own profile ([canSelfPauseProvider]), so it
  /// only sets that role.
  List<Widget> _memberPage() {
    final l10n = context.l10n;
    final player = _permissions[Role.player];
    final general = ref.watch(rdGroupKindProvider) == 'general';
    return [
      ..._group(l10n.rdRolesAlways, [
        _fixed(l10n.rdRolesFixedSignup),
        if (!general) _fixed(l10n.rdRolesFixedWorks),
      ]),
      RdTenantSettingsBlock(sections: const [RdTenantSettings.visibility], label: l10n.rdRolesSees),
      const SizedBox(height: 22),
      if (player != null)
        ..._group(
          l10n.rdRolesAdjustable,
          [
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
          note: l10n.rdSettingsPermMemberNote,
        ),
      ..._group(l10n.rdRolesNever, [
        _fixed(l10n.rdRolesNeverAttendance, hint: l10n.rdRolesNeverAttendanceHint, never: true),
        _fixed(l10n.rdRolesNeverLead, hint: l10n.rdRolesNeverLeadHint, never: true),
      ]),
    ];
  }

  /// Verantwortliche and (for those who may not manage Admins) Admins:
  /// nothing to set, the page says what the role is and who has it.
  List<Widget> _leadPage() {
    final l10n = context.l10n;
    final general = ref.watch(rdGroupKindProvider) == 'general';
    if (widget.view == RdRoleView.admin) {
      return [
        ..._group(l10n.rdRolesAlways, [_fixed(l10n.rdRolesFixedAll, hint: l10n.rdRolesFixedAllHint)]),
        ..._people(),
      ];
    }
    return [
      ..._group(l10n.rdRolesAlways, [
        _fixed(l10n.rdRolesFixedManage),
        if (!general) _fixed(l10n.rdRolesFixedManageWorks),
        _fixed(l10n.rdRolesFixedSettings),
      ]),
      ..._group(l10n.rdRolesNever, [_fixed(l10n.rdRolesNeverAdmins, hint: l10n.rdRolesNeverAdminsHint, never: true)]),
      ..._people(note: l10n.rdRolesAssignNote),
    ];
  }

  /// Opens a page of the list: next to the Verwaltung on wide screens,
  /// pushed otherwise.
  void _open(String location) {
    if (_inSplit) {
      rdManageSplitOpen(context, location);
    } else {
      context.push(location);
    }
  }

  /// The right column of the Verwaltung on wide screens.
  bool _inSplit = false;

  Widget _roleRow(IconData icon, String title, String hint, {int? count, String? value, required String location}) =>
      RdListRow(
        leading: RdRowIcon(icon),
        title: title,
        subtitle: hint,
        value: value ?? (count == null ? null : '$count'),
        onTap: () => _open(location),
      );

  /// The list of roles with the number of accounts, then what applies to
  /// everyone in the group.
  List<Widget> _listPage({required bool isAdmin}) {
    final l10n = context.l10n;
    final accounts = ref.watch(rdRoleAccountsProvider);
    int? count(RdRoleView view) => accounts == null ? null : rdRoleAccounts(accounts, view).length;
    final access = ref.watch(rdManageAccessProvider);
    final leaders = count(RdRoleView.leader);
    return [
      ..._group(l10n.rdRolesLeads, [
        _roleRow(
          Icons.verified_user_outlined,
          l10n.commonRolesAdmin,
          l10n.rdAdminAdminsHint,
          count: count(RdRoleView.admin),
          // Managing Admins is for Admins (not in the demo); others read.
          location: rdManageVisible(RdManageEntry.admins, access)
              ? RedesignRoutes.admins
              : RedesignRoutes.role(RdRoleView.admin.key),
        ),
        _roleRow(
          Icons.manage_accounts_outlined,
          l10n.rdRolesResponsible,
          l10n.rdRolesResponsibleHint,
          count: count(RdRoleView.responsible),
          location: RedesignRoutes.role(RdRoleView.responsible.key),
        ),
      ]),
      ..._group(l10n.rdRolesMembersHelpers, [
        _roleRow(
          Icons.fact_check_outlined,
          l10n.commonRolesHelper,
          l10n.rdRolesHelperHint,
          count: count(RdRoleView.helper),
          location: RedesignRoutes.role(RdRoleView.helper.key),
        ),
        // Groups of type "Allgemein" have no Stimmführer, unless some are
        // left from before.
        if (!access.isGeneral || (leaders ?? 0) > 0)
          _roleRow(
            Icons.record_voice_over_outlined,
            l10n.rolesVoiceLeader,
            l10n.rdRolesLeaderHint,
            count: leaders,
            location: RedesignRoutes.role(RdRoleView.leader.key),
          ),
        _roleRow(
          Icons.person_outline,
          l10n.commonRolesMember,
          l10n.rdRolesMemberHint,
          count: count(RdRoleView.member),
          location: RedesignRoutes.role(RdRoleView.member.key),
        ),
      ]),
      ..._group(l10n.rdRolesOthers, [
        _roleRow(
          Icons.favorite_border,
          l10n.rolesParents,
          l10n.rdAdminParentsHint,
          count: rdLoadedValue(ref.watch(parentsProvider))?.length,
          value: access.parentsEnabled ? null : l10n.rdRolesOff,
          location: RedesignRoutes.parents,
        ),
        _roleRow(
          Icons.visibility_outlined,
          l10n.commonRolesViewer,
          l10n.rdAdminViewersHint,
          count: rdLoadedValue(ref.watch(viewersProvider))?.length,
          location: RedesignRoutes.viewers,
        ),
      ]),
      RdTenantSettingsBlock(sections: const [RdTenantSettings.assistant], label: l10n.rdRolesForAll),
      const SizedBox(height: 12),
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
    ];
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
