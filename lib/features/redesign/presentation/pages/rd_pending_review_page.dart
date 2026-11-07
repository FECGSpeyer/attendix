import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/tenant_label_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart' show ExtraField;
import '../../../../data/repositories/extra_fields_repository.dart' show extraFieldDefaultValue;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart' show showAppConfirm;
import '../../../people/person_write.dart';
import '../../../people/presentation/pages/person_detail_page.dart' show personProvider;
import '../../../people/presentation/widgets/duplicate_candidates_card.dart' show duplicateCandidatesProvider;
import '../widgets/event/rd_form_widgets.dart';
import '../widgets/manage/rd_manage_list.dart' show rdLoadedValue;
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/members/rd_person_form.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: Verwaltung › Freigaben › "Anfrage prüfen" (replaces the old
/// approval page `/people/:id` while the Beta is on; Admins and
/// Verantwortliche like the old page). Head like the Beta person page,
/// "Mögliche Doppelung" with "Zusammenführen", the details as in "Person
/// bearbeiten" (kept as a draft, written with "Aufnehmen") and "Ablehnen"
/// (with a reason). Approve, decline and merge run through the same code
/// as the old page ([PlayerNotifier.approvePlayer] / `declinePlayer`,
/// [PlayerRepository.mergePendingPlayerIntoExisting]); every write is bound
/// to the group the page was opened in.
class RdPendingReviewPage extends ConsumerStatefulWidget {
  const RdPendingReviewPage({super.key, required this.personId});

  final int personId;

  @override
  ConsumerState<RdPendingReviewPage> createState() => _RdPendingReviewPageState();
}

class _RdPendingReviewPageState extends ConsumerState<RdPendingReviewPage> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();

  /// The person as loaded and the edited draft (null until loaded).
  Person? _person;
  Person? _draft;

  /// Columns and Zusatzfelder changed here (old page: `_changedFields`).
  final Set<String> _changed = {};
  Map<String, dynamic> _additional = {};
  final Set<String> _touchedExtra = {};

  /// Zusatzfelder that only hold a default (no stored value yet); they get
  /// it again once the field definitions or Gemeinden are loaded.
  final Set<String> _defaulted = {};

  /// Organisation fields; null when they could not be loaded (then nothing
  /// is approved, like the old page).
  Future<SharedPersonFields?>? _shared;

  /// Group the page belongs to (bound when the person is loaded).
  int? _tenantId;
  late final ProviderContainer _container;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Still in the group the page was opened in (works after dispose too).
  bool _sameTenant() => _tenantId != null && _container.read(currentTenantIdProvider) == _tenantId;

  void _fill(Person person) {
    if (_person != null) return;
    final tenantId = ref.read(currentTenantIdProvider);
    // A person of another group (value left from before a switch) is never
    // bound to this one.
    if (tenantId == null || person.tenantId != tenantId) return;
    _tenantId = tenantId;
    _person = person;
    _draft = person;
    _first.text = person.firstName;
    _last.text = person.lastName;
    _email.text = person.email ?? '';
    _phone.text = person.phone ?? '';
    _notes.text = person.notes ?? '';
    _additional = Map<String, dynamic>.from(person.additionalFields ?? const {});
    _shared = _loadShared(person);
  }

  /// Old page (_withExtraDefaults): missing Zusatzfeld values get their
  /// default and are written with the approval. Runs on every build, so
  /// definitions and Gemeinden loaded later still count; edited and stored
  /// values stay.
  void _applyDefaults(List<ExtraField> fields, List<Church> churches) {
    final churchIds = <Object>[
      for (final c in churches)
        if (c.id != null) c.id!,
    ];
    for (final f in fields) {
      if (_touchedExtra.contains(f.id)) continue;
      if (_additional[f.id] != null && !_defaulted.contains(f.id)) continue;
      _additional[f.id] =
          extraFieldDefaultValue(f.type, defaultValue: f.defaultValue, options: f.options, churchIds: churchIds);
      _defaulted.add(f.id);
    }
  }

  Future<SharedPersonFields?> _loadShared(Person person) async {
    try {
      final shared = await loadSharedPersonFields(ref, ref.read(profileRepositoryWithTenantProvider), person);
      if (mounted) {
        setState(() {
          for (final e in shared.values.entries) {
            if (shared.fieldIds.contains(e.key) && !_touchedExtra.contains(e.key)) {
              _additional[e.key] = e.value;
              if (e.value != null) _defaulted.remove(e.key);
            }
          }
        });
      }
      return shared;
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.svcLoadSharedFieldsFailed);
      return null;
    }
  }

  void _onColumns(Map<String, dynamic> columns, {bool typing = false}) {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      _draft = applyPersonColumns(draft, columns);
      _changed.addAll(columns.keys);
    });
  }

  void _onExtra(String id, dynamic value, {bool typing = false}) {
    setState(() {
      _additional[id] = value;
      _touchedExtra.add(id);
      _changed.add('additionalFields.$id');
    });
  }

  String? _textOrNull(String? s) => (s ?? '').trim().isEmpty ? null : s!.trim();

  /// Columns the old page writes with the approval (`_draftFields`).
  Map<String, dynamic> _draftFields(Person d) => {
        'firstName': d.firstName.trim(),
        'lastName': d.lastName.trim(),
        'phone': _textOrNull(d.phone),
        'notes': _textOrNull(d.notes),
        'otherExercise': _textOrNull(d.otherExercise),
        'instrument': d.instrument,
        'birthday': d.birthday,
        'playsSince': d.playsSince,
        'joined': d.joined,
        'isLeader': d.isLeader,
        'hasTeacher': d.hasTeacher,
        'teacher': d.teacher,
        'shift_id': d.shiftId,
        'shift_name': d.shiftName,
        'shift_start': d.shiftStart,
        'parent_id': d.parentId,
        'correctBirthday': _changed.contains('birthday') || _person!.correctBirthday,
        'otherOrchestras': d.otherOrchestras,
        'range': _textOrNull(d.range),
        'instruments': _textOrNull(d.instruments),
        'examinee': d.examinee,
        'testResult': _textOrNull(d.testResult),
        'email': _textOrNull(d.email),
      };

  /// Back to Verwaltung › Freigaben (it leaves by itself once empty).
  void _leave() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      GoRouter.of(context).go(RedesignRoutes.approvals);
    }
  }

  void _refresh(int id) {
    _container.invalidate(personProvider(id));
    _container.invalidate(realtimePlayersProvider);
  }

  /// Old page `_approvePerson`: the changed details (organisation fields
  /// shared, the rest in additional_fields) are written together with the
  /// approval; no extra confirmation.
  Future<void> _approve() async {
    final person = _person;
    final draft = _draft;
    final id = person?.id;
    if (person == null || draft == null || id == null || _busy) return;
    final l10n = context.l10n;
    if (draft.firstName.trim().isEmpty || draft.lastName.trim().isEmpty) {
      ToastHelper.showError(context, l10n.personEnterNames);
      return;
    }
    // TENANT: everything bound before the first await.
    final repo = ref.read(playerRepositoryWithTenantProvider);
    final profileRepo = ref.read(profileRepositoryWithTenantProvider);
    final notifier = ref.read(playerNotifierProvider.notifier);
    if (!_sameTenant() || !repo.hasTenantId) {
      ToastHelper.showError(context, l10n.rdPeopleGroupSwitched);
      return;
    }
    setState(() => _busy = true);
    try {
      final shared = await _shared;
      if (!mounted) return;
      if (shared == null) {
        ToastHelper.showError(context, l10n.svcLoadSharedFieldsFailed);
        return;
      }
      if (!_sameTenant()) {
        ToastHelper.showError(context, l10n.rdPeopleGroupSwitched);
        return;
      }
      // Copied once the organisation values are loaded (old approval flow).
      final additional = Map<String, dynamic>.from(_additional);
      final edited = _draft ?? draft;
      final fields = _draftFields(edited);
      final changed = _changed.isNotEmpty;
      if (changed) {
        final local = await saveSharedPersonFields(
          profileRepo,
          values: additional,
          orgFieldIds: shared.fieldIds,
          orgId: shared.orgId,
          personKey: organisationPersonKey(person),
        );
        if (!_sameTenant()) throw StateError('group switched');
        await repo.updatePlayerFields(id, {...fields, 'additional_fields': local});
      }
      // The notifier reads its repositories right away: still this group.
      if (!_sameTenant()) throw StateError('group switched');
      await notifier.approvePlayer(person.copyWith(
        instrument: edited.instrument,
        joined: edited.joined,
        email: _textOrNull(edited.email),
        additionalFields: additional,
      ));
      _refresh(id);
      if (!mounted) return;
      ToastHelper.showSuccess(context, l10n.personUpdated);
      _leave();
    } catch (_) {
      if (mounted) ToastHelper.showError(context, l10n.personUpdateFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Old page `_declinePerson`: asks for the reason, then declines.
  Future<void> _decline() async {
    final person = _person;
    final id = person?.id;
    if (person == null || id == null || _busy) return;
    final l10n = context.l10n;
    final notifier = ref.read(playerNotifierProvider.notifier);
    final reason = await showRdTextSheet(
      context,
      title: l10n.personDeclinePerson,
      helper: l10n.personGiveReasonShort,
      required: true,
      maxLines: 4,
    );
    if (reason == null || !mounted) return;
    if (!_sameTenant()) {
      ToastHelper.showError(context, l10n.rdPeopleGroupSwitched);
      return;
    }
    setState(() => _busy = true);
    try {
      await notifier.declinePlayer(person, reason);
      _refresh(id);
      if (!mounted) return;
      ToastHelper.showSuccess(context, l10n.personUpdated);
      _leave();
    } catch (_) {
      if (mounted) ToastHelper.showError(context, l10n.personUpdateFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Old "Ähnliche Person bereits vorhanden" › "Zusammenführen".
  Future<void> _merge(Person candidate) async {
    final person = _person;
    if (person == null || _busy) return;
    final l10n = context.l10n;
    final repo = ref.read(playerRepositoryWithTenantProvider);
    final confirmed = await showAppConfirm(
      context,
      title: l10n.personMergePeople,
      message: l10n.personMergeMessage(
        '${person.firstName} ${person.lastName}',
        '${candidate.firstName} ${candidate.lastName}',
      ),
      confirmText: l10n.personMerge,
    );
    if (!confirmed || !mounted) return;
    if (!_sameTenant()) {
      ToastHelper.showError(context, l10n.rdPeopleGroupSwitched);
      return;
    }
    setState(() => _busy = true);
    try {
      final tenantUser = await ref.read(currentTenantUserProvider.future);
      final approver = tenantUser?.email ?? _container.read(supabaseClientProvider).auth.currentUser?.email ?? '';
      if (!_sameTenant()) throw StateError('group switched');
      await repo.mergePendingPlayerIntoExisting(person, candidate, approverEmail: approver);
      _container.invalidate(realtimePlayersProvider);
      _container.invalidate(pendingPlayersProvider);
      if (!mounted) return;
      ToastHelper.showSuccess(context, l10n.personMerged);
      _leave();
    } catch (_) {
      if (mounted) ToastHelper.showError(context, l10n.personMergeFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickGroup() async {
    final groups = ref.read(groupsProvider).valueOrNull ?? const [];
    final tenant = ref.read(currentTenantProvider);
    final id = await showRdChoiceSheet<int>(
      context,
      title: groupLabel(tenant?.type),
      options: [
        for (final g in groups)
          if (g.id != null) (g.id!, g.name),
      ],
      selected: _draft?.instrument,
    );
    if (id != null && mounted) _onColumns({'instrument': id});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(personProvider(widget.personId));
    // Only a value that surely belongs to the current group (not one kept
    // while reloading after a group switch).
    final loaded = rdLoadedValue(async);
    if (loaded != null && loaded.pending) _fill(loaded);
    if (_person != null) {
      _applyDefaults(
        ref.watch(personListExtraFieldsProvider),
        ref.watch(churchesProvider).valueOrNull ?? const <Church>[],
      );
    }
    final person = _person;
    final draft = _draft;
    final tenantId = ref.watch(currentTenantIdProvider);

    final back = RdBackLink(
      label: l10n.redesignManagePendingTitle,
      onTap: _leave,
    );

    if (person == null || draft == null || tenantId != _tenantId) {
      final done = loaded != null && !loaded.pending;
      return RdPage(children: [
        back,
        const SizedBox(height: 8),
        async.isLoading && person == null
            ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
            : RdInfoCard(
                text: done
                    ? l10n.rdPeopleReviewDone
                    : async.hasError
                        ? l10n.redesignTodayLoadFailed
                        : l10n.redesignPersonNotFound,
                icon: done ? Icons.how_to_reg_outlined : Icons.person_off_outlined,
                action: async.hasError
                    ? RdOutlineButton(
                        label: l10n.redesignCommonRetry,
                        onPressed: () => ref.invalidate(personProvider(widget.personId)),
                      )
                    : null,
              ),
      ]);
    }

    return RdPage(
      children: [
        back,
        const SizedBox(height: 8),
        _head(context, person),
        const SizedBox(height: 16),
        _duplicates(context, person),
        RdGroupLabel(l10n.rdPeopleReviewDetails),
        _details(context, draft),
        const SizedBox(height: 12),
        _moreFields(draft),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: RdOutlineButton(
                key: const Key('rd-review-decline'),
                label: l10n.personDecline,
                color: context.rd.absent,
                onPressed: _busy ? null : _decline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RdPrimaryButton(
                key: const Key('rd-review-approve'),
                label: l10n.rdPeopleReviewApprove,
                loading: _busy,
                onPressed: _approve,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _head(BuildContext context, Person person) {
    final p = context.rd;
    final l10n = context.l10n;
    final name = '${person.firstName} ${person.lastName}'.trim();
    final groups = ref.watch(groupsMapProvider).valueOrNull ?? const <int, String>{};
    final group = person.groupName ?? (person.instrument == null ? null : groups[person.instrument]);
    final created = person.createdAt;
    final meta = [
      if (created != null) l10n.rdPeopleReviewRequestedOn(DateFormat(dateFmt()).format(created.toLocal())),
      if ((group ?? '').isNotEmpty) group!,
    ].join(' · ');
    return Row(
      children: [
        RdInitials(rdInitialsOf(name.isEmpty ? '?' : name), size: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(name, style: RdType.title(p).copyWith(fontSize: 24))),
              if (meta.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(meta, style: RdType.meta(p, size: 15)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// "Mögliche Doppelung" (same check as the old page).
  Widget _duplicates(BuildContext context, Person person) {
    final p = context.rd;
    final l10n = context.l10n;
    final matches = ref.watch(duplicateCandidatesProvider(person)).valueOrNull ?? const [];
    if (matches.isEmpty) return const SizedBox.shrink();
    final groups = ref.watch(groupsMapProvider).valueOrNull ?? const <int, String>{};
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: RdCard(
        key: const Key('rd-review-duplicates'),
        color: p.excusedSoft,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.people_alt_outlined, color: p.text),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.rdPeopleReviewDuplicateTitle,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.rdPeopleReviewDuplicateHint, style: RdType.meta(p, size: 13)),
            for (final m in matches) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${m.candidate.firstName} ${m.candidate.lastName}',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: p.text),
                        ),
                        Text(
                          [
                            if (m.candidate.instrument != null && groups[m.candidate.instrument] != null)
                              groups[m.candidate.instrument]!,
                            m.reason,
                          ].join(' · '),
                          style: RdType.meta(p, size: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  RdOutlineButton(
                    key: Key('rd-review-merge-${m.candidate.id}'),
                    label: l10n.personMerge,
                    height: 40,
                    onPressed: _busy ? null : () => _merge(m.candidate),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Vorname, Nachname, E-Mail, Telefon, group and note as in "Person
  /// bearbeiten".
  Widget _details(BuildContext context, Person draft) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    final groups = ref.watch(groupsMapProvider).valueOrNull ?? const <int, String>{};
    final textStyle = TextStyle(fontSize: 17, color: p.text);

    Widget field(String label, TextEditingController c, String column, Key key,
            {TextInputType? keyboard, bool readOnly = false, int maxLines = 1, TextCapitalization caps = TextCapitalization.none}) =>
        RdFieldRow(
          label: label,
          child: TextField(
            key: key,
            controller: c,
            readOnly: readOnly,
            keyboardType: keyboard,
            minLines: 1,
            maxLines: maxLines,
            textCapitalization: caps,
            style: readOnly ? textStyle.copyWith(color: p.text2) : textStyle,
            decoration: rdInputDecoration(p, ''),
            onChanged: (v) => _onColumns({column: column == 'firstName' || column == 'lastName' ? v : _textOrNull(v)}),
          ),
        );

    return RdGroupedList(
      children: [
        field(l10n.peopleFirstName, _first, 'firstName', const Key('rd-review-first'), caps: TextCapitalization.words),
        field(l10n.peopleLastName, _last, 'lastName', const Key('rd-review-last'), caps: TextCapitalization.words),
        // Like the old approval page (no account section there): the
        // e-mail of the registration is shown, not changed.
        field(l10n.peopleEmail, _email, 'email', const Key('rd-review-email'),
            keyboard: TextInputType.emailAddress, readOnly: true),
        field(l10n.peoplePhone, _phone, 'phone', const Key('rd-review-phone'), keyboard: TextInputType.phone),
        RdListRow(
          key: const Key('rd-review-group'),
          title: groupLabel(tenant?.type),
          value: draft.instrument == null ? l10n.redesignPersonFormNotSet : groups[draft.instrument] ?? '',
          onTap: _busy ? null : _pickGroup,
        ),
        field(l10n.redesignPersonNotes, _notes, 'notes', const Key('rd-review-notes'),
            maxLines: 6, caps: TextCapitalization.sentences),
      ],
    );
  }

  /// Birthday, joined, Zusatzfelder … (the "Weitere Angaben" of "Person
  /// bearbeiten", always open: they come from the registration).
  Widget _moreFields(Person draft) {
    final main = ref.watch(mainGroupProvider).valueOrNull;
    return RdPersonMoreFields(
      person: draft,
      isMainGroup: main?.id != null && main!.id == draft.instrument,
      additionalValues: _additional,
      birthdayHighlight: !draft.correctBirthday,
      onColumns: _onColumns,
      onExtra: _onExtra,
    );
  }
}
