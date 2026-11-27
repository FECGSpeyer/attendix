import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/attendance_detail_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart' show attendanceTypesProvider;
import '../../../../data/models/attendance/attendance.dart' show AttendanceType;
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart' show missingGroupsPlayerCountsProvider;
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/utils/plan_beamer.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/archived_attendance.dart';
import '../../../../core/services/plan_export_service.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/team_org/team_org.dart' show AgendaItem, ProtocolAttendance, ProtocolType;
import '../../../team_organization/team_org_utils.dart' show planWithTopics;
import '../../../team_organization/presentation/widgets/agenda_picker_sheet.dart';
import '../widgets/plan_export_actions.dart';
import '../widgets/plan_field_dialogs.dart';
import '../widgets/plan_song_helper.dart';
import '../widgets/rd_plan_start.dart';
import '../widgets/rd_plan_widgets.dart';
import '../widgets/register_plan_sheet.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/providers/branding_providers.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/route_leave_guard.dart';
import '../../../../data/repositories/plan_repository.dart';
import '../../../../core/services/offline_queue_service.dart' show rootScaffoldMessengerKey;
import '../../../../core/config/supabase_config.dart' show currentAuthUserIdProvider;
import '../../../../core/services/planning_draft_store.dart';
import '../../../../core/services/register_plan_service.dart';
import '../../data/planning_write_sync.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../attendance/presentation/widgets/songs_selection_sheet.dart' show SongHistoryEntry, SongHistoryEntryExtension;
import '../../../redesign/data/providers/rd_event_works_providers.dart';
import '../../../redesign/data/rd_event_works_sync.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart' show RdFieldRow, rdInputDecoration;
import '../../../redesign/presentation/widgets/event/rd_plan_take_over.dart';
import '../../../redesign/presentation/widgets/today/rd_today_common.dart' show RdInfoCard;

part 'planning_page_beta.dart';
part 'planning_page_beta_timeline.dart';
part 'planning_page_beta_actions.dart';
part 'planning_page_beta_quick_add.dart';
part 'planning_page_beta_widgets.dart';
part 'planning_page_drafts.dart';
part 'planning_page_operations.dart';
part 'planning_page_persistence.dart';

/// Provider for songs list (for adding to plan)
final planSongsProvider = FutureProvider<List<Song>>((ref) async {
  // Wait for the song source tenant (Werk-Synchronisierung) first.
  await ref.watch(songTenantSettingsProvider.future);
  // Reloads after Werke moved between Sammlungen ("planbar").
  ref.watch(songCollectionChangesProvider);
  final repo = ref.watch(songRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getSongs();
});

/// SOL_FIX29: a plan list operation: gets the newest stored row, its plan
/// list (days written out, may be changed in place) and the position of the
/// plan the operation acts on (null when adding); returns the new list and
/// the position of the plan to open, or null for "no change".
typedef _PlanListOp = ({List<Plan> plans, int open})? Function(PlanAttendance att, List<Plan> plans, int? index);

/// SOL_FIX30: identity of a plan in the editor's copy of a Termin: its id
/// ([key]); for a plan without id (Ionic stores the main plan without one)
/// its position (`i<n>`) plus the plan count and the plan itself (JSON) in
/// that copy, see [_PlanningPageState._indexOfRef].
typedef _PlanRef = ({String key, int count, String? json});

/// ABL-01: opens the Ablaufplan editor from inside the app via `/planning`.
Future<bool?> openPlanningEditor(BuildContext context, {int? attendanceId, int? planIndex}) {
  final query = [
    if (attendanceId != null) 'attendanceId=$attendanceId',
    if (planIndex != null && planIndex > 0) 'plan=$planIndex',
  ].join('&');
  return context.push<bool>(query.isEmpty ? '/planning' : '/planning?$query');
}

/// Ablaufplan editor of a Termin (Ionic `PlanningPage`).
///
/// Supports several plans per Termin (`attendance.extra_plans`), Programmblöcke,
/// block templates, org templates / default fields, share links and the
/// org plan flag.
class PlanningPage extends ConsumerStatefulWidget {
  const PlanningPage({super.key, this.attendanceId, this.initialPlanIndex});

  final int? attendanceId;

  /// Plan to open first when the Termin has several. Null or out of range
  /// (SOL_FIX22: also negative) opens the first plan.
  final int? initialPlanIndex;

  @override
  ConsumerState<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends ConsumerState<PlanningPage> {
  List<PlanAttendance> _attendances = [];
  int? _attId;
  int _planIndex = 0;
  String _time = '17:50';
  List<PlanField> _fields = [];
  final _titleController = TextEditingController();
  bool _sharePlan = false;
  bool _isOrgPlan = false;
  bool _loaded = false;

  /// [_init] has chosen the start Termin (or found none). Until then the
  /// page shows its loading state instead of the editor, since edits made
  /// before would be replaced by the loaded plan.
  bool _started = false;

  /// Ionic 4.17.10: the organisation is linked to the Gemeinde App, so every
  /// row gets a stable uid when the plan is stored (kept from the last build,
  /// also used by [_flushOnDispose]).
  bool _gemeindeAppLinked = false;

  /// SOL_FIX2: the explicitly requested Termin could not be loaded. The
  /// editor then shows an error and never falls back to another Termin.
  bool _requestedNotFound = false;
  bool _hasChanges = false;

  /// SOL_FIX22: the editor holds changes that are not stored yet. `_save()`
  /// only writes when this is set (or the title differs from [_savedTitle]),
  /// so leftovers in the editor (e.g. after the last plan was deleted) are
  /// never written back as a plan.
  bool _dirty = false;

  /// Title as last loaded / saved (dirty check for the title field).
  String _savedTitle = '';
  Timer? _saveTimer;

  /// SOL_FIX23: every write of the attendance row runs only after the
  /// previous one finished, so an older editor state or an older copy of
  /// `extra_plans` can never be written last.
  /// SOL_FIX27: the chain is process-wide per (tenant, Termin)
  /// ([PlanningWriteSync]), shared by every editor instance.
  final int _instanceNo = PlanningWriteSync.newInstance();

  /// SOL_FIX27: per Termin the commit sequence number this editor knows
  /// (its load, then its own last commit). A write queued by [dispose] is
  /// skipped when a later editor committed after it.
  final Map<int, int> _knownSeq = {};

  /// SOL_FIX23: bumped on every edit; a finished write only clears `_dirty`
  /// when nothing was edited since its snapshot.
  int _editGen = 0;

  /// SOL_FIX23: bumped whenever the editor loads another plan / Termin; a
  /// finished write never touches the baseline of a newly loaded plan.
  int _loadGen = 0;

  /// SOL_FIX23: a close is waiting for the pending writes.
  bool _closing = false;

  /// SOL_FIX24: [_editGen] when the open plan was loaded. Only edits made
  /// after that (not the auto-created default plan) block leaving the plan
  /// while it is invalid.
  int _loadEditGen = 0;

  /// SOL_FIX24: a multi-step plan operation (add / rename / move / delete a
  /// plan, Tagesordnung picker) is writing and reloading the editor. The page
  /// is blocked meanwhile, so no edit can be made that the reload would drop.
  bool _busy = false;

  /// SOL_FIX25: captured while mounted, so the shell's leave guard can be
  /// removed and pending edits can still be written in [dispose] (no `ref`).
  late final RouteLeaveGuardRegistry _leaveGuards;
  late final ProviderContainer _container;
  PlanRepository? _disposeRepo;

  /// SOL_FIX26: a write succeeded since the caches were last invalidated;
  /// every exit path (close, shell leave guard, dispose) invalidates them.
  bool _needsInvalidate = false;

  /// SOL_FIX26: Termine written since the last invalidation.
  final Set<int> _writtenAttIds = {};

  /// SOL_FIX26: tenant of the local drafts (captured with [_disposeRepo]).
  int? _tenantId;

  /// SOL_FIX27: signed-in account the editor (and its drafts) belong to.
  String? _userId;

  /// SOL_FIX26: draft restored into the editor; removed once it is stored.
  /// SOL_FIX27: only while it still holds the restored revision.
  ({String key, int? rev})? _restoredDraft;

  /// SOL_FIX26: captured while mounted, so a failed write queued by
  /// [dispose] can still show a toast.
  ScaffoldMessengerState? _messenger;

  /// REDESIGN (Beta editor, [_PlanningBeta]): collapsed blocks and the row
  /// whose duration field is open.
  final Set<String> _rdCollapsed = {};

  /// Beta: the load ([_loadGen]) whose plan showed the Überschrift field;
  /// it then stays until another plan is loaded, also when emptied.
  int? _rdHeadingGen;
  int? _rdDurationIndex;

  /// REDESIGN: the open block whose head is being dragged; its Unterpunkte
  /// fold into the head meanwhile, so the block moves as one card.
  String? _rdDragBlock;

  /// REDESIGN: counts drag starts, so a delayed unfold of an earlier drag
  /// never ends a newer one (see `_rdDragCancel`).
  int _rdDragGen = 0;

  /// REDESIGN: live drop target while an item is dragged. The rows' places
  /// at the drag start (in list coordinates) and the gap index as the list
  /// computes it, so the block the item would join ([_rdHotBlock]) lights
  /// up before the drop (see `_rdDragHover`).
  final GlobalKey _rdListKey = GlobalKey();
  final Map<String, GlobalKey> _rdSlotKeys = {};
  List<GlobalKey> _rdSlotOrder = const [];
  List<Rect>? _rdDragRects;
  int? _rdDragFrom;
  int _rdDragInsert = 0;
  double _rdDragOffset = 0;
  Offset? _rdPointerDown;
  String? _rdHotBlock;

  /// REDESIGN: the "Tipp auf die Dauer …" hint was dismissed with
  /// "Verstanden" (null while the preference loads: no flash).
  bool? _rdHintHidden;

  @override
  void initState() {
    super.initState();
    _rdLoadHint();
    _leaveGuards = ref.read(routeLeaveGuardRegistryProvider);
    _leaveGuards.add(_onLeave);
    _container = ProviderScope.containerOf(context, listen: false);
    _disposeRepo = ref.read(planRepositoryWithTenantProvider);
    _tenantId = ref.read(currentTenantIdProvider);
    _userId = ref.read(currentAuthUserIdProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _leaveGuards.remove(_onLeave);
    _saveTimer?.cancel();
    _flushOnDispose();
    // SOL_FIX26: after every queued write (also the one above), refresh the
    // caches when anything was stored, even without pending edits.
    final attId = _attId;
    if (attId == null) {
      _invalidateCaches();
    } else {
      unawaited(_serialised(attId, () async => _invalidateCaches()));
    }
    _titleController.dispose();
    super.dispose();
  }

  /// SOL_FIX25: shell tab switch (`context.go`, no `PopScope`): like the
  /// close button, wait for running writes and store pending edits; stay on
  /// the page while busy, when a write failed or the plan is invalid.
  Future<bool> _onLeave() async {
    if (!mounted) return true;
    if (_closing || _busy) return false;
    _closing = true;
    final bool ok;
    try {
      ok = await _flushSaves();
    } finally {
      _closing = false;
    }
    if (ok) _invalidateCaches();
    return ok;
  }

  /// SOL_FIX25: the page goes away without the close / leave flow (deep
  /// link, browser back, tenant switch): queue the pending edits behind the
  /// running writes instead of dropping them. Uses only what was captured
  /// while mounted. Like Ionic `saveOpenPlan`, an invalid plan is not stored.
  ///
  /// SOL_FIX27: the write is queued on the process-wide chain of the Termin
  /// and only runs for the account that made the edit. When an editor opened
  /// later has stored the Termin meanwhile, this older snapshot is not
  /// written (the later editor's write wins, see [PlanningWriteSync]); its
  /// draft stays only if it differs from what the later editor stored.
  void _flushOnDispose() {
    final attId = _attId;
    final repo = _disposeRepo;
    if (attId == null || repo == null || !_hasPendingChanges) return;
    final time = _time;
    final fields = _withFieldUids([..._fields]);
    final title = _titleController.text.trim();
    final planIndex = _planIndex;
    if (PlanUtils.validate(time, fields) != PlanValidation.ok) return;
    // SOL_FIX27: signed out or another account meanwhile: neither a write
    // nor a draft (the edit belongs to the previous account). Without a
    // signed-in user there is no draft ([_draftKey] is null).
    final userId = _userId;
    if (_authUserId() != userId) return;
    final syncKey = PlanningWriteSync.keyFor(_tenantId, attId);
    final knownSeq = _knownSeq[attId] ?? 0;
    // SOL_FIX26: the editor is gone, so the edit is kept as a local draft
    // until the write is confirmed; a failed write shows a toast and the
    // draft is restored the next time this plan is opened.
    final planKey = _planKeyOf(_att, planIndex);
    final draftKey = _draftKey(attId, planKey, userId);
    final draft = _draftData(time: time, fields: fields, title: title);
    // SOL_FIX31: with the stored version it was made from ([_restoreDraft]).
    final draftRev = PlanningDraftStore.write(draftKey, {...draft, 'base': _baseOf(_att, planIndex)},
        allowed: () => _authUserId() == userId);
    unawaited(PlanningWriteSync.run(syncKey, () async {
      final rev = await draftRev;
      if (_authUserId() != userId) return;
      final newer = PlanningWriteSync.newerCommit(syncKey, _instanceNo, knownSeq);
      if (newer != null) {
        final stored = _planByKey(newer, planKey);
        if (stored != null && _sameDraft(_draftOfPlan(stored), draft)) {
          await PlanningDraftStore.removeIfRevision(draftKey, rev);
          return;
        }
        // SOL_FIX30: the later editor stored something else (or the plan is
        // gone): this edit is not written. Tell the user whether it is kept
        // as a confirmed local draft or lost.
        final deleted = stored == null && !_isPositionalKey(planKey);
        _showDetachedError(deleted
            ? (rev != null
                ? l10nWithoutContext.planningFlutterPlanDeletedDraftSaved
                : l10nWithoutContext.planningFlutterPlanDeletedDraftLost)
            : (rev != null
                ? l10nWithoutContext.planningFlutterPlanChangedDraftSaved
                : l10nWithoutContext.planningFlutterPlanChangedDraftLost));
        return;
      }
      // Built when the write starts: `_att` is the latest persisted row (it
      // is still replaced after every write that finishes after dispose).
      final att = _att;
      if (att?.id != attId) return;
      // SOL_FIX28: on top of the newest stored row of the Termin.
      final base = _writeBase(attId, att!, planIndex);
      final baseIndex = base.index;
      if (baseIndex == null) {
        // SOL_FIX29: the plan was deleted meanwhile: never restore it. The
        // edit stays as the local draft written above (when confirmed).
        final changed = _isPositionalKey(planKey);
        _showDetachedError(await draftRev != null
            ? (changed
                ? l10nWithoutContext.planningFlutterPlanChangedDraftSaved
                : l10nWithoutContext.planningFlutterPlanDeletedDraftSaved)
            : (changed
                ? l10nWithoutContext.planningFlutterPlanChangedDraftLost
                : l10nWithoutContext.planningFlutterPlanDeletedDraftLost));
        return;
      }
      final saved = await repo.updateAttendancePlanFields(
          attId, _planUpdate(base.att, baseIndex, time: time, fields: fields, title: title));
      _markWritten(attId, saved);
      await PlanningDraftStore.removeIfRevision(draftKey, rev);
    }).catchError((Object _) async {
      // SOL_FIX28: "Entwurf lokal gesichert" only for a confirmed draft;
      // otherwise the edit is really lost and the user is told so.
      final kept = await draftRev != null;
      _showDetachedError(kept
          ? l10nWithoutContext.planningFlutterDraftSavedLocally
          : l10nWithoutContext.planningFlutterDraftLost);
    }));
  }

  /// `setState` bridge for extension parts.
  void _rdSet(VoidCallback fn) => setState(fn);

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final attendancesAsync = ref.watch(planAttendancesProvider);
    final typesAsync = ref.watch(planAttendanceTypesProvider);
    ref.watch(planSongsProvider);
    // Loaded for the Werk picker (Werke of a Sammlung that is not "planbar").
    ref.watch(songCollectionsProvider);
    ref.watch(currentSongsProvider);
    ref.watch(groupsProvider);
    ref.watch(groupCategoriesProvider);
    ref.watch(missingGroupsPlayerCountsProvider); // "Ohne …" redraws once the counts are there
    ref.watch(protocolTypesProvider); // PROTOCOL: keeps the protocol settings loaded
    final blockTemplates = ref.watch(planBlockTemplatesProvider).valueOrNull ?? const <PlanBlockTemplate>[];
    final role = ref.watch(effectiveRoleProvider);
    final org = ref.watch(currentOrganisationProvider).valueOrNull;
    _gemeindeAppLinked = PlanBeamer.gemeindeAppLinked(org);
    // Ionic 4.17.10 `showBeamer`: linked org, setting on, ORG plan.
    final showBeamer = PlanBeamer.active(org, _isOrgPlan);

    // SOL_FIX26: not from the previous value while the Termine reload after
    // an invalidation (that would edit the stale plan).
    // Ionic ngOnInit loads Werke and history before choosing the start plan
    // (the type template only applies with history); the role decides
    // whether archived Termine can be opened.
    final startReady = !ref.watch(currentSongsProvider).isLoading &&
        !ref.watch(planSongsProvider).isLoading &&
        !ref.watch(currentTenantUserProvider).isLoading;
    if (!_loaded && startReady && attendancesAsync.hasValue && !attendancesAsync.isLoading && !typesAsync.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loaded) unawaited(_init(attendancesAsync.value!));
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _closing || _busy) return;
        // SOL_FIX23: close waits for running writes and stays open when a
        // write failed (toast shown, changes kept for a retry).
        _closing = true;
        final ok = await _flushSaves();
        _closing = false;
        if (!ok || !mounted) return;
        _invalidateCaches();
        if (context.mounted) Navigator.of(context).pop(_hasChanges);
      },
      // SOL_FIX24: blocked while a multi-step plan operation runs.
      child: Stack(children: [
        ExcludeFocus(
          excluding: _busy,
          child: AbsorbPointer(
            absorbing: _busy,
            child: _rdScaffold(
              attendancesAsync,
              isAdmin: role.isAdmin,
              blockTemplates: blockTemplates,
              showBeamer: showBeamer,
            ),
          ),
        ),
        if (_busy)
          const Positioned.fill(
            key: ValueKey('planning-busy'),
            child: ColoredBox(color: Colors.black26, child: Center(child: AppSpinner())),
          ),
      ]),
    );
  }
}
