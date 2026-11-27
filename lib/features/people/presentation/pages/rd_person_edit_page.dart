import 'dart:async';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/cross_tenant_person_providers.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/self_service_providers.dart' show currentSelfServicePlayerProvider;
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_registration_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/error_reporter.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/people_shift_status.dart' show shiftAssignmentChanged;
import '../../../../core/utils/text_utils.dart' show emailsMatch;
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/models/person/person.dart';
import '../../../../core/providers/admin_providers.dart' show TenantUser, tenantUsersProvider;
import '../../../../core/providers/person_detail_providers.dart'
    show otherTenantsProvider, personAttendanceStatsProvider, personProvider;
import '../../../../data/repositories/cross_tenant_person_repository.dart';
import '../../../../data/repositories/extra_fields_repository.dart' show extraFieldDefaultValue;
import '../../../../data/repositories/player_repository.dart';
import '../../../../data/repositories/profile_repository.dart';
import '../../../../data/repositories/user_registration_repository.dart';
import '../../../../core/services/auth/auth_service.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../duty/presentation/pages/unavailability_page.dart' show openUnavailabilityPage;
import '../../person_stats.dart' show htmlStrongToSpan, lateWarningThreshold;
import '../../person_write.dart';
import '../widgets/email_taken_dialog.dart' show showEmailTakenDialog;
import '../widgets/person_detail/person_photo_actions.dart';
import '../widgets/person_transfer_sheet.dart' show showPersonTransferSheet;
import '../widgets/planned_absences.dart'
    show addPlannedAbsenceFlow, deletePlannedAbsenceFlow;
import '../../../../core/redesign/rd_words.dart';
import '../../../attendance/presentation/widgets/event/rd_form_widgets.dart';
import '../widgets/members/rd_person_form.dart';
import '../widgets/members/rd_critical_talk.dart' show RdCriticalReasonRow, rdRecordTalk;
import '../../data/providers/rd_critical_providers.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../today/presentation/widgets/rd_today_common.dart' show RdInfoCard;

part 'rd_person_edit_actions.dart';
part 'rd_person_edit_form.dart';
part 'rd_person_edit_writes.dart';

/// REDESIGN: "Person bearbeiten" (canvas "Einheitliche Beta-UX", board A):
/// the cards of "Neue Person", saved right away like "Werk bearbeiten"
/// ("Gespeichert ✓"). Below: Problemfall, Verspätungen, Account, actions
/// (Benutzer zuweisen, übertragen / kopieren, Abwesenheiten, Entfernen)
/// and other instances. Pausieren / Archivieren stay on the person page.
/// The writes run through the same code as the person page of the
/// normal app ([syncPersonRoles], [saveSharedPersonFields], …), every
/// write with id + tenantId ([PlayerRepository.updatePlayerFields]).
class RdPersonEditPage extends ConsumerStatefulWidget {
  const RdPersonEditPage({super.key, required this.personId});

  final int personId;

  @override
  ConsumerState<RdPersonEditPage> createState() => _RdPersonEditPageState();
}

class _RdPersonEditPageState extends ConsumerState<RdPersonEditPage> {
  bool _creatingAccount = false;
  void _update(VoidCallback fn) => setState(fn);

  late final int _personId = widget.personId;

  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  final _firstFocus = FocusNode();
  final _lastFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _notesFocus = FocusNode();

  /// The person as last written (null until loaded).
  Person? _person;
  Map<String, dynamic> _additional = {};
  Map<String, dynamic> _storedAdditional = {};
  Future<SharedPersonFields?>? _shared;

  Role? _userRole;
  bool _loadingRole = false;

  /// The account's role could not be read (shown as Mitglied then).
  bool _roleUnknown = false;
  bool _canTransfer = false;
  bool _showMore = false;
  bool _emailInvalid = false;
  bool _deleted = false;
  bool _saved = false;
  Timer? _savedTimer;

  /// Typed text is saved a moment after the last key stroke.
  Timer? _typingTimer;
  final Map<String, dynamic> _typedColumns = {};

  /// Zusatzfelder changed here and not queued yet (also those whose write
  /// failed: they are written again with the next change or "Fertig").
  final Map<String, dynamic> _pendingExtra = {};

  /// Zusatzfelder changed here: the organisation values loaded later do not
  /// replace what was entered.
  final Set<String> _touchedExtra = {};

  /// Names, phone and notes as stored (trimmed). Only a successful write
  /// changes them, so a failed one is written again on the next focus loss
  /// or "Fertig".
  final Map<String, String> _confirmed = {};

  /// The newest queued value per text column (until its write finished).
  final Map<String, String> _requested = {};

  /// Writes run one after another, so the last change always wins.
  Future<void> _queue = Future.value();

  /// Counts the Stimmführer switch changes: a failed one only jumps back
  /// while no newer change follows.
  int _leaderChanges = 0;

  /// Queued writes that have not finished yet.
  int _running = 0;

  /// Bound once the person is loaded, so text saved when the page closes
  /// (or while the group changes) still goes to the group it came from.
  PlayerRepository? _repo;
  ProfileRepository? _profileRepo;
  UserRegistrationRepository? _registrations;
  Future<int?> _mainGroupId = Future.value(null);
  bool _general = false;
  late final ProviderContainer _container;

  /// Admin or Verantwortlicher (set while building).
  bool _canEdit = false;

  /// Loading of Zusatzfelder and account role (only for editable persons).
  bool _editingStarted = false;

  /// The running e-mail save (check, other groups, account question).
  Future<void>? _emailSave;

  /// "Fertig" / back is running.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    for (final (focus, save) in [
      (_firstFocus, () => _saveText('firstName', _first.text)),
      (_lastFocus, () => _saveText('lastName', _last.text)),
      (_phoneFocus, () => _saveText('phone', _phone.text)),
      (_notesFocus, () => _saveText('notes', _notes.text)),
      (_emailFocus, _saveEmail),
    ]) {
      focus.addListener(() {
        // dispose saves the text itself.
        if (!focus.hasFocus && !_disposing) save();
      });
    }
    _checkTransfer();
  }

  /// Set while the page closes: values are still written, the page is not
  /// rebuilt any more.
  bool _disposing = false;

  /// Only Admins and Verantwortliche write, and not for archived persons or
  /// persons waiting for approval (they are approved on the approval page).
  bool get _editable {
    final p = _person;
    return _canEdit && p != null && p.left == null && !p.pending;
  }

  /// Text typed last (no focus change yet). The e-mail is not part of it:
  /// it needs the account question ([_done] waits for it).
  void _saveTyped() {
    _flushTyped();
    for (final (column, c) in _textFields) {
      _saveText(column, c.text);
    }
  }

  List<(String, TextEditingController)> get _textFields =>
      [('firstName', _first), ('lastName', _last), ('phone', _phone), ('notes', _notes)];

  /// Something is not written yet: back goes through [_done], which waits
  /// for it (and shows a failure while the page is still open).
  bool get _unsaved =>
      _running > 0 ||
      _emailSave != null ||
      _emailChanged ||
      _typedColumns.isNotEmpty ||
      _pendingExtra.isNotEmpty ||
      _textFields.any((f) => _confirmed.containsKey(f.$1) && f.$2.text.trim() != _confirmed[f.$1]);

  @override
  void dispose() {
    _disposing = true;
    // Text typed last is saved when the page closes (no focus change).
    _saveTyped();
    _typingTimer?.cancel();
    _savedTimer?.cancel();
    for (final c in [_first, _last, _email, _phone, _notes]) {
      c.dispose();
    }
    for (final f in [_firstFocus, _lastFocus, _emailFocus, _phoneFocus, _notesFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  T? _tryRead<T>(ProviderListenable<T> provider) {
    try {
      return ref.read(provider);
    } catch (_) {
      return null;
    }
  }

  void _fill(Person person) {
    if (_person != null) return;
    // Bound here: a group change while saving keeps the group of the page.
    _repo = ref.read(playerRepositoryWithTenantProvider);
    _profileRepo = _tryRead(profileRepositoryWithTenantProvider);
    _registrations = _tryRead(userRegistrationRepositoryWithTenantProvider);
    _general = ref.read(currentTenantProvider)?.type == 'general';
    _mainGroupId = ref.read(mainGroupProvider.future).then<int?>((g) => g?.id).catchError((Object _) => null);
    _person = person;
    _first.text = person.firstName;
    _last.text = person.lastName;
    _email.text = person.email ?? '';
    _phone.text = person.phone ?? '';
    _notes.text = person.notes ?? '';
    // Compared trimmed: opening and closing the page writes nothing (e.g. a
    // stored note "abc\n").
    for (final (column, c) in _textFields) {
      _confirmed[column] = c.text.trim();
    }
    // Ionic ngOnInit: missing Zusatzfeld values get their default.
    final fields = ref.read(personListExtraFieldsProvider);
    final churchIds = <Object>[
      for (final c in ref.read(churchesProvider).valueOrNull ?? const <Church>[])
        if (c.id != null) c.id!,
    ];
    final values = Map<String, dynamic>.from(person.additionalFields ?? const {});
    _additional = {
      ...values,
      for (final f in fields)
        if (values[f.id] == null)
          f.id: extraFieldDefaultValue(f.type, defaultValue: f.defaultValue, options: f.options, churchIds: churchIds),
    };
    _storedAdditional = Map.of(_additional);
  }

  /// Organisation fields and account role: only loaded when the person can
  /// be edited (the role check may repair the account, a write).
  void _startEditing() {
    final person = _person;
    if (_editingStarted || person == null || !_editable) return;
    _editingStarted = true;
    _shared = _loadShared(person);
    _loadUserRole(person);
  }

  /// Organisation fields: shared values replace the stored ones (and the
  /// shown ones not changed here meanwhile). Null when they cannot be loaded
  /// (then Zusatzfelder are not saved, like Ionic).
  Future<SharedPersonFields?> _loadShared(Person person) async {
    try {
      final repo = _profileRepo;
      if (repo == null) throw StateError('no profile repository');
      final shared = await loadSharedPersonFields(ref, repo, person);
      void take() {
        for (final e in shared.values.entries) {
          if (!shared.fieldIds.contains(e.key)) continue;
          _storedAdditional[e.key] = e.value;
          if (!_touchedExtra.contains(e.key)) _additional[e.key] = e.value;
        }
      }

      if (mounted && !_disposing) {
        setState(take);
      } else {
        take();
      }
      return shared;
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.svcLoadSharedFieldsFailed);
      return null;
    }
  }

  Future<void> _loadUserRole(Person person) async {
    final appId = person.appId;
    final repo = _registrations;
    if (appId == null || repo == null || !repo.hasTenantId) return;
    // Also called while building (first load): the result rebuilds.
    _loadingRole = true;
    Role? role;
    var failed = false;
    try {
      role = await repo.getTenantUserRole(appId);
      // LOGIC_PEOPLE: repair a half-approved account (like the person page).
      if (role == Role.applicant && !person.pending) {
        final mainId = await _mainGroupId;
        final promoted = mainId != null && person.instrument == mainId ? Role.responsible : Role.player;
        await repo.updateTenantUserRole(appId, promoted);
        role = promoted;
      }
    } catch (_) {
      failed = true;
    }
    if (mounted) {
      setState(() {
        _roleUnknown = failed;
        _userRole = role ?? Role.player;
        _loadingRole = false;
      });
    }
  }

  /// Ionic: transfer / copy only with an organisation and other instances.
  Future<void> _checkTransfer() async {
    try {
      final org = await ref.read(currentOrganisationProvider.future);
      final can = org != null && (await ref.read(linkedTenantsProvider.future)).isNotEmpty;
      if (mounted) setState(() => _canTransfer = can);
    } catch (_) {}
  }

  /// Account, Passbild, history and status come from reloads (actions on
  /// this page); typed values stay.
  void _takeOver(Person remote) {
    final local = _person;
    if (local == null) return;
    setState(() {
      _person = local.copyWith(
        appId: remote.appId,
        img: remote.img,
        email: remote.email,
        globalPersonId: remote.globalPersonId,
        isCritical: remote.isCritical,
        lastSolve: remote.lastSolve,
        pending: remote.pending,
        left: remote.left,
        paused: remote.paused,
        groupName: remote.groupName,
        history: remote.history,
      );
      // A typed or still checked e-mail stays.
      if (!_emailFocus.hasFocus && _emailSave == null && !_emailInvalid) _email.text = remote.email ?? '';
    });
    if (local.appId != remote.appId && _editingStarted) {
      _userRole = null;
      _loadUserRole(remote);
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final async = ref.watch(personProvider(_personId));
    ref.listen<AsyncValue<Person?>>(personProvider(_personId), (_, next) {
      final remote = next.valueOrNull;
      if (remote != null) _takeOver(remote);
    });
    final role = ref.watch(currentRoleProvider);
    final isAdmin = role.isAdmin || role.isResponsible;
    _canEdit = isAdmin;
    final loaded = async.valueOrNull;
    if (loaded != null) _fill(loaded);
    _startEditing();
    final person = _person;

    final Widget body;
    if (person == null) {
      body = RdFormBody(children: [
        async.isLoading
            ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
            : RdInfoCard(
                text: async.hasError ? l10n.redesignTodayLoadFailed : l10n.redesignPersonNotFound,
                icon: Icons.person_off_outlined,
                // Retry only helps after an error, not when it is gone.
                action: async.hasError
                    ? RdOutlineButton(
                      label: l10n.redesignCommonRetry,
                      onPressed: () => ref.invalidate(personProvider(_personId)),
                    )
                    : null,
              ),
      ]);
    } else if (!isAdmin) {
      body = RdFormBody(children: [RdInfoCard(text: l10n.redesignPersonFormNotAllowed, icon: Icons.lock_outline)]);
    } else if (person.left != null) {
      body = RdFormBody(children: [
        RdInfoCard(
          text: l10n.redesignPersonFormArchived,
          icon: Icons.archive_outlined,
          action: RdPrimaryButton(label: l10n.redesignArchiveListRestore, onPressed: () => _reactivate(person)),
        ),
      ]);
    } else if (person.pending) {
      // Like the person page: a pending person is only approved or declined
      // (changes are saved with the approval), nothing is written here.
      body = RdFormBody(children: [
        RdInfoCard(
          text: l10n.redesignPersonPending,
          icon: Icons.hourglass_top_rounded,
          action: RdPrimaryButton(
            key: const Key('rd-person-review'),
            label: l10n.redesignPersonReview,
            onPressed: () => context.push(RedesignRoutes.membersReview(_personId)),
          ),
        ),
      ]);
    } else {
      body = _form(context, person);
    }

    final name = person == null ? '' : _name(person);
    final page = Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RdEditTopBar(
              title: name.isEmpty ? l10n.personEditPerson : l10n.redesignPersonFormEditTitle(name),
              doneKey: const Key('rd-person-edit-done'),
              onDone: _done,
              leading: AnimatedOpacity(
                opacity: _saved ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  // Shrinks instead of cutting "Gespeichert ✓" in the 88 wide slot.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.redesignPersonFormSaved,
                      key: const Key('rd-person-edit-saved'),
                      maxLines: 1,
                      style: RdType.meta(p, size: 13).copyWith(color: p.present),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
    // Back waits for the e-mail (account question) and the writes like
    // "Fertig" while something is not saved yet.
    return PopScope(
      canPop: !(_editable && _unsaved),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: page,
    );
  }

}

/// The Stimmführer role that goes with [role] (Mitglied → Stimmführer,
/// Helfer → Stimmführer-Helfer); null for every other role.
Role? rdLeaderRoleFor(Role? role) => switch (role) {
      Role.player => Role.voiceLeader,
      Role.helper => Role.voiceLeaderHelper,
      _ => null,
    };

/// [role] without its Stimmführer part (Stimmführer → Mitglied,
/// Stimmführer-Helfer → Helfer).
Role rdBaseRole(Role role) => switch (role) {
      Role.voiceLeader => Role.player,
      Role.voiceLeaderHelper => Role.helper,
      _ => role,
    };

/// Role shown at a person: for Stimmführer the base role (the switch
/// "Stimmführer" shows the rest); a Stimmführer role without the switch keeps
/// its full name.
String rdRoleLabel(Role role, {required bool isLeader}) =>
    UserRegistrationRepository.roleText(isLeader ? rdBaseRole(role) : role);
