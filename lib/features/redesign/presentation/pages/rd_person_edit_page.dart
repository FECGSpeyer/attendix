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
import '../../../../core/utils/tenant_label_utils.dart';
import '../../../../core/utils/text_utils.dart' show emailsMatch;
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/repositories/cross_tenant_person_repository.dart';
import '../../../../data/repositories/extra_fields_repository.dart' show extraFieldDefaultValue;
import '../../../../data/repositories/player_repository.dart';
import '../../../../data/repositories/profile_repository.dart';
import '../../../../data/repositories/user_registration_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../duty/presentation/pages/unavailability_page.dart' show openUnavailabilityPage;
import '../../../people/person_stats.dart' show lateWarningThreshold;
import '../../../people/person_write.dart';
import '../../../people/presentation/pages/person_detail_page.dart'
    show personProvider, personAttendanceStatsProvider;
import '../../../people/presentation/widgets/person_detail/andere_instanzen_accordion.dart' show otherTenantsProvider;
import '../../../people/presentation/widgets/person_detail/late_warning_card.dart' show htmlStrongToSpan;
import '../../../people/presentation/widgets/person_detail/person_photo_actions.dart';
import '../../../people/presentation/widgets/person_match_suggestions.dart' show showEmailTakenDialog;
import '../../../people/presentation/widgets/person_transfer_sheet.dart' show showPersonTransferSheet;
import '../../../people/presentation/widgets/planned_absences.dart'
    show addPlannedAbsenceFlow, deletePlannedAbsenceFlow;
import '../widgets/event/rd_form_widgets.dart';
import '../widgets/members/rd_person_form.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

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
  late final int _personId = widget.personId;

  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  final _problemNotes = TextEditingController();
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
  bool _canTransfer = false;
  bool _showMore = false;
  bool _problemSolved = false;
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
    for (final c in [_first, _last, _email, _phone, _notes, _problemNotes]) {
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
    try {
      role = await repo.getTenantUserRole(appId);
      // LOGIC_PEOPLE: repair a half-approved account (like the person page).
      if (role == Role.applicant && !person.pending) {
        final mainId = await _mainGroupId;
        final promoted = mainId != null && person.instrument == mainId ? Role.responsible : Role.player;
        await repo.updateTenantUserRole(appId, promoted);
        role = promoted;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
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
  // Writing
  // ---------------------------------------------------------------------

  /// Queues [task]; the returned future completes when it finished.
  Future<void> _enqueue(Future<void> Function() task) {
    _running++;
    final run = _queue.then((_) => task()).catchError((Object e, StackTrace st) {
      ErrorReporter.report(e, st, where: 'rd_person_edit_page');
      if (mounted) ToastHelper.showError(context, context.l10n.personUpdateFailedWith(friendlyErrorMessage(e)));
    }).whenComplete(() {
      _running--;
      // Back may close the page directly again.
      if (_running == 0 && mounted && !_disposing) setState(() {});
    });
    return _queue = run;
  }

  void _refresh() {
    _container
      ..invalidate(personProvider(_personId))
      ..invalidate(realtimePlayersProvider);
  }

  void _markSaved() {
    if (!mounted) return;
    _savedTimer?.cancel();
    setState(() => _saved = true);
    _savedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  /// Writes [columns] (id + tenantId); reports a failure while the page is open.
  Future<bool> _store(Map<String, dynamic> columns) async {
    final repo = _repo;
    if (_deleted || !_editable || repo == null || !repo.hasTenantId) return false;
    try {
      await repo.updatePlayerFields(_personId, columns);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.personUpdateFailedWith(friendlyErrorMessage(e)));
      return false;
    }
    _refresh();
    _markSaved();
    try {
      _container.read(trackingServiceProvider).track(TrackingEvent.playerUpdated);
    } catch (_) {}
    return true;
  }

  /// Writes [columns] with the [entry] built from the stored person added to
  /// the stored history (like the person page with the freshly loaded
  /// person): entries deleted in "Verlauf" stay deleted, entries added
  /// elsewhere (copy to another group) stay. When the person cannot be
  /// loaded nothing is written (an old history would bring deleted entries
  /// back): a toast, and [revert] sets the shown value back.
  Future<bool> _storeWithHistory(
    Map<String, dynamic> columns,
    Map<String, dynamic> Function(Person stored) entry, {
    required VoidCallback revert,
  }) async {
    final repo = _repo;
    if (_deleted || !_editable || repo == null || !repo.hasTenantId) return false;
    Person? stored;
    Object? error;
    try {
      stored = await repo.getPlayerById(_personId);
    } catch (e, st) {
      error = e;
      ErrorReporter.report(e, st, where: 'rd_person_edit_page');
    }
    if (stored == null) {
      revert();
      if (mounted) {
        ToastHelper.showError(
          context,
          error == null ? context.l10n.redesignPersonNotFound : context.l10n.personUpdateFailedWith(friendlyErrorMessage(error)),
        );
      }
      return false;
    }
    final history = [
      for (final h in stored.history) h.toJson(),
      entry(stored),
    ];
    return _store({...columns, 'history': history});
  }

  void _apply(Map<String, dynamic> columns) {
    final p = _person;
    if (p == null) return;
    if (_disposing || !mounted) {
      _person = applyPersonColumns(p, columns);
      return;
    }
    setState(() => _person = applyPersonColumns(p, columns));
  }

  /// Changes of the "Weitere Angaben" fields.
  void _onColumns(Map<String, dynamic> columns, {bool typing = false}) {
    final before = _person;
    if (before == null || !_editable) return;
    if (typing) {
      _apply(columns);
      _typedColumns.addAll(columns);
      _restartTyping();
      return;
    }
    if (columns.containsKey('isLeader')) {
      _setLeader(columns['isLeader'] as bool);
      return;
    }
    _apply(columns);
    final after = _person!;
    _enqueue(() async {
      if (!await _store(columns)) return;
      // LOGIC_PEOPLE: Ionic updateShiftAssignmentsForPerson when the shift
      // plan, shift or start changed.
      if (shiftAssignmentChanged(
        oldShiftId: before.shiftId,
        oldShiftName: before.shiftName,
        oldShiftStart: before.shiftStart,
        newShiftId: after.shiftId,
        newShiftName: after.shiftName,
        newShiftStart: DateTime.tryParse(after.shiftStart ?? ''),
      )) {
        await _repo!.updateShiftAssignmentsForPerson(after);
      }
    });
  }

  void _onExtra(String id, dynamic value, {bool typing = false}) {
    if (!_editable) return;
    setState(() => _additional[id] = value);
    _pendingExtra[id] = value;
    _touchedExtra.add(id);
    if (typing) {
      _restartTyping();
    } else {
      _writeExtra();
    }
  }

  void _restartTyping() {
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 800), _flushTyped);
  }

  void _flushTyped() {
    _typingTimer?.cancel();
    if (_typedColumns.isNotEmpty) {
      final columns = Map<String, dynamic>.from(_typedColumns);
      _typedColumns.clear();
      _enqueue(() => _store(columns));
    }
    if (_pendingExtra.isNotEmpty) _writeExtra();
  }

  /// Zusatzfelder: organisation fields to tenant_group_person_fields, the
  /// rest to additional_fields, then Ionic
  /// syncPlayerWithUpcomingAttendancesByAdditionalFields.
  ///
  /// Only the fields changed here are put onto the stored values when the
  /// write runs (after the organisation values are loaded): values shown
  /// before they were loaded never overwrite stored organisation values.
  void _writeExtra() {
    final person = _person;
    final shared = _shared;
    final profileRepo = _profileRepo;
    if (_pendingExtra.isEmpty || person == null || shared == null || !_editable) return;
    final changes = Map<String, dynamic>.from(_pendingExtra);
    _pendingExtra.clear();
    // Written again with the next change or "Fertig" (newer values win).
    void keepForRetry() {
      for (final e in changes.entries) {
        _pendingExtra.putIfAbsent(e.key, () => e.value);
      }
    }

    _enqueue(() async {
      final fields = await shared;
      if (fields == null || profileRepo == null) {
        keepForRetry();
        if (mounted) ToastHelper.showError(context, context.l10n.svcLoadSharedFieldsFailed);
        return;
      }
      final old = _storedAdditional;
      final next = {...old, ...changes};
      if (mapEquals(next, old)) return;
      final Map<String, dynamic> local;
      try {
        local = await saveSharedPersonFields(
          profileRepo,
          values: next,
          orgFieldIds: fields.fieldIds,
          orgId: fields.orgId,
          personKey: organisationPersonKey(person),
        );
      } catch (e) {
        keepForRetry();
        if (mounted) ToastHelper.showError(context, context.l10n.personUpdateFailedWith(friendlyErrorMessage(e)));
        return;
      }
      if (!await _store({'additional_fields': local})) {
        keepForRetry();
        return;
      }
      _storedAdditional = next;
      try {
        await _repo!.syncPlayerWithUpcomingAttendances(
          (_person ?? person).copyWith(additionalFields: next),
          oldInstrument: (_person ?? person).instrument,
          oldAdditionalFields: old,
        );
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'rd_person_edit_page');
      }
    });
  }

  /// Names, phone and notes: written when the text differs from the stored
  /// one ([_confirmed]) and from the one already queued. Names are never
  /// emptied. Ionic: the previous note goes to the history.
  void _saveText(String column, String text) {
    final value = text.trim();
    final confirmed = _confirmed[column];
    if (!_editable || confirmed == null) return;
    if ((column == 'firstName' || column == 'lastName') && value.isEmpty) return;
    if (value == (_requested[column] ?? confirmed)) return;
    final stored = value.isEmpty ? null : value;
    _apply({column: stored});
    _requested[column] = value;
    _enqueue(() async {
      final bool ok;
      if (column == 'notes') {
        ok = await _storeWithHistory(
          {'notes': stored},
          (s) => personNotesChangeEntry(s.notes),
          revert: () {
            if (_requested['notes'] != value) return; // a newer note is queued
            final back = _confirmed['notes'] ?? '';
            _apply({'notes': back.isEmpty ? null : back});
            if (!_disposing && _notes.text.trim() == value) _notes.text = back;
          },
        );
      } else {
        ok = await _store({column: stored});
      }
      if (ok) _confirmed[column] = value;
      if (_requested[column] == value) _requested.remove(column);
    });
  }

  String _name(Person p) => '${p.firstName} ${p.lastName}'.trim();

  /// Ionic continueUpdatingPlayer role sync after a group or Stimmführer
  /// change (main group ⇄ Verantwortlicher, Stimmführer roles).
  Future<void> _syncRoles({
    required Person before,
    required Person after,
    required bool assignVoiceLeaderRole,
  }) async {
    final appId = before.appId;
    final tenantId = _repo?.currentTenantId;
    if (appId == null || tenantId == null) return;
    try {
      await syncPersonRoles(
        _container.read(authServiceProvider),
        appId: appId,
        tenantId: tenantId,
        mainGroupId: await _mainGroupId,
        oldGroupId: before.instrument,
        newGroupId: after.instrument,
        wasLeader: before.isLeader,
        isLeader: after.isLeader,
        isGeneral: _general,
        assignVoiceLeaderRole: assignVoiceLeaderRole,
      );
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.personFlutterRoleUpdateFailed(friendlyErrorMessage(e)));
    }
    if (mounted) await _loadUserRole(after);
  }

  /// Ionic onInstrumentChange: a moved person is no longer Stimmführer; the
  /// group change goes to the history.
  Future<void> _setGroup(int groupId) async {
    final before = _person;
    if (before == null || !_editable || before.instrument == groupId) return;
    _apply({'instrument': groupId, 'isLeader': false});
    final after = _person!;
    final groups = await _container.read(groupsMapProvider.future).catchError((Object _) => <int, String>{});
    _enqueue(() async {
      final ok = await _storeWithHistory(
        {'instrument': groupId, 'isLeader': false},
        (stored) => personGroupChangeEntry(groups, stored.instrument, groupId),
        // Back to the group shown before (unless another one was chosen).
        revert: () {
          if (_person?.instrument == groupId) _apply({'instrument': before.instrument, 'isLeader': before.isLeader});
        },
      );
      if (!ok) return;
      await _syncRoles(before: before, after: after, assignVoiceLeaderRole: false);
    });
  }

  /// Ionic: switching Stimmführer on for a person with an account asks
  /// whether the role comes with it.
  Future<void> _setLeader(bool value) async {
    final before = _person;
    if (before == null || !_editable || before.isLeader == value) return;
    var assign = false;
    if (value && before.appId != null && !_general) {
      final choice = await showVoiceLeaderRoleDialog(context, _name(before));
      if (choice == null || !mounted) return;
      assign = choice;
    }
    _apply({'isLeader': value});
    final after = _person!;
    _enqueue(() async {
      if (!await _store({'isLeader': value})) return;
      await _syncRoles(before: before, after: after, assignVoiceLeaderRole: assign);
    });
  }

  /// The typed e-mail differs from the stored one (only without an account).
  bool get _emailChanged {
    final p = _person;
    return p != null && p.appId == null && _email.text.trim() != (p.email ?? '').trim();
  }

  /// E-mail (only without an account): checked, matched against other
  /// groups, and – like the person page – registered right away. A second
  /// focus loss while it runs waits for the running save (one question, one
  /// account).
  Future<void> _saveEmail() {
    if (_disposing) return Future.value();
    return _emailSave ??= _runEmailSave().whenComplete(() {
      _emailSave = null;
      if (mounted && !_disposing) setState(() {});
    });
  }

  Future<void> _runEmailSave() async {
    try {
      await _writeEmail();
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'rd_person_edit_page');
    }
  }

  Future<void> _writeEmail() async {
    final person = _person;
    if (!_editable || person == null || person.appId != null || !mounted) return;
    var value = _email.text.trim();
    if (value == (person.email ?? '').trim()) {
      if (_emailInvalid) setState(() => _emailInvalid = false);
      return;
    }
    if (value.isNotEmpty && !isValidPersonEmail(value)) {
      setState(() => _emailInvalid = true);
      return;
    }
    setState(() => _emailInvalid = false);
    if (value.isEmpty) {
      _apply({'email': null});
      await _enqueue(() => _store({'email': null}));
      return;
    }
    // Bound to the person's group when the page was filled ([_fill]): the
    // account after "Ja" is created there even after a group switch.
    final registrations = _registrations;
    final draft = await _lookupEmail(value);
    if (!mounted) return;
    if (draft != null) value = draft.person.email?.trim() ?? value;
    if (value.isEmpty || value == (_person!.email ?? '').trim()) return;
    // Ionic: "Abbrechen" saves nothing – neither the e-mail nor the data of
    // the matched person.
    if (!await confirmCreateAccountForNewEmail(context)) {
      if (mounted) setState(() => _email.text = _person?.email ?? '');
      return;
    }
    if (mounted) _email.text = value;
    if (draft != null) await _takeDraft(draft);
    // Awaited: the e-mail save ([_emailSave]) runs until the account exists
    // and the page knows it, so a second focus loss neither asks again nor
    // queues a second account.
    await _enqueue(() async {
      final String appId;
      try {
        if (registrations == null || !registrations.hasTenantId) {
          throw AccountFlowException(l10nWithoutContext.coreFlutterNoInstanceSelected);
        }
        // Like AccountCreationNotifier.createAccount, with the bound repository.
        final mainGroupId = await registrations.getMainGroupId().catchError((Object _) => null);
        appId = await registrations.createPlayerAccount(_person!.copyWith(email: value), mainGroupId: mainGroupId);
      } catch (e) {
        if (mounted) ToastHelper.showError(context, context.l10n.personUpdateFailedWith(friendlyErrorMessage(e)));
        return;
      }
      _setAppId(appId);
      _container
        ..invalidate(playersProvider)
        ..invalidate(playerByIdProvider(_personId));
      if (await _store({'email': value})) _apply({'email': value});
    });
  }

  /// The account created here, before the reload shows it.
  void _setAppId(String appId) {
    final p = _person;
    if (p == null) return;
    if (_disposing || !mounted) {
      _person = p.copyWith(appId: appId);
      return;
    }
    setState(() => _person = p.copyWith(appId: appId));
    if (_editingStarted) _loadUserRole(_person!);
  }

  /// Ionic onEmailBlur: the e-mail belongs to a person of another group
  /// → that person's data, taken over only after "Ja" ([_takeDraft]).
  Future<({Person person, int? groupId})?> _lookupEmail(String email) async {
    final repo = ref.read(crossTenantPersonRepositoryWithTenantProvider);
    if (emailsMatch(email, _person?.email)) return null;
    List<CrossTenantPersonCandidate> matches;
    try {
      final linkedIds = await ref.read(linkedTenantIdsProvider.future);
      matches = await repo.getPossiblePersonsByEmail(email, linkedTenantIds: linkedIds);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.dbLoadPeopleFailed);
      return null;
    }
    matches = matches.where((m) => m.person.id != _personId).toList();
    if (matches.isEmpty || !mounted) return null;
    final chosen = await showEmailTakenDialog(
      context,
      matches,
      usedBy: context.l10n.redesignPersonFormEmailUsedBy,
      usedMany: context.l10n.redesignPersonFormEmailUsedMany,
    );
    if (chosen == null || !mounted) return null;
    final groups = ref.read(groupsProvider).valueOrNull ?? const [];
    final group = groups.where((g) => g.name == chosen.groupName).firstOrNull;
    return (person: chosen.person, groupId: group?.id);
  }

  /// Writes the data of the matched person (names, birthday, Nebenfach,
  /// Stimmlage, group).
  Future<void> _takeDraft(({Person person, int? groupId}) draft) async {
    final m = draft.person;
    if (mounted) {
      _first.text = m.firstName;
      _last.text = m.lastName;
    }
    _saveText('firstName', m.firstName);
    _saveText('lastName', m.lastName);
    _onColumns({
      if (m.correctBirthday && m.birthday != null) ...{'birthday': m.birthday, 'correctBirthday': true},
      'otherExercise': m.otherExercise,
      'range': m.range,
    });
    if (draft.groupId != null) await _setGroup(draft.groupId!);
    if (mounted) ToastHelper.showSuccess(context, context.l10n.personDataTaken);
  }

  // ---------------------------------------------------------------------
  // Actions (same calls as the person page of the normal app)
  // ---------------------------------------------------------------------

  Future<void> _solveProblem() async {
    if (!_editable) return;
    final remarks = _problemNotes.text;
    final entry = personProblemSolvedEntry(remarks);
    final columns = personProblemSolvedColumns();
    setState(() => _problemSolved = false);
    _problemNotes.clear();
    _enqueue(() => _storeWithHistory(
          columns,
          (_) => entry,
          // The remarks are shown again to save them later.
          revert: () {
            if (!mounted || _disposing) return;
            setState(() => _problemSolved = true);
            if (_problemNotes.text.isEmpty) _problemNotes.text = remarks;
          },
        ));
  }

  Future<void> _resetLateCount(Person person) async {
    try {
      await ref.read(playerNotifierProvider.notifier).resetLateCount(person);
      _container.invalidate(personProvider(_personId));
      _container.invalidate(personAttendanceStatsProvider(_personId));
      if (mounted) ToastHelper.showSuccess(context, context.l10n.personLateCounterReset);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.personResetFailed);
    }
  }

  Future<void> _changeRole(Person person) async {
    if (!ref.read(currentRoleProvider).isConductor) {
      ToastHelper.showError(context, context.l10n.personFlutterNoPermissionRoles);
      return;
    }
    // Bind the tenant repository before the first await (tenant switch).
    final repo = ref.read(userRegistrationRepositoryWithTenantProvider);
    final current = _userRole ?? Role.player;
    // Ionic: Mitglied, Verantwortlicher, Helfer and – for Stimmführer – the
    // Stimmführer roles; another current role stays visible.
    final roles = <Role>[
      Role.player,
      Role.responsible,
      Role.helper,
      if (person.isLeader) Role.voiceLeaderHelper,
      if (person.isLeader) Role.voiceLeader,
    ];
    if (!roles.contains(current)) roles.add(current);
    final role = await showAppActionSheet<Role>(
      context,
      title: context.l10n.personRole,
      actions: [for (final r in roles) AppActionSheetAction(value: r, label: UserRegistrationRepository.roleText(r))],
    );
    if (role == null || role == current || !mounted) return;
    if (person.appId == null || !repo.hasTenantId) return;
    try {
      await repo.updateTenantUserRole(person.appId!, role);
      if (!mounted) return;
      setState(() => _userRole = role);
      ToastHelper.showSuccess(context, context.l10n.personRoleUpdated);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  Future<void> _unlinkAccount(Person person) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.personRemoveAccount,
      message: context.l10n.personRemoveAccountMessage,
      confirmText: context.l10n.commonYes,
      cancelText: context.l10n.commonCancel,
    );
    if (!confirmed || !mounted) return;
    if (!ref.read(currentRoleProvider).isConductor) {
      ToastHelper.showError(context, context.l10n.personFlutterNoPermissionUnlink);
      return;
    }
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    try {
      await ref.read(playerNotifierProvider.notifier).unlinkAccount(person);
      _container.invalidate(personProvider(_personId));
      if (mounted) ToastHelper.showSuccess(context, context.l10n.personUserRemoved);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.personUserRemoveFailed);
    }
  }

  bool _creatingAccount = false;

  Future<void> _createAccount(Person person) async {
    if (_creatingAccount) return;
    if (!ref.read(currentRoleProvider).isConductor) {
      ToastHelper.showError(context, context.l10n.personFlutterNoPermissionCreateAccount);
      return;
    }
    final email = person.email;
    if (email == null || email.isEmpty) {
      ToastHelper.showError(context, context.l10n.personFlutterNoEmail);
      return;
    }
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.personFlutterCreateAccountQuestion,
      message: context.l10n.personFlutterCreateAccountMessage(person.fullName, email),
      confirmText: context.l10n.personFlutterCreateAccount,
      cancelText: context.l10n.commonCancel,
    );
    if (!confirmed || !mounted) return;
    _creatingAccount = true;
    try {
      // AUTH: attendix-user Edge Function; Verantwortlicher for the main
      // group, otherwise Spieler (Ionic).
      await ref.read(accountCreationNotifierProvider.notifier).createAccount(person);
      _container.invalidate(personProvider(_personId));
      if (mounted) ToastHelper.showSuccess(context, context.l10n.personFlutterAccountCreatedMail);
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(
            context, context.l10n.personFlutterCreateAccountFailed('${person.firstName} ${person.lastName}', e));
      }
    } finally {
      _creatingAccount = false;
    }
  }

  /// Ionic assignMyAccount(): link the signed-in user to this person.
  Future<void> _assignMyAccount(Person person) async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (person.id == null || user == null) return;
    try {
      final tenantUser = await ref.read(currentTenantUserProvider.future);
      await ref
          .read(accountCreationNotifierProvider.notifier)
          .createAccount(person.copyWith(email: tenantUser?.email ?? user.email));
      _container.invalidate(personProvider(_personId));
      _container.invalidate(realtimePlayersProvider);
      _container.invalidate(currentTenantUserProvider);
      if (mounted) ToastHelper.showSuccess(context, context.l10n.personUserAssigned);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
    }
  }

  Future<void> _searchOtherInstance(Person person) async {
    try {
      final linked = await searchPersonInOtherInstance(
        context,
        ref,
        person,
        firstName: person.firstName,
        lastName: person.lastName,
        onNoMatch: () {
          if (mounted) ToastHelper.showError(context, context.l10n.redesignPersonFormNoMatchOther);
        },
      );
      if (!linked) return;
      _refresh();
      if (mounted) ToastHelper.showSuccess(context, context.l10n.personEmailUpdated);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  /// Hands over the person as stored: typed text and running writes first,
  /// then reloaded (current history, e.g. after an earlier copy).
  Future<void> _transfer({required bool copy}) async {
    _saveTyped();
    await _settle();
    if (!mounted) return;
    Person? stored;
    try {
      stored = await _repo?.getPlayerById(_personId);
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'rd_person_edit_page');
    }
    final person = stored ?? _person;
    if (person == null || !mounted) return;
    final done = await showPersonTransferSheet(context, person, copy: copy);
    if (!done || !mounted) return;
    _refresh();
    if (!copy) {
      _deleted = true; // the person left this group
      context.go(RedesignRoutes.members);
    }
  }

  Future<void> _delete(Person person) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.attendanceRemovePerson,
      message: context.l10n.personRemovePersonMessage,
      confirmText: context.l10n.commonYes,
      cancelText: context.l10n.commonCancel,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(playerNotifierProvider.notifier).deletePlayer(_personId, appId: person.appId);
      _deleted = true;
      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.personRemoved);
      context.go(RedesignRoutes.members);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  /// Ionic activate(): "Person reaktivieren" for archived persons.
  Future<void> _reactivate(Person person) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.personReactivatePerson,
      message: context.l10n.personReactivateConfirm,
      confirmText: context.l10n.commonYes,
      cancelText: context.l10n.commonCancel,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(playerNotifierProvider.notifier).reactivatePlayer(person);
      _container.invalidate(realtimePlayersProvider);
      _container.invalidate(personProvider(_personId));
      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.personReactivated);
      _done();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  Future<void> _onAvatarTap(Person person) async {
    final hasImage = person.img != null && person.img!.isNotEmpty && !person.img!.contains('.svg');
    if (!hasImage) return replacePersonPhoto(context, ref, person);
    final action = await showAppActionSheet<String>(
      context,
      actions: [
        AppActionSheetAction(value: 'replace', icon: Icons.photo_camera_outlined, label: context.l10n.personReplace),
        AppActionSheetAction(value: 'remove', icon: Icons.delete_outline, label: context.l10n.commonRemove, destructive: true),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'replace':
        await replacePersonPhoto(context, ref, person);
      case 'remove':
        await removePersonPhoto(context, ref, person);
    }
  }

  void _showAccountHelp(Person person) {
    showAppDialog<void>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(ctx.l10n.personHelp),
        content: Text([if (person.appId == null) ctx.l10n.personAccountHelp, ctx.l10n.redesignPersonFormExistingUserHint].join('\n\n')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.commonClose))],
      ),
    );
  }

  /// Waits until every queued write finished (also the ones queued meanwhile).
  Future<void> _settle() async {
    while (true) {
      final queue = _queue;
      await queue;
      if (identical(queue, _queue)) return;
    }
  }

  /// "Fertig" and back: saves the typed text, waits for the e-mail (account
  /// question) and every queued write, then the page closes. Failures are
  /// shown as toasts while it is still open.
  Future<void> _done() async {
    if (_leaving) return;
    _leaving = true;
    final wasInvalid = _emailInvalid;
    FocusScope.of(context).unfocus();
    _saveTyped();
    await _saveEmail();
    await _settle();
    if (!mounted) return;
    // An invalid e-mail is shown once; "Fertig" again leaves without it.
    if (_emailInvalid && !wasInvalid) {
      _leaving = false;
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.person(_personId));
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
                action: RdOutlineButton(
                  label: l10n.redesignCommonRetry,
                  onPressed: () => ref.invalidate(personProvider(_personId)),
                ),
              ),
      ]);
    } else if (!isAdmin) {
      body = RdFormBody(children: [RdInfoCard(text: l10n.redesignPersonFormNotAllowed, icon: Icons.lock_outline)]);
    } else if (person.left != null) {
      body = RdFormBody(children: [
        RdInfoCard(
          text: l10n.redesignPersonFormArchived,
          icon: Icons.archive_outlined,
          action: RdPrimaryButton(label: l10n.personReactivatePerson, onPressed: () => _reactivate(person)),
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
            onPressed: () => context.push(RedesignRoutes.approvalReview(_personId)),
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
                  child: Text(
                    l10n.redesignPersonFormSaved,
                    key: const Key('rd-person-edit-saved'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RdType.meta(p, size: 13).copyWith(color: p.present),
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

  Widget _form(BuildContext context, Person person) {
    final p = context.rd;
    final l10n = context.l10n;
    final role = ref.watch(currentRoleProvider);
    final isAdmin = role.isAdmin || role.isResponsible;
    final tenant = ref.watch(currentTenantProvider);
    final main = ref.watch(mainGroupProvider).valueOrNull;
    final isMainGroup = main?.id != null && main!.id == person.instrument;
    final textStyle = TextStyle(fontSize: 17, color: p.text);
    final userId = ref.watch(currentAuthUserIdProvider);
    final isSelf = person.appId != null && person.appId == userId;
    final hasEmail = (person.email ?? '').trim().isNotEmpty;

    Widget hint(String text, {Color? color}) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(text, style: RdType.meta(p, size: 13).copyWith(color: color)),
        );
    Widget field(String label, TextEditingController c, FocusNode f, Key key,
            {TextInputType? keyboard, bool readOnly = false, int maxLines = 1, TextCapitalization caps = TextCapitalization.none}) =>
        RdFieldRow(
          label: label,
          child: TextField(
            key: key,
            controller: c,
            focusNode: f,
            readOnly: readOnly,
            keyboardType: keyboard,
            minLines: 1,
            maxLines: maxLines,
            textCapitalization: caps,
            style: readOnly ? textStyle.copyWith(color: p.text2) : textStyle,
            decoration: rdInputDecoration(p, ''),
            onChanged: (_) => setState(() {}),
          ),
        );
    Widget row(String title, VoidCallback? onTap, {IconData? icon, Color? color, String? value, String? subtitle, Key? key}) =>
        RdListRow(
          key: key,
          title: title,
          subtitle: subtitle,
          value: value,
          titleColor: color,
          leading: icon == null ? null : Icon(icon, color: color ?? p.softText),
          showChevron: color == null,
          onTap: onTap,
        );

    final namesEmpty = _first.text.trim().isEmpty || _last.text.trim().isEmpty;
    final stats = ref.watch(personAttendanceStatsProvider(_personId)).valueOrNull;
    final lateCount = stats?['lateCount'] as int? ?? 0;
    final lateExcused = stats?['lateCountExcused'] as int? ?? 0;
    final showLate = stats != null && lateCount >= lateWarningThreshold(tenant?.criticalRules);
    final canManageAbsences = ref.watch(canManagePlannedAbsencesProvider);
    final absences = canManageAbsences ? ref.watch(playerAbsencesByPersonIdProvider(_personId)).valueOrNull ?? const [] : const [];
    final others = person.appId == null ? null : ref.watch(otherTenantsProvider(person.appId!)).valueOrNull;

    return RdFormBody(
      children: [
        RdCard(
          padding: EdgeInsets.zero,
          color: person.isCritical ? p.absentSoft : null,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: RdPersonAvatar(name: _name(person), imageUrl: person.img, onTap: () => _onAvatarTap(person)),
              ),
              Expanded(
                child: Column(
                  children: [
                    field(l10n.peopleFirstName, _first, _firstFocus, const Key('rd-person-first'), caps: TextCapitalization.words),
                    Divider(height: 1, thickness: 1, color: p.line),
                    field(l10n.peopleLastName, _last, _lastFocus, const Key('rd-person-last'), caps: TextCapitalization.words),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (namesEmpty) hint(l10n.personEnterNames, color: p.absent),
        const SizedBox(height: 20),
        RdGroupLabel(groupLabel(tenant?.type)),
        RdPersonGroupChips(selected: person.instrument, onSelected: _setGroup),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignPersonFormContact),
        RdGroupedList(
          children: [
            field(l10n.peopleEmail, _email, _emailFocus, const Key('rd-person-email'),
                keyboard: TextInputType.emailAddress, readOnly: person.appId != null),
            field(l10n.peoplePhone, _phone, _phoneFocus, const Key('rd-person-phone'), keyboard: TextInputType.phone),
          ],
        ),
        if (_emailInvalid) hint(l10n.personInvalidEmail, color: p.absent),
        if (person.appId == null) hint(l10n.redesignPersonFormEmailHint),
        // Ionic: "Notizen" for Admins and Verantwortliche.
        if (isAdmin) ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.redesignPersonNotes),
          RdGroupedList(children: [
            field(l10n.peopleNotes, _notes, _notesFocus, const Key('rd-person-notes'),
                maxLines: 6, caps: TextCapitalization.sentences),
          ]),
        ],
        const SizedBox(height: 20),
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('rd-person-more'),
              title: l10n.redesignPersonFormMore,
              subtitle: l10n.redesignPersonFormMoreHint,
              showChevron: false,
              trailing: Icon(_showMore ? Icons.expand_less : Icons.expand_more, color: p.text2),
              onTap: () => setState(() => _showMore = !_showMore),
            ),
          ],
        ),
        if (_showMore) ...[
          const SizedBox(height: 12),
          RdPersonMoreFields(
            person: person,
            isMainGroup: isMainGroup,
            additionalValues: _additional,
            birthdayHighlight: !person.correctBirthday,
            onColumns: _onColumns,
            onExtra: _onExtra,
          ),
        ],
        hint(l10n.redesignPersonFormLiveHint),

        // Problemfall (Ionic: !readOnly && isCritical)
        if (person.isCritical) ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.peopleProblemCase),
          RdGroupedList(children: [
            RdListRow(
              title: l10n.personTalkedTo,
              showChevron: false,
              trailing: Switch.adaptive(
                value: _problemSolved,
                activeTrackColor: p.primary,
                onChanged: (v) => setState(() => _problemSolved = v),
              ),
              onTap: () => setState(() => _problemSolved = !_problemSolved),
            ),
            if (_problemSolved)
              RdFieldRow(
                label: l10n.personRemarks,
                child: TextField(
                  controller: _problemNotes,
                  minLines: 2,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  style: textStyle,
                  decoration: rdInputDecoration(p, ''),
                ),
              ),
          ]),
          if (_problemSolved) ...[
            const SizedBox(height: 12),
            RdPrimaryButton(label: l10n.redesignPersonFormProblemSave, onPressed: _solveProblem),
          ],
        ],

        // Verspätungen (Ionic late-warning-card)
        if (showLate) ...[
          const SizedBox(height: 20),
          RdCard(
            color: p.lateSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.personLateWarningTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text)),
                const SizedBox(height: 6),
                Text.rich(htmlStrongToSpan(l10n.personLateWarning(lateCount)), style: TextStyle(color: p.text)),
                if (lateExcused > 0) ...[
                  const SizedBox(height: 6),
                  Text(l10n.personLateExcusedExtra(lateExcused), style: RdType.meta(p, size: 13)),
                ],
                const SizedBox(height: 12),
                RdOutlineButton(label: l10n.personResetTalked, onPressed: () => _resetLateCount(person)),
              ],
            ),
          ),
        ],

        // Account (Ionic: !readOnly && !approveMode; pending persons only
        // get the approval card)
        ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.personAccount),
          RdGroupedList(children: [
            if (person.appId != null) ...[
              RdListRow(title: l10n.personAccount, value: l10n.personFlutterLinked, showChevron: false),
              RdListRow(
                key: const Key('rd-person-role'),
                title: l10n.personRole,
                value: _loadingRole ? '…' : UserRegistrationRepository.roleText(_userRole ?? Role.player),
                // Main group: the role follows the group (Ionic).
                onTap: isMainGroup || _loadingRole ? null : () => _changeRole(person),
              ),
              row(l10n.personFlutterUnlinkAccount, () => _unlinkAccount(person), icon: Icons.link_off, color: p.absent),
            ] else ...[
              if (hasEmail) row(l10n.personFlutterCreateAccount, () => _createAccount(person), icon: Icons.person_add_alt_outlined),
              if (hasEmail)
                row(l10n.redesignPersonFormSearchOtherGroup, () => _searchOtherInstance(person), icon: Icons.person_search),
            ],
            row(l10n.personHelp, () => _showAccountHelp(person), icon: Icons.help_outline),
          ]),
          if (person.appId == null && !hasEmail) hint(l10n.personFlutterEmailRequiredForAccount),
        ],

        // Abwesenheiten (Ionic person.page absences, Dienstplan)
        if (canManageAbsences) ...[
          const SizedBox(height: 20),
          RdGroupLabel(absences.isEmpty ? l10n.personAbsences : l10n.personAbsencesCount(absences.length)),
          RdGroupedList(children: [
            for (final a in absences)
              RdListRow(
                title: '${_fmt(a.fromDate)} – ${_fmt(a.untilDate)}',
                subtitle: a.reason,
                trailing: Icon(Icons.delete_outline, color: p.absent),
                showChevron: false,
                onTap: () => deletePlannedAbsenceFlow(context, ref, a),
              ),
            row(
              l10n.personAddAbsence,
              () => addPlannedAbsenceFlow(
                context,
                ref,
                personId: _personId,
                showLongAbsenceHint: true,
                forOther: true,
                firstName: person.firstName,
              ),
              icon: Icons.add_circle_outline,
            ),
            if (ref.watch(hasDutyTypesProvider))
              row(
                l10n.signoutRegularlyUnavailable,
                () => openUnavailabilityPage(context, personId: _personId, personName: person.fullName, forOther: true),
                icon: Icons.event_busy_outlined,
              ),
          ]),
        ],

        // Weitere Aktionen (Ionic openMoreMenu)
        const SizedBox(height: 20),
        RdGroupLabel(l10n.personActions),
        RdGroupedList(children: [
          row(l10n.redesignPersonHistory, () => context.push(RedesignRoutes.personHistory(_personId)), icon: Icons.history),
          if (person.appId == null)
            row(l10n.personAssignMyUser, () => _assignMyAccount(person), icon: Icons.person_pin_outlined),
          if (_canTransfer) ...[
            row(l10n.redesignPersonFormTransferOther, () => _transfer(copy: false), icon: Icons.drive_file_move_outline),
            row(l10n.redesignPersonFormCopyOther, () => _transfer(copy: true), icon: Icons.copy_outlined),
          ],
        ]),

        // Andere Gruppen (only with an account)
        if (others != null && others.isNotEmpty) ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.redesignPersonFormOtherGroups),
          RdGroupedList(children: [
            for (final t in others)
              RdListRow(
                title: t['tenantName'] as String,
                subtitle: t['role'] as String,
                value: t['percentage'] == null ? l10n.personNotAvailable : '${t['percentage']} %',
                showChevron: false,
              ),
          ]),
        ],

        if (!isSelf) ...[
          const SizedBox(height: 32),
          RdGroupedList(children: [
            row(l10n.attendanceRemovePerson, () => _delete(person),
                icon: Icons.delete_outline, color: p.absent, key: const Key('rd-person-delete')),
          ]),
        ],
      ],
    );
  }

  String _fmt(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}
