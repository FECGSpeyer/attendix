import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/person_detail_providers.dart' show duplicateCandidatesProvider, personProvider;
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/design_theme.dart';
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
import '../../person_write.dart';
import '../widgets/parent_review_hint.dart';
import '../../../settings/presentation/widgets/manage/manage_list.dart' show rdLoadedValue;
import '../../../settings/presentation/widgets/manage/settings_sheets.dart';
import '../widgets/members/person_form.dart' show applyPersonColumns;
import '../../../../shared/widgets/components/components.dart';
import '../../../today/presentation/widgets/today_common.dart' show RdInfoCard, RdLinkButton;

part 'pending_review_cards.dart';

/// Verwaltung › Freigaben › "Anfrage prüfen" (for Admins and Verantwortliche).
/// Shows duplicate-merge hints, registration details (only the group can be
/// edited before approval), and Approve / Decline actions bound to the
/// tenant that opened the page.
class RdPendingReviewPage extends ConsumerStatefulWidget {
  const RdPendingReviewPage({super.key, required this.personId, this.fromMembers = false});

  /// Opened from the Mitglieder tab or a person: the page lives in that tab
  /// and leads back to it.
  final bool fromMembers;

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
      GoRouter.of(context).go(widget.fromMembers ? RedesignRoutes.members : RedesignRoutes.approvals);
    }
  }

  void _refresh(int id) {
    _container.invalidate(personProvider(id));
    _container.invalidate(realtimePlayersProvider);
    // "Wartet" and its counters read this list. Without this they only
    // change once the live update arrives, which can be late or missing.
    _container.invalidate(realtimePendingPlayersProvider);
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
      ToastHelper.showSuccess(context, l10n.rdTextPendingAccepted(person.firstName.trim().isEmpty ? person.lastName : person.firstName.trim()));
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
      ToastHelper.showSuccess(context, l10n.rdTextPendingDeclined);
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
      _container.invalidate(realtimePendingPlayersProvider);
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
      label: widget.fromMembers ? l10n.redesignTabMembers : l10n.redesignManagePendingTitle,
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
}
