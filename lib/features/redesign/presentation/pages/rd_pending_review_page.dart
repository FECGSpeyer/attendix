import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/extra_field_utils.dart' show formatExtraFieldValue;
import '../../../../core/utils/handover_request.dart';
import '../../../../core/utils/tenant_label_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/utils/parent_registration.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart' show ExtraField;
import '../../../../data/repositories/extra_fields_repository.dart' show extraFieldDefaultValue;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart' show showAppConfirm;
import '../../../people/person_write.dart';
import '../../../people/presentation/pages/person_detail_page.dart' show personProvider;
import '../../../people/presentation/widgets/duplicate_candidates_card.dart' show duplicateCandidatesProvider;
import '../../../people/presentation/widgets/parent_review_hint.dart';
import '../widgets/manage/rd_manage_list.dart' show rdLoadedValue;
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/members/rd_person_form.dart' show applyPersonColumns;
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard, RdLinkButton;

/// REDESIGN: Verwaltung › Freigaben › "Anfrage prüfen" (replaces the old
/// approval page `/people/:id` while the Beta is on; Admins and
/// Verantwortliche like the old page). Head like the Beta person page,
/// "Mögliche Doppelung" with "Zusammenführen", the registration's details
/// to read (only the group can be changed before "Aufnehmen"; everything
/// else is edited on the person afterwards), "Aufnehmen" as the one main
/// action and "Ablehnen" (with a reason) below it. Ionic opens the full
/// person form here; the Beta deliberately keeps it lean. Approve, decline and merge run through the same code
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
  /// The person as loaded and the edited draft (null until loaded).
  Person? _person;
  Person? _draft;

  /// Columns changed here (only the group; old page: `_changedFields`).
  final Set<String> _changed = {};
  Map<String, dynamic> _additional = {};

  /// Zusatzfelder that only hold a default (no stored value yet); they get
  /// it again once the field definitions or Gemeinden are loaded.
  final Set<String> _defaulted = {};

  /// The organisation values were loaded (or failed): only then the
  /// Zusatzfelder are shown, with the stored values.
  bool _sharedDone = false;

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
    _additional = Map<String, dynamic>.from(person.additionalFields ?? const {});
    _shared = _loadShared(person);
  }

  /// Old page (_withExtraDefaults): missing Zusatzfeld values get their
  /// default and are written with the approval. Runs on every build, so
  /// definitions and Gemeinden loaded later still count; stored values
  /// stay.
  void _applyDefaults(List<ExtraField> fields, List<Church> churches) {
    final churchIds = <Object>[
      for (final c in churches)
        if (c.id != null) c.id!,
    ];
    for (final f in fields) {
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
          _sharedDone = true;
          for (final e in shared.values.entries) {
            if (shared.fieldIds.contains(e.key)) {
              _additional[e.key] = e.value;
              if (e.value != null) _defaulted.remove(e.key);
            }
          }
        });
      }
      return shared;
    } catch (_) {
      if (mounted) {
        setState(() => _sharedDone = true);
        ToastHelper.showError(context, context.l10n.svcLoadSharedFieldsFailed);
      }
      return null;
    }
  }

  void _onColumns(Map<String, dynamic> columns) {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      _draft = applyPersonColumns(draft, columns);
      _changed.addAll(columns.keys);
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

  /// Old page `_approvePerson`: a changed group (with the details, the
  /// organisation fields shared, the rest in additional_fields) is written
  /// together with the approval; no extra confirmation.
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
    final tenantId = ref.watch(currentTenantIdProvider);
    final orgAsync = ref.watch(currentOrganisationProvider);
    final churchesAsync = ref.watch(churchesProvider);
    // Defaults only from the definitions of the bound group.
    if (_person != null && tenantId == _tenantId) {
      _applyDefaults(
        ref.watch(personListExtraFieldsProvider),
        churchesAsync.valueOrNull ?? const <Church>[],
      );
    }
    // The Zusatzfelder start once their values and definitions are loaded
    // (their text inputs keep what they started with).
    final extrasReady = _sharedDone && !orgAsync.isLoading && !churchesAsync.isLoading;
    final person = _person;
    final draft = _draft;

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
        if (handoverRequestOf(person) case final handover?) ...[
          RdInfoCard(
            key: const Key('rd-review-handover'),
            icon: Icons.swap_horiz,
            text: '${l10n.peopleFlutterHandoverRequestHint(handover.fromTenantName)}\n'
                '${handover.keep ? l10n.peopleFlutterHandoverRequestKeeps : l10n.peopleFlutterHandoverRequestMoves}',
          ),
          const SizedBox(height: 16),
        ],
        _duplicates(context, person),
        RdGroupLabel(l10n.rdPeopleReviewDetails),
        _details(context, draft, extrasReady),
        const SizedBox(height: 24),
        RdPrimaryButton(
          key: const Key('rd-review-approve'),
          label: l10n.rdPeopleReviewApprove,
          loading: _busy,
          onPressed: _approve,
        ),
        const SizedBox(height: 8),
        Center(
          child: RdLinkButton(
            key: const Key('rd-review-decline'),
            label: l10n.personDecline,
            onPressed: _decline,
          ),
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
    // A child registered by an Elternteil is never merged: the merge would
    // move the parent's account onto the existing person.
    if (parentRegistrationOf(person) != null) return const SizedBox.shrink();
    // A handover request is taken in or declined as it is (a merge would
    // leave the asking group without its answer).
    if (handoverRequestOf(person) != null) return const SizedBox.shrink();
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

  /// What the registration holds, to read: e-mail, phone, group (the only
  /// thing to change here), dates, the other filled columns, the filled
  /// Zusatzfelder and the note. Empty values are left out.
  Widget _details(BuildContext context, Person draft, bool extrasReady) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    final groups = ref.watch(groupsMapProvider).valueOrNull ?? const <int, String>{};
    final long = DateFormat.yMMMd(currentIntlLocale());

    String? text(String? s) => _textOrNull(s);
    String? date(String? s) {
      final d = DateTime.tryParse(s ?? '');
      return d == null ? null : long.format(d);
    }

    // Short values at the end of the row; long or multi-line ones (a note,
    // a text Zusatzfeld) in full below the label, so nothing is cut off.
    Widget block(String title, String value, {Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.text)),
              const SizedBox(height: 2),
              Text(value, style: RdType.meta(p, size: 14)),
            ],
          ),
        );
    Widget info(String title, String value, {Key? key}) => value.length > 28 || value.contains('\n')
        ? block(title, value, key: key)
        : RdListRow(key: key, title: title, value: value, showChevron: false);

    // Registered by an Elternteil ("Mein Kind"): the e-mail is the parent's,
    // shown in its own block below.
    final parent = parentRegistrationOf(_person ?? draft);
    final rows = <Widget>[
      if (parent == null)
        if (text(draft.email) case final v?) info(l10n.peopleEmail, v, key: const Key('rd-review-email')),
      if (text(draft.phone) case final v?) info(l10n.peoplePhone, v, key: const Key('rd-review-phone')),
      RdListRow(
        key: const Key('rd-review-group'),
        title: groupLabel(tenant?.type),
        value: draft.instrument == null ? l10n.redesignPersonFormNotSet : groups[draft.instrument] ?? '',
        onTap: _busy ? null : _pickGroup,
      ),
      if (date(draft.birthday) case final v?) info(l10n.redesignPersonBirthday, v),
      if (date(draft.playsSince) case final v?) info(l10n.personPlaysSince, v),
      if (text(draft.range) case final v?) info(l10n.personVocalRange, v),
      if (text(draft.instruments) case final v?) info(l10n.peopleInstruments, v),
      if (text(draft.otherExercise) case final v?) info(l10n.peopleOtherDuties, v),
      if ((draft.otherOrchestras ?? const <String>[]).isNotEmpty)
        info(l10n.personOtherOrchestras, draft.otherOrchestras!.join(', ')),
      if (draft.examinee) info(l10n.peopleCandidate, l10n.commonYes),
      if (text(draft.testResult) case final v?) info(l10n.peopleTestResult, v),
      if (extrasReady) ..._extraRows(info),
    ];
    final notes = text(draft.notes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupedList(children: [
          ...rows,
          if (notes != null) block(l10n.redesignPersonNotes, notes, key: const Key('rd-review-notes')),
        ]),
        if (parent != null) ...[
          const SizedBox(height: 18),
          RdSectionHeader(l10n.parentRegisterReviewParent),
          RdGroupedList(children: [
            block(parent.fullName, parent.email, key: const Key('rd-review-parent')),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(parentReviewHint(ref, l10n, parent), style: RdType.meta(p, size: 13)),
          ),
        ],
        if (!extrasReady) ...[
          const SizedBox(height: 12),
          RdInfoCard(text: l10n.redesignTodayLoading, loading: true),
        ],
      ],
    );
  }

  /// Zusatzfelder the registration filled (defaults added for the approval
  /// are not shown).
  List<Widget> _extraRows(Widget Function(String title, String value, {Key? key}) info) {
    final churches = ref.watch(churchesProvider).valueOrNull ?? const <Church>[];
    final churchNames = {
      for (final c in churches)
        if (c.id != null) c.id!: c.name,
    };
    return [
      for (final f in ref.watch(personListExtraFieldsProvider))
        if (_additional[f.id] != null && !_defaulted.contains(f.id))
          if (formatExtraFieldValue(_additional, f, churchNames: churchNames).trim() case final v when v.isNotEmpty)
            info(f.name, v),
    ];
  }
}
