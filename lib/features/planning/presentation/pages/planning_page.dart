import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/attendance_detail_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/team_org_providers.dart'; // PROTOCOL
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/plan_export_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/team_org/team_org.dart' show ProtocolAttendance; // PROTOCOL
import '../../../team_organization/presentation/widgets/agenda_picker_sheet.dart'; // PROTOCOL
import '../widgets/plan_export_actions.dart';
import '../widgets/plan_field_dialogs.dart';
import '../widgets/plan_fields_editor.dart';
import '../widgets/plan_song_helper.dart';
import '../widgets/plan_view_list.dart';
import '../widgets/ion_items.dart';
import '../widgets/register_plan_sheet.dart';
import '../../../../l10n/l10n.dart';
import '../../../songs/presentation/utils/song_utils.dart';
import '../../../../core/providers/branding_providers.dart'; // MISC2
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2
import 'package:attendix/shared/widgets/layout/route_leave_guard.dart'; // SOL_FIX25
import '../../../../data/repositories/plan_repository.dart'; // SOL_FIX25
import '../../../../core/services/offline_queue_service.dart' show rootScaffoldMessengerKey; // SOL_FIX26
import '../../../../core/config/supabase_config.dart' show currentAuthUserIdProvider; // SOL_FIX27
import '../../../../core/services/planning_draft_store.dart'; // SOL_FIX27
import '../../data/planning_write_sync.dart'; // SOL_FIX27

/// Provider for songs list (for adding to plan)
final planSongsProvider = FutureProvider<List<Song>>((ref) async {
  // Wait for the song source tenant (Werk-Synchronisierung) first.
  await ref.watch(songTenantSettingsProvider.future);
  final repo = ref.watch(songRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getSongs();
});

/// SOL_FIX29: a plan list operation: gets the newest stored row, its plan
/// list (days written out, may be changed in place) and the position of the
/// plan the operation acts on (null when adding); returns the new list and
/// the position of the plan to open, or null for "no change".
typedef _PlanListOp = ({List<Plan> plans, int open})? Function(PlanAttendance att, List<Plan> plans, int? index);

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
  OverlayState? _rootOverlay;
  bool _iosLook = false;

  @override
  void initState() {
    super.initState();
    _leaveGuards = ref.read(routeLeaveGuardRegistryProvider);
    _leaveGuards.add(_onLeave);
    _container = ProviderScope.containerOf(context, listen: false);
    _disposeRepo = ref.read(planRepositoryWithTenantProvider);
    _tenantId = ref.read(currentTenantIdProvider);
    _userId = ref.read(currentAuthUserIdProvider); // SOL_FIX27
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
    _rootOverlay = Overlay.maybeOf(context, rootOverlay: true);
    _iosLook = useIosLook(context);
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
    final fields = [..._fields];
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
    final draftRev = PlanningDraftStore.write(draftKey, draft, allowed: () => _authUserId() == userId);
    unawaited(PlanningWriteSync.run(syncKey, () async {
      final rev = await draftRev;
      if (_authUserId() != userId) return;
      final newer = PlanningWriteSync.newerCommit(syncKey, _instanceNo, knownSeq);
      if (newer != null) {
        final stored = _planByKey(newer, planKey);
        if (stored != null && _sameDraft(_draftOfPlan(stored), draft)) {
          await PlanningDraftStore.removeIfRevision(draftKey, rev);
        }
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
        _showDetachedError(await draftRev != null
            ? l10nWithoutContext.planningFlutterPlanDeletedDraftSaved
            : l10nWithoutContext.planningFlutterPlanDeletedDraftLost);
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

  // ---------------------------------------------------------------------------
  // SOL_FIX26: local drafts of edits whose write failed after leaving
  // ---------------------------------------------------------------------------

  /// SOL_FIX27: signed-in account right now (null when signed out).
  String? _authUserId() {
    try {
      return _container.read(currentAuthUserIdProvider);
    } catch (_) {
      return null;
    }
  }

  /// Stable part of a plan in the draft key: its id, else its position.
  static String _planKeyOf(PlanAttendance? att, int planIndex) {
    final plans = PlanUtils.allPlans(att);
    final id = planIndex < plans.length ? plans[planIndex].id : null;
    return (id?.isNotEmpty ?? false) ? id! : 'i$planIndex';
  }

  /// SOL_FIX27: plan of [att] that [planKey] ([_planKeyOf]) names.
  static Plan? _planByKey(PlanAttendance att, String planKey) {
    final i = _indexOfPlanKey(att, planKey);
    return i == null ? null : PlanUtils.allPlans(att)[i];
  }

  /// SOL_FIX28: position of the plan of [att] that [planKey] names (by id,
  /// else by position); null when there is none.
  static int? _indexOfPlanKey(PlanAttendance att, String planKey) {
    final plans = PlanUtils.allPlans(att);
    final byId = plans.indexWhere((p) => p.id == planKey);
    if (byId >= 0) return byId;
    final index = RegExp(r'^i(\d+)$').firstMatch(planKey)?.group(1);
    final i = index == null ? null : int.tryParse(index);
    return i != null && i < plans.length ? i : null;
  }

  /// SOL_FIX28: row and plan position a write of plan [planIndex] of the
  /// editor's copy [own] builds on. When an editor instance (this one
  /// excluded) stored Termin [attId] after the last commit this editor knows,
  /// the write builds on that newest stored row ([PlanningWriteSync.
  /// latestSince]): the edited plan is found there by id (else position) and
  /// only it is replaced, every other plan stays as stored. Without a newer
  /// commit the editor's own copy.
  ///
  /// SOL_FIX29: when the edited plan no longer exists in the newest stored
  /// row (another editor deleted it), the result is that row with a null
  /// index: a conflict. The caller writes nothing (the old row would restore
  /// the deleted plan and reset every other change made since) and keeps
  /// the edit as a local draft.
  ({PlanAttendance att, int? index}) _writeBase(int attId, PlanAttendance own, int planIndex) {
    final latest =
        PlanningWriteSync.latestSince(PlanningWriteSync.keyFor(_tenantId, attId), _knownSeq[attId] ?? 0);
    if (latest == null || latest.id != attId) return (att: own, index: planIndex);
    final index = _indexOfPlanKey(latest, _planKeyOf(own, planIndex));
    if (index != null) return (att: latest, index: index);
    if (PlanUtils.allPlans(latest).isEmpty && PlanUtils.allPlans(own).isEmpty) return (att: latest, index: 0);
    return (att: latest, index: null);
  }

  /// SOL_FIX29: takes over [latest], the newest stored row of Termin [attId]
  /// (returned by [PlanningWriteSync.latestSince] right before, so row and
  /// sequence number are adopted together), and shows one of its plans: the
  /// plan at the open position, else the last one, else the empty editor.
  /// Used when the open plan was deleted by another editor meanwhile.
  void _reloadLatest(int attId, PlanAttendance latest) {
    _knownSeq[attId] = PlanningWriteSync.seq(PlanningWriteSync.keyFor(_tenantId, attId));
    _replaceAtt(latest);
    if (!mounted || _attId != attId) return;
    final plans = PlanUtils.allPlans(latest);
    if (plans.isEmpty) {
      _clearEditor(latest);
      return;
    }
    final index = _planIndex.clamp(0, plans.length - 1);
    setState(() => _planIndex = index);
    _loadPlan(latest, plans[index]);
  }

  /// SOL_FIX29: the plan [planKey] of Termin [attId] was deleted by another
  /// editor meanwhile. Keeps [draft] (the edits of that plan that could not
  /// be written, if any) as a confirmed local draft and tells the user.
  Future<void> _planDeletedMeanwhile(int attId, String planKey, Map<String, dynamic>? draft) async {
    if (draft == null) {
      if (mounted) ToastHelper.showWarning(context, context.l10n.planningFlutterPlanDeleted);
      return;
    }
    final userId = _userId;
    final rev = await PlanningDraftStore.write(_draftKey(attId, planKey, userId), draft,
        allowed: () => _authUserId() == userId);
    if (!mounted) {
      _showDetachedError(rev != null
          ? l10nWithoutContext.planningFlutterPlanDeletedDraftSaved
          : l10nWithoutContext.planningFlutterPlanDeletedDraftLost);
    } else if (rev != null) {
      ToastHelper.showWarning(context, context.l10n.planningFlutterPlanDeletedDraftSaved);
    } else {
      ToastHelper.showError(context, context.l10n.planningFlutterPlanDeletedDraftLost);
    }
  }

  /// SOL_FIX28: takes over the newest row another editor instance stored for
  /// Termin [attId] (when this editor has not seen it yet), so a plan
  /// operation (add / rename / day / move / delete), which writes the whole
  /// plan list, builds on it instead of the editor's stale copy.
  ///
  /// SOL_FIX29: false when the open plan was deleted there meanwhile: the
  /// editor then shows the newest row ([_reloadLatest]), pending edits of the
  /// deleted plan are kept as a draft and the operation must not continue.
  bool _adoptLatest(int attId) {
    final key = PlanningWriteSync.keyFor(_tenantId, attId);
    final latest = PlanningWriteSync.latestSince(key, _knownSeq[attId] ?? 0);
    if (latest == null || latest.id != attId) return true;
    final own = _att;
    final planKey = _planKeyOf(own, _planIndex);
    final index = own == null ? null : _indexOfPlanKey(latest, planKey);
    if (index == null && PlanUtils.allPlans(own).isNotEmpty) {
      final draft = _hasPendingChanges
          ? _draftData(time: _time, fields: _fields, title: _titleController.text.trim())
          : null;
      _reloadLatest(attId, latest);
      unawaited(_planDeletedMeanwhile(attId, planKey, draft));
      return false;
    }
    _knownSeq[attId] = PlanningWriteSync.seq(key);
    _replaceAtt(latest);
    if (index != null && index != _planIndex && mounted) setState(() => _planIndex = index);
    return true;
  }

  /// SOL_FIX27: draft key of the account [userId] in the editor's tenant
  /// (null without user or tenant: no draft).
  String? _draftKey(int attId, String planKey, String? userId) =>
      PlanningDraftStore.keyFor(userId: userId, tenantId: _tenantId, attId: attId, planKey: planKey);

  static Map<String, dynamic> _draftData(
          {required String time, required List<PlanField> fields, required String title}) =>
      jsonDecode(jsonEncode({
        'time': time,
        'title': title,
        'fields': [for (final f in fields) f.toJson()],
      })) as Map<String, dynamic>;

  static Map<String, dynamic> _draftOfPlan(Plan plan) =>
      _draftData(time: PlanUtils.formatTime(plan.time), fields: plan.fields, title: plan.title ?? '');

  static bool _sameDraft(Map<String, dynamic> a, Map<String, dynamic> b) => jsonEncode(a) == jsonEncode(b);

  /// Restores the draft of the plan that was just loaded, when one exists
  /// and differs from it: the editor takes it over as a pending (dirty)
  /// change, so it is saved again by the autosave.
  ///
  /// SOL_FIX27: only the signed-in account's own draft, and only while that
  /// account is still signed in when the draft was read.
  Future<void> _restoreDraft(int attId, int planIndex) async {
    final userId = _authUserId();
    final key = _draftKey(attId, _planKeyOf(_att, planIndex), userId);
    if (key == null) return;
    final loadGen = _loadGen;
    final editGen = _editGen;
    final stored = await PlanningDraftStore.read(key);
    // Another plan was loaded or the user already edited: keep the draft.
    if (stored == null || !mounted || loadGen != _loadGen || editGen != _editGen) return;
    if (_authUserId() != userId) return;
    try {
      final draft = stored.data;
      final fields = [
        for (final f in draft['fields'] as List) PlanField.fromJson(Map<String, dynamic>.from(f as Map)),
      ];
      final t = PlanUtils.formatTime(draft['time'] as String?);
      final time = t.isNotEmpty ? t : _time;
      final title = draft['title'] as String? ?? '';
      final restored = _draftData(time: time, fields: fields, title: title);
      final loaded = _draftData(time: _time, fields: _fields, title: _titleController.text.trim());
      if (_sameDraft(restored, loaded)) {
        await PlanningDraftStore.removeIfRevision(key, stored.rev);
        return;
      }
      setState(() {
        _time = time;
        _fields = fields;
        _titleController.text = title;
      });
      _restoredDraft = (key: key, rev: stored.rev);
      _changed();
      ToastHelper.showInfo(context, context.l10n.planningFlutterDraftRestored);
    } catch (_) {
      await PlanningDraftStore.removeIfRevision(key, stored.rev);
    }
  }

  /// Toast without a mounted page (root overlay / messenger captured while
  /// mounted), like [ToastHelper.showError].
  void _showDetachedError(String message) {
    try {
      final overlay = _rootOverlay;
      if (!_iosLook && overlay != null && overlay.mounted) {
        showIonMdToast(overlay, message, color: AppColors.danger);
        return;
      }
      final captured = _messenger;
      final messenger = captured != null && captured.mounted ? captured : rootScaffoldMessengerKey.currentState;
      messenger?.showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
        ]),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      // App already closed.
    }
  }

  /// Update of the `attendance` row that stores plan [planIndex] of [att]
  /// with the given editor state (Ionic `updateAttendance` /
  /// `splitPlans`).
  static Map<String, dynamic> _planUpdate(
    PlanAttendance att,
    int planIndex, {
    required String time,
    required List<PlanField> fields,
    required String title,
  }) {
    final plans = PlanUtils.allPlans(att);
    final base = planIndex < plans.length ? plans[planIndex] : const Plan();
    final current = base.copyWith(
      time: time,
      end: PlanUtils.computeEndIso(time, fields),
      fields: fields,
      title: title.isEmpty ? null : title,
    );
    if (plans.length < 2) return {'plan': current.toJson()};
    plans[planIndex] = current;
    return PlanUtils.splitPlans(plans);
  }

  PlanAttendance? get _att => _attendances.where((a) => a.id == _attId).firstOrNull;

  List<PlanAttendanceType> get _types => ref.read(planAttendanceTypesProvider).valueOrNull ?? const [];

  PlanAttendanceType? _typeOf(PlanAttendance? att) =>
      att?.typeId == null ? null : _types.where((t) => t.id == att!.typeId).firstOrNull;

  /// Ionic `calculateEnd`: stored as "YYYY-MM-DDTHH:mm".
  String get _end => PlanUtils.computeEndIso(_time, _fields);

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  Future<void> _init(List<PlanAttendance> attendances) async {
    _loaded = true;
    _attendances = [...attendances];
    // SOL_FIX25: the repository (tenant) the Termine were loaded with.
    _disposeRepo = ref.read(planRepositoryWithTenantProvider);
    _tenantId = ref.read(currentTenantIdProvider); // SOL_FIX26
    _userId = ref.read(currentAuthUserIdProvider); // SOL_FIX27
    // SOL_FIX29: the cached rows hold the commits up to the last cache
    // refresh; newer commits are adopted when a Termin is loaded.
    for (final a in _attendances) {
      if (a.id != null) _knownSeq[a.id!] = PlanningWriteSync.refreshedSeq(PlanningWriteSync.keyFor(_tenantId, a.id!));
    }
    PlanAttendance? att;
    final requestedId = widget.attendanceId;
    if (requestedId != null) {
      att = _attendances.where((a) => a.id == requestedId).firstOrNull;
      // SOL_FIX2: a Termin outside the loaded season is loaded by id
      // (tenant-filtered); never edit another Termin instead.
      if (att == null) {
        // SOL_FIX29: fetched now, so it holds every commit made before.
        final seqBefore = PlanningWriteSync.seq(PlanningWriteSync.keyFor(_tenantId, requestedId));
        att = await _loadRequestedAttendance(requestedId);
        if (att != null) _knownSeq[requestedId] = seqBefore;
      }
      if (!mounted) return;
      if (att == null) {
        setState(() => _requestedNotFound = true);
        return;
      }
      if (!_attendances.any((a) => a.id == att!.id)) {
        _attendances = [..._attendances, att]..sort((a, b) => b.date.compareTo(a.date));
      }
      _loadAttendance(att, planIndex: widget.initialPlanIndex);
      return;
    }
    // No Termin requested: first upcoming Termin (list is sorted newest first).
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final upcoming = _attendances.where((a) {
      final d = DateTime.tryParse(a.date);
      return d != null && !DateTime(d.year, d.month, d.day).isBefore(todayDate);
    }).toList();
    att = upcoming.isNotEmpty ? upcoming.last : _attendances.firstOrNull;
    if (att != null) {
      _loadAttendance(att);
    } else {
      setState(() {});
    }
  }

  /// Requested Termin by id, scoped to the current tenant; null when it does
  /// not exist, belongs to another tenant or could not be loaded.
  Future<PlanAttendance?> _loadRequestedAttendance(int id) async {
    try {
      final repo = ref.read(planRepositoryWithTenantProvider);
      if (!repo.hasTenantId) return null;
      return await repo.getPlanAttendanceById(id);
    } catch (_) {
      return null;
    }
  }

  /// Ionic `Utils.getPlanningTitle`.
  String _defaultTitle(PlanAttendance? att) {
    final type = _typeOf(att);
    final info = att?.typeInfo ?? '';
    final pt = type?.planningTitle ?? '';
    if (pt.isNotEmpty && info.isNotEmpty) return '$pt ($info)';
    if (pt.isNotEmpty) return pt;
    if (info.isNotEmpty) return info;
    if ((type?.name ?? '').isNotEmpty) return type!.name;
    return context.l10n.defaultsTypesRehearsalPlan;
  }

  /// Ionic `resolveOrgPlan`: stored flag once a plan exists, otherwise the type default.
  bool _resolveOrgPlan(PlanAttendance att) {
    if (att.plan != null) return att.isOrgPlan;
    return _typeOf(att)?.isDefaultOrgPlan ?? false;
  }

  void _loadAttendance(PlanAttendance loaded, {int? planIndex}) {
    // SOL_FIX27: the commits this editor has seen of the Termin.
    // SOL_FIX29: row and sequence number are adopted together: when another
    // editor instance stored the Termin after the commit this editor's copy
    // holds (e.g. while another Termin was open), the newest stored row is
    // loaded and only then its sequence number recorded. A stale copy is
    // never marked as current.
    var att = loaded;
    final attId = att.id;
    if (attId != null) {
      final key = PlanningWriteSync.keyFor(_tenantId, attId);
      final latest = PlanningWriteSync.latestSince(key, _knownSeq[attId] ?? 0);
      if (latest != null && latest.id == attId) {
        att = latest;
        _knownSeq[attId] = PlanningWriteSync.seq(key);
        _attendances = [for (final a in _attendances) a.id == attId ? latest : a];
      } else {
        _knownSeq[attId] ??= PlanningWriteSync.seq(key);
      }
    }
    final plans = PlanUtils.allPlans(att);
    // SOL_FIX22: `?plan=-1` (or too large) falls back to the first plan.
    final index = PlanUtils.validPlanIndex(planIndex, plans.length) ?? 0;
    setState(() {
      _attId = att.id;
      _planIndex = index;
      _sharePlan = att.sharePlan;
      _isOrgPlan = _resolveOrgPlan(att);
    });
    if (plans.isNotEmpty) {
      _loadPlan(att, plans[index]);
    } else {
      _loadGen++;
      _loadEditGen = _editGen;
      final tenant = ref.read(currentTenantProvider);
      final isPractice = att.type == 'uebung';
      final start = (att.startTime?.isNotEmpty ?? false)
          ? att.startTime!
          : (isPractice ? (tenant?.practiceStart ?? '17:50') : '10:00');
      final formatted = PlanUtils.formatTime(start);
      setState(() {
        _time = formatted.isEmpty ? '17:50' : formatted;
        _titleController.text = _defaultTitle(att);
        _fields = [PlanField(id: 'Wort', name: context.l10n.planningDefaultWord.trim(), time: '10')];
      });
      _applyTypeDefaultPlan(att, save: false);
      _savedTitle = _titleController.text.trim();
      // Ionic `onAttChange` → `calculateEnd` → `updateAttendance` stores the
      // default plan of a Termin without plan; keep it as a pending change.
      _dirty = true;
      _restoredDraft = null;
      if (att.id != null) unawaited(_restoreDraft(att.id!, index)); // SOL_FIX26
    }
  }

  void _loadPlan(PlanAttendance att, Plan plan) {
    final history = _history;
    _saveTimer?.cancel();
    _loadGen++;
    _loadEditGen = _editGen;
    _dirty = false;
    _restoredDraft = null;
    setState(() {
      _titleController.text = plan.title ?? _defaultTitle(att);
      final t = PlanUtils.formatTime(plan.time);
      if (t.isNotEmpty) _time = t;
      _fields = plan.fields.map((f) {
        var field = f;
        if ((field.conductor ?? '').isEmpty) {
          final h = history.where((h) => h.songId?.toString() == field.id).firstOrNull;
          if (h?.conductorName != null) field = field.copyWith(conductor: h!.conductorName);
        }
        if (PlanUtils.isAgendaPlaceholder(field)) field = field.copyWith(time: '0');
        return field;
      }).toList();
    });
    _savedTitle = _titleController.text.trim();
    if (att.id != null) unawaited(_restoreDraft(att.id!, _planIndex)); // SOL_FIX26
  }

  /// SOL_FIX22 / Ionic `deletePlan` → `loadPlan(att, undefined)`: after the
  /// last plan is deleted the editor is empty (default title, no fields, time
  /// kept) and holds no pending change, so closing writes nothing back.
  void _clearEditor(PlanAttendance att) {
    _saveTimer?.cancel();
    _loadGen++;
    _loadEditGen = _editGen;
    _dirty = false;
    _restoredDraft = null;
    setState(() {
      _planIndex = 0;
      _titleController.text = _defaultTitle(att);
      _fields = [];
    });
    _savedTitle = _titleController.text.trim();
  }

  List<SongHistory> get _history =>
      (ref.read(currentSongsProvider).valueOrNull ?? const []).expand((e) => e.history).toList();

  List<Song> get _songs => ref.read(planSongsProvider).valueOrNull ?? const [];

  /// Ionic `onAttChange` without plan / "Plan zurücksetzen".
  void _applyTypeDefaultPlan(PlanAttendance att, {bool save = true}) {
    final type = _typeOf(att);
    final defaults = type?.defaultPlan?.fields ?? const <PlanField>[];
    if (defaults.isNotEmpty) {
      setState(() {
        final t = PlanUtils.formatTime(type?.startTime);
        if (t.isNotEmpty) _time = t;
        _fields = PlanSongHelper.resolvePlaceholders(
          defaults,
          history: _history,
          songs: _songs,
          prefix: _songPrefix(type),
        );
      });
    } else if (save) {
      setState(() => _fields = []);
    }
    if (save) _changed();
  }

  String Function(Song song) _songPrefix(PlanAttendanceType? type) {
    final tenant = ref.read(currentTenantProvider);
    return (song) =>
        type?.planningPrefixInstanceName == true ? '${tenant?.longName ?? ''}: ' : '${song.number ?? ''}. ';
  }

  // ---------------------------------------------------------------------------
  // Saving
  // ---------------------------------------------------------------------------

  void _changed() {
    _fields = PlanUtils.normalizeGroups(_fields);
    _hasChanges = true;
    _dirty = true;
    _editGen++;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  /// Ionic `validate`: start time, at least one field, a duration on every field.
  bool _validate({bool showToast = false}) {
    switch (PlanUtils.validate(_time, _fields)) {
      case PlanValidation.ok:
        return true;
      case PlanValidation.noFields:
        if (showToast) ToastHelper.showWarning(context, context.l10n.planningChooseFieldMin);
        return false;
      case PlanValidation.missingTime:
        if (showToast) ToastHelper.showWarning(context, context.l10n.planningFillRequired);
        return false;
    }
  }

  /// Title field lost focus: only a real edit counts as a change.
  void _onTitleFocusLost() {
    if (_titleController.text.trim() != _savedTitle) _changed();
  }

  /// SOL_FIX22: true while the editor holds changes that are not stored yet.
  bool get _hasPendingChanges => _dirty || _titleController.text.trim() != _savedTitle;

  /// SOL_FIX23: runs [task] after every write queued before it. Errors
  /// reach the caller, never the chain.
  /// SOL_FIX27: on the process-wide chain of Termin [attId], shared with
  /// every other editor instance (e.g. one that was just left and still
  /// writes).
  Future<T> _serialised<T>(int attId, Future<T> Function() task) =>
      PlanningWriteSync.run(PlanningWriteSync.keyFor(_tenantId, attId), task);

  /// Ionic `saveOpenPlan`: queues a write of the open plan (when it holds
  /// valid pending changes) behind all running writes.
  ///
  /// SOL_FIX23: false only when the write failed; the editor then keeps its
  /// changes and dirty state and the Ionic error toast is shown.
  Future<bool> _save() {
    _saveTimer?.cancel();
    final attId = _attId;
    if (attId == null) return Future.value(true);
    return _serialised(attId, () => _writeOpenPlan(attId));
  }

  /// SOL_FIX24: the user edited the open plan since it was loaded.
  bool get _hasUserEdits => _editGen != _loadEditGen || _titleController.text.trim() != _savedTitle;

  /// SOL_FIX23: waits for running writes and stores everything still pending
  /// (also edits made while a write ran). Plan / Termin switches and close
  /// only continue when this returns true.
  ///
  /// SOL_FIX24: Ionic only stores a valid plan (`saveOpenPlan` → `validate`)
  /// and never coerces an empty minutes field, so invalid edits would be
  /// dropped silently on leaving. With [blockInvalid] an invalid plan with
  /// user edits shows the Ionic validation toast and returns false, so the
  /// user can fix it first.
  Future<bool> _flushSaves({bool blockInvalid = true}) async {
    while (true) {
      if (!await _save()) return false;
      if (!mounted) return true;
      if (!_hasPendingChanges || _att?.id == null) return true;
      if (!_validate()) {
        if (!blockInvalid || !_hasUserEdits) return true;
        _validate(showToast: true);
        return false;
      }
    }
  }

  /// SOL_FIX24: runs [task] with the page blocked (overlay, no focus, no
  /// close) so the editor cannot change while [task] writes and reloads it.
  Future<T> _whileBusy<T>(Future<T> Function() task) async {
    _saveTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      return await task();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _writeOpenPlan(int attId) async {
    if (!mounted || !_hasPendingChanges) return true;
    // SOL_FIX29: read before the first await (tenant of this editor).
    final repo = ref.read(planRepositoryWithTenantProvider);
    // Built when the write starts: `_att` is the latest persisted row (it is
    // replaced after every write), plus the current editor state.
    final att = _att;
    // SOL_FIX27: queued on the chain of [attId]; another Termin opened
    // meanwhile is written by its own queued save.
    if (att?.id != attId || !_validate()) return true;
    final loadGen = _loadGen;
    final editGen = _editGen;
    final title = _titleController.text.trim();
    // SOL_FIX28: built on the newest stored row of the Termin (another
    // editor instance may have stored another plan meanwhile): only the open
    // plan is replaced.
    final base = _writeBase(attId, att!, _planIndex);
    final baseIndex = base.index;
    if (baseIndex == null) {
      // SOL_FIX29: the open plan was deleted by another editor meanwhile:
      // nothing is written, the edit is kept as a local draft and the editor
      // shows the newest stored row.
      final planKey = _planKeyOf(att, _planIndex);
      final draft = _draftData(time: _time, fields: _fields, title: title);
      _reloadLatest(attId, base.att);
      await _planDeletedMeanwhile(attId, planKey, draft);
      return true;
    }
    final update = _planUpdate(base.att, baseIndex, time: _time, fields: _fields, title: title);
    try {
      final saved = await repo.updateAttendancePlanFields(att.id!, update);
      // SOL_FIX23: every successful write is a change (caches on close).
      _markWritten(att.id!, saved);
      _replaceAtt(saved);
      // Baseline / dirty only for the snapshot that was really stored.
      if (loadGen == _loadGen) {
        // SOL_FIX28: the open plan's position in the stored row.
        if (mounted && baseIndex != _planIndex) setState(() => _planIndex = baseIndex);
        _savedTitle = title;
        if (editGen == _editGen) _dirty = false;
        // SOL_FIX26: the restored draft is stored now.
        // SOL_FIX27: removed only while it still holds the restored revision.
        final draft = _restoredDraft;
        if (draft != null) {
          _restoredDraft = null;
          await PlanningDraftStore.removeIfRevision(draft.key, draft.rev);
        }
      }
      return true;
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.svcUpdateAttendanceFailed);
      return false;
    }
  }

  /// SOL_FIX29: runs the plan list operation [op] (add / rename / day / move
  /// / delete) INSIDE the queued write step of Termin [attId], applied to the
  /// newest stored row at that moment (another editor instance may have
  /// stored the Termin while this editor's dialog was open), and stores the
  /// resulting plan list. [planKey] names the plan the operation acts on (by
  /// id, else position, see [_planKeyOf]); null for adding a plan.
  ///
  /// Returns the position of the plan to open in the stored row, or null when
  /// nothing was written: [op] made no change, or the plan [planKey] was
  /// deleted meanwhile (the editor then shows the newest row and the user is
  /// told, see [_planDeletedMeanwhile]).
  Future<int?> _writePlanOp(int attId, String? planKey, _PlanListOp op) => _serialised(attId, () async {
        final repo = ref.read(planRepositoryWithTenantProvider);
        final latest =
            PlanningWriteSync.latestSince(PlanningWriteSync.keyFor(_tenantId, attId), _knownSeq[attId] ?? 0);
        final own = _att;
        final base = latest != null && latest.id == attId ? latest : own;
        if (base == null || base.id != attId) return null;
        int? index;
        if (planKey != null) {
          index = _indexOfPlanKey(base, planKey);
          if (index == null) {
            final draft = mounted && _attId == attId && _hasPendingChanges && _planKeyOf(own, _planIndex) == planKey
                ? _draftData(time: _time, fields: _fields, title: _titleController.text.trim())
                : null;
            _reloadLatest(attId, base);
            await _planDeletedMeanwhile(attId, planKey, draft);
            return null;
          }
        }
        final result = op(base, PlanUtils.withDays(base, PlanUtils.allPlans(base)), index);
        if (result == null) return null;
        final saved = await repo.updateAttendancePlanFields(attId, PlanUtils.splitPlans(result.plans));
        _markWritten(attId, saved);
        _replaceAtt(saved);
        return result.open;
      });

  void _replaceAtt(PlanAttendance saved) {
    final updated = [for (final a in _attendances) a.id == saved.id ? saved : a];
    // SOL_FIX25: also after dispose, so a write queued by [dispose] is built
    // from the latest persisted row.
    if (!mounted) {
      _attendances = updated;
      return;
    }
    setState(() => _attendances = updated);
  }

  Future<void> _updateFlags(Map<String, dynamic> updates) async {
    final att = _att;
    if (att?.id == null) return;
    final saved = await _serialised(
        att!.id!, () => ref.read(planRepositoryWithTenantProvider).updateAttendancePlanFields(att.id!, updates));
    _markWritten(att.id!, saved);
    _replaceAtt(saved);
  }

  /// SOL_FIX26: a write of Termin [attId] succeeded.
  /// SOL_FIX27: [saved] (the stored row) is recorded as a commit of this
  /// editor on the process-wide chain ([PlanningWriteSync]).
  void _markWritten(int attId, PlanAttendance saved) {
    _hasChanges = true;
    _needsInvalidate = true;
    _writtenAttIds.add(attId);
    _knownSeq[attId] = PlanningWriteSync.commit(PlanningWriteSync.keyFor(_tenantId, attId), _instanceNo, saved);
  }

  /// SOL_FIX26: refreshes the caches of every Termin written since the last
  /// call. Runs on every exit path (close, leave guard and, via the write
  /// chain, after [dispose]), so also autosaved changes are never shown
  /// stale. Uses the container captured while mounted.
  void _invalidateCaches() {
    if (!_needsInvalidate) return;
    _needsInvalidate = false;
    final ids = [..._writtenAttIds];
    _writtenAttIds.clear();
    try {
      _container.invalidate(planAttendancesProvider);
      for (final id in ids) {
        _container.invalidate(attendanceDetailProvider(id));
        _container.invalidate(planAttendanceByIdProvider(id));
      }
      _container.invalidate(orgPlansProvider);
      // SOL_FIX29: rows loaded from the caches from now on hold every commit.
      PlanningWriteSync.markCachesRefreshed();
    } catch (_) {
      // Container already disposed (app closed): nothing to refresh.
    }
  }

  // ---------------------------------------------------------------------------
  // Termin navigation
  // ---------------------------------------------------------------------------

  Future<void> _selectAttendance(int? id) async {
    if (id == null || id == _attId) return;
    // SOL_FIX23: a failed write keeps the open Termin (and its changes).
    if (!await _flushSaves()) {
      if (mounted) setState(() {});
      return;
    }
    if (!mounted) return;
    final att = _attendances.where((a) => a.id == id).firstOrNull;
    if (att != null) _loadAttendance(att);
  }

  Future<void> _navigate(int direction) async {
    final i = _attendances.indexWhere((a) => a.id == _attId);
    // List is sorted newest first: "Nächste" goes to a smaller index.
    final target = i - direction;
    if (target < 0) {
      ToastHelper.showWarning(context, context.l10n.planningFirstEvent);
      return;
    }
    if (target >= _attendances.length) {
      ToastHelper.showWarning(context, context.l10n.planningLastEvent);
      return;
    }
    await _selectAttendance(_attendances[target].id);
  }

  String _attLabel(PlanAttendance a) {
    final d = DateTime.tryParse(a.date);
    final date = d == null
        ? a.date
        : DateFormat(dateFmt()).format(d);
    final type = _typeOf(a);
    final title = (a.typeInfo?.isNotEmpty ?? false) ? a.typeInfo! : (type?.name ?? '');
    return '$date $title';
  }

  // ---------------------------------------------------------------------------
  // Several plans
  // ---------------------------------------------------------------------------

  Future<void> _selectPlan(int index) async {
    if (_att == null || index == _planIndex) return;
    // SOL_FIX23: wait for running writes; a failed write keeps the plan open.
    if (!await _flushSaves() || !mounted) return;
    final updated = _att!;
    setState(() => _planIndex = index);
    _loadPlan(updated, PlanUtils.allPlans(updated)[index]);
  }

  Future<void> _addPlan() async {
    if (_att == null) {
      ToastHelper.showWarning(context, context.l10n.planningChooseEventFirst);
      return;
    }
    if (!_validate()) {
      ToastHelper.showWarning(context, context.l10n.planningCreateRunSheetFirst);
      return;
    }
    if (!await _flushSaves() || !mounted) return;
    final choice = await showAppDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(ctx.l10n.planningAddAnotherPlan),
        content: Text(ctx.l10n.planningAddAnotherPlanMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, 'empty'), child: Text(ctx.l10n.planningEmpty)),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'copy'), child: Text(ctx.l10n.planningCopy)),
        ],
      ),
    );
    if (choice == null || !mounted || _att == null) return;
    final attId = _attId!;
    if (!_adoptLatest(attId)) return; // SOL_FIX28 / SOL_FIX29
    final copy = choice == 'copy';
    final current = _att!;
    final type = _typeOf(current);
    final time = copy ? _time : PlanUtils.formatTime(type?.startTime ?? current.startTime ?? _time);
    final newPlan = Plan(
      id: PlanUtils.uuid(),
      time: time.isEmpty ? _time : time,
      // Ionic: `dayjs().hour(..).minute(..).format('YYYY-MM-DDTHH:mm')`
      end: copy ? _end : PlanUtils.computeEndIso(time.isEmpty ? _time : time, const []),
      fields: copy
          ? _fields.where((f) => f.agendaItemId == null && !PlanUtils.isAgendaPlaceholder(f)).toList()
          : const [],
      title: copy && _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
    );
    try {
      // SOL_FIX24: no edits between the write and loading the new plan.
      await _whileBusy(() async {
        // SOL_FIX29: appended to the newest stored plan list (day: the next
        // free day there).
        final open = await _writePlanOp(attId, null, (att, plans, _) {
          plans.add(newPlan.copyWith(day: PlanUtils.nextFreeDay(att, plans)));
          return (plans: plans, open: plans.length - 1);
        });
        if (open == null || !mounted || _att == null) return;
        setState(() => _planIndex = open);
        _loadPlan(_att!, PlanUtils.allPlans(_att)[open]);
      });
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.planningFlutterSaveFailedWith(friendlyErrorMessage(e)));
    }
  }

  Future<void> _showPlanOptions() async {
    final att = _att;
    if (att == null) return;
    final plans = PlanUtils.allPlans(att);
    final shownIndex = _planIndex;
    final action = await showPlanActionSheet<String>(
      context,
      title: context.l10n.planningPlanHeader(PlanUtils.planLabel(att, shownIndex, plans)),
      subtitle: context.l10n.planningFlutterPlanPosition(shownIndex + 1, plans.length),
      actions: [
        PlanSheetAction('rename', context.l10n.planningRename, icon: Icons.edit_outlined),
        if (PlanUtils.dayOptions(att).isNotEmpty)
          PlanSheetAction('day', context.l10n.planningAssignOtherDay, icon: Icons.event),
        if (shownIndex > 0) PlanSheetAction('left', context.l10n.planningMoveLeft, icon: Icons.chevron_left),
        if (shownIndex < plans.length - 1)
          PlanSheetAction('right', context.l10n.planningMoveRight, icon: Icons.chevron_right),
        PlanSheetAction('delete', context.l10n.planningDeletePlan, icon: Icons.delete_outline, destructive: true),
      ],
    );
    if (action == null || !mounted) return;
    // SOL_FIX24: an invalid open plan does not block: rename / day / move
    // keep the editor (and its pending edits), delete removes the plan.
    if (!await _flushSaves(blockInvalid: false) || !mounted || _att == null) return;
    final attId = _attId!;
    // SOL_FIX29: the plan the sheet was opened for (its id, else position).
    final planKey = _planKeyOf(att, shownIndex);
    // SOL_FIX28: show the newest stored row in the dialogs; the open plan
    // keeps its position there. SOL_FIX29: stop when it was deleted.
    if (!_adoptLatest(attId)) return;
    final current = _att!;
    final index = _indexOfPlanKey(current, planKey);
    if (index == null) return;
    final list = PlanUtils.withDays(current, PlanUtils.allPlans(current));
    // SOL_FIX29: every change below is applied to the newest stored row
    // INSIDE the queued write ([_writePlanOp]), so a plan another editor
    // stored while a dialog was open is never reset by this copy.
    try {
      switch (action) {
        case 'rename':
          final auto = PlanUtils.planLabel(current, index, [for (final p in list) p.copyWith(label: null)]);
          final label = await showPlanTextPrompt(
            context,
            title: context.l10n.planningRenamePlan,
            message: context.l10n.planningRenameHint,
            initialValue: list[index].label,
            hint: auto,
            allowEmpty: true,
          );
          if (label == null || !mounted) return;
          await _whileBusy(() async {
            final open = await _writePlanOp(attId, planKey, (att, plans, i) {
              plans[i!] = plans[i].copyWith(label: label.isEmpty ? null : label);
              return (plans: plans, open: i);
            });
            if (open != null && mounted && open != _planIndex) setState(() => _planIndex = open);
          });
        case 'day':
          final options = PlanUtils.dayOptions(current);
          final day = await showPlanActionSheet<int>(
            context,
            title: context.l10n.planningAssignDay,
            actions: [
              for (final o in options)
                PlanSheetAction(o.day, o.label, icon: list[index].day == o.day ? Icons.check : null),
            ],
          );
          if (day == null || !mounted) return;
          await _whileBusy(() async {
            final open = await _writePlanOp(attId, planKey, (att, plans, i) {
              final moved = plans[i!].copyWith(day: day);
              plans[i] = moved;
              plans.sort((a, b) => (a.day ?? 0).compareTo(b.day ?? 0));
              return (plans: plans, open: plans.indexWhere((p) => identical(p, moved)));
            });
            if (open != null && mounted) setState(() => _planIndex = open);
          });
        case 'left':
        case 'right':
          await _whileBusy(() async {
            final open = await _writePlanOp(attId, planKey, (att, plans, i) {
              final to = i! + (action == 'left' ? -1 : 1);
              if (to < 0 || to >= plans.length) return null;
              final tmp = plans[i];
              plans[i] = plans[to];
              plans[to] = tmp;
              return (plans: plans, open: to);
            });
            if (open != null && mounted) setState(() => _planIndex = open);
          });
        case 'delete':
          final ok = await showPlanConfirm(
            context,
            title: context.l10n.planningDeletePlanConfirm,
            message: context.l10n.planningDeletePlanMessage(PlanUtils.planLabel(current, index, list)),
            confirmText: context.l10n.commonDelete,
            destructive: true,
          );
          if (!ok || !mounted) return;
          await _whileBusy(() async {
            final open = await _writePlanOp(attId, planKey, (att, plans, i) {
              plans.removeAt(i!);
              return (plans: plans, open: plans.isEmpty ? -1 : i.clamp(0, plans.length - 1));
            });
            if (open == null || !mounted) return;
            if (open < 0) {
              // SOL_FIX22: last plan deleted → empty editor, nothing pending.
              _clearEditor(_att ?? current);
            } else if (_att != null) {
              setState(() => _planIndex = open);
              _loadPlan(_att!, PlanUtils.allPlans(_att)[open]);
            }
          });
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.planningFlutterSaveFailedWith(friendlyErrorMessage(e)));
    }
  }

  // ---------------------------------------------------------------------------
  // Adding fields
  // ---------------------------------------------------------------------------

  Future<void> _addField() async {
    final r = await showPlanFieldDialog(context,
        title: context.l10n.planningAddField, nameHint: context.l10n.planningEnterFreeText, initialMinutes: 20);
    if (r == null) return;
    setState(() => _fields = [
          ..._fields,
          PlanField(id: r.name, name: r.name, conductor: r.conductor, info: r.info, time: '${r.minutes ?? 20}'),
        ]);
    _changed();
  }

  Future<void> _addNote() async {
    final r = await showPlanFieldDialog(context,
        title: context.l10n.planningAddNoteField,
        nameLabel: context.l10n.planningNote,
        nameHint: context.l10n.planningEnterNote,
        emptyNameMessage: context.l10n.plansEnterNotePlease,
        withConductor: false,
        withInfo: false,
        withMinutes: false);
    if (r == null) return;
    setState(() => _fields = [..._fields, PlanField(id: 'noteFld ${r.name}', name: r.name, conductor: '', time: '0')]);
    _changed();
  }

  Future<void> _addGroup() async {
    final r = await showPlanFieldDialog(
      context,
      title: context.l10n.planningAddBlock,
      message: context.l10n.planningBlockDurationHint,
      nameLabel: context.l10n.planningName,
      nameHint: context.l10n.planningBlockNamePlaceholder,
      conductorLabel: context.l10n.planningPerformance,
      conductorHint: context.l10n.planningPerformanceOptional,
      confirmText: context.l10n.commonCreate,
      emptyNameMessage: context.l10n.planningEnterNamePlease,
      withMinutes: false,
    );
    if (r == null || !mounted) return;
    final head = PlanUtils.newGroupHead(r.name, conductor: r.conductor, info: r.info);
    setState(() => _fields = [..._fields, head]);
    _changed();
    final sub = await showPlanFieldDialog(
      context,
      title: context.l10n.planningAddSubItem,
      subtitle: head.name,
      nameHint: context.l10n.planningSubItemPlaceholder,
      infoHint: context.l10n.planningSubItemInfoPlaceholder,
      initialMinutes: 5,
    );
    if (sub == null) return;
    setState(() => _fields = PlanUtils.addSubItem(
          _fields,
          head.id,
          PlanField(
            id: 'fld-${PlanUtils.uuid()}',
            name: sub.name,
            conductor: sub.conductor,
            info: sub.info,
            time: '${sub.minutes ?? 5}',
          ),
        ));
    _changed();
  }

  void _addCurrentSongs() {
    final added = PlanSongHelper.currentSongFields(
      _fields,
      history: _history,
      songs: _songs,
      prefix: _songPrefix(_typeOf(_att)),
    );
    if (added.isEmpty) return;
    setState(() => _fields = [..._fields, ...added]);
    _changed();
  }

  Future<void> _addSong() async {
    final song = await showPlanSongPicker(context, _songs);
    if (song == null) return;
    setState(() => _fields = [
          ..._fields,
          PlanSongHelper.songField(song, history: _history, prefix: _songPrefix(_typeOf(_att))),
        ]);
    _changed();
  }

  void _insertBlockTemplate(PlanBlockTemplate tpl) {
    setState(() => _fields = [..._fields, ...PlanUtils.cloneBlock(tpl.fields)]);
    _changed();
  }

  Future<void> _deleteBlockTemplate(PlanBlockTemplate tpl) async {
    final ok = await showPlanConfirm(
      context,
      title: context.l10n.planningDeleteTemplateConfirm,
      message: context.l10n.planningDeleteTemplateMessage(tpl.name),
      confirmText: context.l10n.commonDelete,
      destructive: true,
    );
    if (ok) await ref.read(planSettingsNotifierProvider.notifier).deleteBlockTemplate(tpl.id);
  }

  Future<void> _saveBlockTemplate(PlanField head) async {
    final ok = await ref.read(planSettingsNotifierProvider.notifier).saveBlockAsTemplate(_fields, head.id);
    if (!mounted) return;
    if (ok) {
      ToastHelper.showSuccess(context, context.l10n.planningTemplateSaved(head.name));
    } else {
      ToastHelper.showError(context, context.l10n.planningTemplateSaveFailed);
    }
  }

  void _applyOrgTemplate(Plan tpl) {
    setState(() {
      // Ionic applyTemplate resolves placeholders without the Termin type.
      _fields = PlanSongHelper.resolvePlaceholders(tpl.fields,
          history: _history, songs: _songs, prefix: _songPrefix(null));
      final t = PlanUtils.formatTime(tpl.time);
      if (t.isNotEmpty) _time = t;
    });
    _changed();
  }

  void _addOrgField(PlanField field) {
    setState(() => _fields = [..._fields, field]);
    _changed();
  }

  /// Ionic `getMissingGroups`: red "Ohne …" line under songs (not for general tenants).
  String? _missingGroups(PlanField field) {
    if (field.songId == null || ref.read(currentTenantProvider)?.type == 'general') return null;
    final song = _songs.where((s) => s.id == field.songId).firstOrNull;
    final ids = song?.instrumentIds;
    if (ids == null || ids.isEmpty) return null;
    return SongUtils.missingInstrumentsText(
      ids,
      ref.read(groupsProvider).valueOrNull ?? const [],
      ref.read(groupCategoriesProvider).valueOrNull ?? const [],
    );
  }

  /// Ionic `canAddTopics`: topics only live in the first plan of a protocol type.
  bool get _canAddTopics {
    final hasProtocol = ref.read(protocolTypeByIdProvider(_att?.typeId))?.enableProtocol ?? false;
    return _att?.id != null && _planIndex == 0 && hasProtocol && ref.read(isTeamLeaderProvider);
  }

  Future<void> _showAddMenu(BuildContext anchorContext) async {
    final role = ref.read(effectiveRoleProvider);
    final tenant = ref.read(currentTenantProvider);
    final isGeneral = tenant?.type == 'general';
    final blockTemplates = ref.read(planBlockTemplatesProvider).valueOrNull ?? const <PlanBlockTemplate>[];
    final org = ref.read(currentOrganisationProvider).valueOrNull;
    final orgTemplates = org?.planningTemplates ?? const <Plan>[];
    final orgFields = org?.defaultFields ?? const <PlanField>[];
    // PROTOCOL: Tagesordnung of protocol types (topics only live in the first plan)
    final hasProtocol = ref.read(protocolTypeByIdProvider(_att?.typeId))?.enableProtocol ?? false;
    final canAddTopics = _att?.id != null && _planIndex == 0 && hasProtocol && ref.read(isTeamLeaderProvider);
    final canInsertAgenda = hasProtocol && _planIndex == 0 && !_fields.any(PlanUtils.isAgendaPlaceholder);

    // Ionic: ion-popover (class add-popover, max 70vh) anchored to the "+".
    final l10n = context.l10n;
    PopupMenuItem<String> item(String value, String label, {Widget? icon, String? note, Color? color, Widget? trailing}) =>
        PopupMenuItem<String>(
          value: value,
          child: Row(
            children: [
              if (icon != null) ...[icon, const SizedBox(width: 12)],
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: label, style: color != null ? TextStyle(color: color) : null),
                  if (note != null) TextSpan(text: ' $note', style: const TextStyle(color: AppColors.medium)),
                ])),
              ),
              if (trailing != null) trailing,
            ],
          ),
        );
    PopupMenuItem<String> section(String label) => PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
        );
    final box = anchorContext.findRenderObject() as RenderBox;
    final overlay = Navigator.of(anchorContext).overlay!.context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
    final action = await showMenu<String>(
      context: anchorContext,
      position: RelativeRect.fromRect(Rect.fromPoints(topLeft, bottomRight), Offset.zero & overlay.size),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7, minWidth: 250, maxWidth: 320),
      items: [
        item('field', l10n.planningAddField),
        item('group', l10n.planningAddBlock),
        item('note', l10n.planningAddNoteField),
        if (!isGeneral) item('current', l10n.planningAddCurrentSongs),
        if (!isGeneral && _songs.isNotEmpty) item('song', l10n.planningAddSong),
        // PROTOCOL
        if (canAddTopics)
          item('topics', l10n.attendanceAddTopics,
              icon: const Icon(Icons.playlist_add_circle_outlined, color: AppColors.primary)),
        if (canInsertAgenda)
          item('agenda', l10n.planningInsertAgenda, icon: const Icon(Icons.commit, color: AppColors.medium)),
        if (blockTemplates.isNotEmpty) ...[
          const PopupMenuDivider(),
          section(l10n.planningBlocks),
          for (final tpl in blockTemplates)
            item(
              'block:${tpl.id}',
              tpl.name,
              note: l10n.planningMinShort(PlanUtils.templateMinutes(tpl)),
              trailing: role.isAdmin
                  ? Builder(
                      builder: (menuCtx) => IconButton(
                        tooltip: l10n.planningDeleteTemplate,
                        visualDensity: VisualDensity.compact,
                        color: AppColors.medium,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => Navigator.pop(menuCtx, 'delblock:${tpl.id}'),
                      ),
                    )
                  : null,
            ),
        ],
        if (orgTemplates.isNotEmpty || orgFields.isNotEmpty) const PopupMenuDivider(),
        if (orgTemplates.isNotEmpty) ...[
          section(l10n.planningTemplates),
          for (var i = 0; i < orgTemplates.length; i++) item('tpl:$i', orgTemplates[i].title ?? ''),
        ],
        if (orgFields.isNotEmpty) ...[
          section(l10n.planningFields),
          for (var i = 0; i < orgFields.length; i++)
            item('orgfield:$i', orgFields[i].name, note: l10n.planningMinShort(orgFields[i].time)),
        ],
        if (_att != null) ...[
          const PopupMenuDivider(),
          item('plan', l10n.planningAddAnotherPlan,
              icon: const Icon(Icons.copy_outlined, color: AppColors.medium), color: AppColors.medium),
        ],
      ],
    );
    if (action == null || !mounted) return;
    if (action.startsWith('block:')) {
      final tpl = blockTemplates.where((t) => t.id == action.substring(6)).firstOrNull;
      if (tpl != null) _insertBlockTemplate(tpl);
      return;
    }
    if (action.startsWith('delblock:')) {
      final tpl = blockTemplates.where((t) => t.id == action.substring(9)).firstOrNull;
      if (tpl != null) await _deleteBlockTemplate(tpl);
      return;
    }
    if (action.startsWith('tpl:')) {
      _applyOrgTemplate(orgTemplates[int.parse(action.substring(4))]);
      return;
    }
    if (action.startsWith('orgfield:')) {
      _addOrgField(orgFields[int.parse(action.substring(9))]);
      return;
    }
    switch (action) {
      case 'field':
        await _addField();
      case 'group':
        await _addGroup();
      case 'note':
        await _addNote();
      case 'current':
        _addCurrentSongs();
      case 'song':
        await _addSong();
      case 'plan':
        await _addPlan();
      case 'agenda': // PROTOCOL
        _addAgendaPlaceholder();
      case 'topics': // PROTOCOL
        await _openAgendaPicker();
    }
  }

  // PROTOCOL: Ionic `addAgendaItemsPlaceholder` (the marker takes no time).
  void _addAgendaPlaceholder() {
    if (_fields.any(PlanUtils.isAgendaPlaceholder)) {
      ToastHelper.showWarning(context, context.l10n.planningAgendaExists);
      return;
    }
    setState(() => _fields = [
          ..._fields,
          PlanField(id: PlanUtils.agendaPlaceholderId, name: context.l10n.planningAgenda, time: '0'),
        ]);
    _changed();
  }

  // PROTOCOL: Ionic `openAgendaPicker` — saves what is on screen first, so the
  // picker inserts into the current plan, then takes over the saved plan.
  Future<void> _openAgendaPicker() async {
    final protocolRepo = ref.read(protocolRepositoryWithTenantProvider);
    final att = _att;
    if (att?.id == null) return;
    if (!await _flushSaves() || !mounted) return;
    // SOL_FIX24: no edits while the protocol row loads (the picker then
    // stores the editor state and the editor reloads the stored plan).
    var protocolAtt = await _whileBusy<ProtocolAttendance?>(() async {
      try {
        return await protocolRepo.getAttendance(att!.id!);
      } catch (_) {
        return null;
      }
    });
    if (protocolAtt == null || !mounted) return;
    final title = _titleController.text.trim();
    if (_fields.isNotEmpty) {
      protocolAtt = protocolAtt.copyWith(plan: {
        ...?protocolAtt.plan,
        'time': _time,
        'end': _end,
        'fields': _fields.map((f) => f.toJson()).toList(),
        if (title.isNotEmpty) 'title': title,
      });
    }
    final type = ref.read(protocolTypeByIdProvider(att!.typeId));
    final saved = await showAgendaPickerSheet(context, attendance: protocolAtt, type: type);
    if (saved == null || !mounted) return;
    try {
      final plan = Plan.fromJson(saved);
      final stored = att.copyWith(plan: plan);
      _replaceAtt(stored);
      _loadPlan(att, plan);
      _markWritten(att.id!, stored);
      ref.invalidate(planAttendanceByIdProvider(att.id!));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Share / export
  // ---------------------------------------------------------------------------

  Future<void> _shareLink() async {
    final att = _att;
    if (att?.id == null) {
      ToastHelper.showWarning(context, context.l10n.planningChooseEventFirst);
      return;
    }
    // SOL_FIX24: sharing keeps the editor, so an invalid plan does not block.
    if (!await _flushSaves(blockInvalid: false) || !mounted) return;
    final action = await showPlanActionSheet<String>(
      context,
      title: context.l10n.planningShareLink,
      actions: [
        PlanSheetAction('read', context.l10n.planningReadOnlyLink, icon: Icons.link),
        PlanSheetAction('edit', context.l10n.planningEditLink, icon: Icons.edit_note),
        if (att!.shareKey != null)
          PlanSheetAction('revoke', context.l10n.planningFlutterUnshareAction,
              icon: Icons.link_off, destructive: true),
      ],
    );
    if (action == null || !mounted) return;
    try {
      if (action == 'revoke') {
        final ok = await showPlanConfirm(
          context,
          title: context.l10n.planningUnshareConfirm,
          message: context.l10n.planningUnshareMessage,
          confirmText: context.l10n.planningUnshare,
          destructive: true,
        );
        if (!ok) return;
        await _updateFlags({'share_key': null, 'share_edit_key': null});
        if (mounted) ToastHelper.showSuccess(context, context.l10n.planningUnshared);
        return;
      }
      final edit = action == 'edit';
      var shareKey = att.shareKey;
      var editKey = att.shareEditKey;
      if (shareKey == null) {
        shareKey = PlanUtils.randomKey();
        editKey = PlanUtils.randomKey();
        await _updateFlags({'share_key': shareKey, 'share_edit_key': editKey});
      } else if (edit && editKey == null) {
        editKey = PlanUtils.randomKey();
        await _updateFlags({'share_edit_key': editKey});
      }
      final base = '/plan?id=${att.id}&key=$shareKey';
      final url = planPublicUrl(edit ? '$base&edit=$editKey' : base);
      if (mounted) await sharePlanLink(context, url, title: _effectiveTitle);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.planningFlutterShareFailedWith(friendlyErrorMessage(e)));
    }
  }

  String get _effectiveTitle {
    final t = _titleController.text.trim();
    return t.isNotEmpty ? t : _defaultTitle(_att);
  }

  PlanExportPage _exportPage(PlanAttendance att, int index, Plan plan) {
    final plans = PlanUtils.allPlans(att);
    final date = PlanUtils.planDate(att, index, plans.isEmpty ? [plan] : plans) ?? DateTime.tryParse(att.date);
    final label = plans.length > 1 ? ' · ${PlanUtils.planLabel(att, index, plans)}' : '';
    final title = (plan.title?.trim().isNotEmpty ?? false) ? plan.title!.trim() : _defaultTitle(att);
    return PlanExportPage(
      title: title,
      subtitle: '${PlanUtils.longDate(date)}$label',
      time: plan.time,
      end: plan.end,
      fields: plan.fields,
    );
  }

  String get _fileDate {
    final d = DateTime.tryParse(_att?.date ?? '') ?? DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}_${d.month.toString().padLeft(2, '0')}_${d.year}';
  }

  /// Ionic `showOptions`: export entries only with fields (validated on
  /// click), the Registerprobenplan always for choir / orchestra.
  Future<void> _showOptions() async {
    // Exports use the editor state, so they also work when the write failed
    // (SOL_FIX24: or the plan is invalid; the export validates on click).
    await _flushSaves(blockInvalid: false);
    if (!mounted) return;
    final att = _att;
    final tenant = ref.read(currentTenantProvider);
    final showSectional = tenant?.type == 'choir' || tenant?.type == 'orchestra';
    final plans = PlanUtils.allPlans(att);
    final current = Plan(time: _time, end: _end, fields: _fields, title: _effectiveTitle);
    final fileName = '${_effectiveTitle}_$_fileDate';
    await showPlanExportSheet(
      context,
      ref,
      title: context.l10n.personActions,
      fileName: fileName,
      includeBranding: ref.read(includeBrandingProvider), // MISC2
      showExports: _fields.isNotEmpty,
      beforeExport: () => _validate(showToast: true),
      pages: () => [
        att == null
            ? PlanExportPage(
                title: _effectiveTitle,
                subtitle: PlanUtils.longDate(DateTime.now()),
                time: _time,
                end: _end,
                fields: _fields)
            : _exportPage(att, _planIndex, current),
      ],
      extraActions: [
        if (_fields.isNotEmpty && plans.length > 1)
          PlanSheetAction('all', context.l10n.planningExportPdfAll, icon: Icons.picture_as_pdf),
        if (showSectional)
          PlanSheetAction('sectional', context.l10n.planningCreateSectionalPlan, icon: Icons.groups),
      ],
      onExtraAction: (a) async {
        if (a == 'sectional') {
          await showRegisterPlanSheet(context, attendanceDate: DateTime.tryParse(att?.date ?? ''));
        } else if (a == 'all' && att != null) {
          await runPlanExport(
            context,
            ref,
            PlanExportAction.pdf,
            pages: [
              for (var i = 0; i < plans.length; i++) _exportPage(att, i, i == _planIndex ? current : plans[i]),
            ],
            fileName: fileName,
            includeBranding: ref.read(includeBrandingProvider), // MISC2
          );
        }
      },
    );
  }

  Future<void> _resetPlan() async {
    final ok = await showPlanConfirm(
      context,
      title: context.l10n.planningResetPlan,
      message: context.l10n.planningResetPlanMessage,
      confirmText: context.l10n.dateDialogReset,
    );
    if (ok && _att != null) _applyTypeDefaultPlan(_att!);
  }

  Future<void> _pickTime() async {
    final m = PlanUtils.parseTimeToMinutes(_time) ?? (17 * 60 + 50);
    final picked = await showAppTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _time = PlanUtils.formatMinutes(picked.hour * 60 + picked.minute));
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final attendancesAsync = ref.watch(planAttendancesProvider);
    final typesAsync = ref.watch(planAttendanceTypesProvider);
    ref.watch(planSongsProvider);
    ref.watch(currentSongsProvider);
    ref.watch(groupsProvider);
    ref.watch(groupCategoriesProvider);
    ref.watch(protocolTypesProvider); // PROTOCOL: keeps the protocol settings loaded
    final blockTemplates = ref.watch(planBlockTemplatesProvider).valueOrNull ?? const <PlanBlockTemplate>[];
    final role = ref.watch(effectiveRoleProvider);

    // SOL_FIX26: not from the previous value while the Termine reload after
    // an invalidation (that would edit the stale plan).
    if (!_loaded && attendancesAsync.hasValue && !attendancesAsync.isLoading && !typesAsync.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loaded) unawaited(_init(attendancesAsync.value!));
      });
    }

    final att = _att;
    final plans = PlanUtils.allPlans(att);
    final labels = att == null || plans.length < 2
        ? const <String>[]
        : [for (var i = 0; i < plans.length; i++) PlanUtils.planLabel(att, i, plans)];

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
            child: Scaffold(
        // Ionic: modal toolbar [Link teilen, Schließen]; actions in the FAB (…).
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(context.l10n.attendanceCreateRunSheet),
          // IOS_PAGES3: iOS → the end ion-buttons share one glass capsule
          actions: [
            ToolbarButtonGroup(children: [
              IconButton(tooltip: context.l10n.planningShareLink, icon: const Icon(Icons.link), onPressed: _shareLink),
              IconButton(
                tooltip: context.l10n.commonClose,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ]),
          ],
        ),
        floatingActionButton: TabBarFab.wrap(FloatingActionButton(
          tooltip: context.l10n.personActions,
          onPressed: _showOptions,
          child: const Icon(Icons.more_horiz),
        )),
        body: attendancesAsync.when(
          loading: () => const Center(child: AppSpinner()),
          error: (e, _) => Center(child: Text(context.l10n.planningFlutterErrorWith(friendlyErrorMessage(e)))),
          // SOL_FIX2: requested Termin not reachable → error, no fallback
          data: (_) => _requestedNotFound
              ? Center(child: Text(context.l10n.attendanceFlutterNotFound))
              : ListView(
            padding: EdgeInsets.only(bottom: scrollEndPadding(context, base: 16, fabRoom: 80)),
            children: [
              _buildAttendanceCard(att),
              // Ionic: second ion-list [inset] "Ablauf" with the "+" popover
              // trigger, the plan chips and the white item group.
              IonInsetList(
                dividerIndent: null,
                headerWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IonListHeader(
                      title: context.l10n.planningRunSheet,
                      trailing: Builder(
                        builder: (anchor) => IconButton(
                          color: AppColors.primary,
                          tooltip: context.l10n.planningAddField,
                          icon: const Icon(Icons.add),
                          onPressed: () => _showAddMenu(anchor),
                        ),
                      ),
                    ),
                    if (labels.isNotEmpty)
                      PlanChips(
                        labels: labels,
                        selected: _planIndex,
                        onSelected: _selectPlan,
                        trailing: IconButton(
                          tooltip: context.l10n.planningPlanOptions,
                          color: AppColors.medium,
                          icon: const Icon(Icons.more_horiz),
                          onPressed: _showPlanOptions,
                        ),
                      ),
                  ],
                ),
                children: [
                  ListTile(
                    title: Text(context.l10n.attendanceStartLabel),
                    trailing: IonDatetimeChip(text: _time, onTap: _pickTime),
                  ),
                  const Divider(height: 1, indent: 16),
                  PlanFieldsEditor(
                    fields: _fields,
                    startTime: _time,
                    onChanged: (f) {
                      setState(() => _fields = f);
                      _changed();
                    },
                    blockTemplateNames: blockTemplates.map((t) => t.name).toSet(),
                    onAddTopics: _canAddTopics ? _openAgendaPicker : null,
                    fieldWarning: _missingGroups,
                    onSaveBlockTemplate: role.isAdmin ? _saveBlockTemplate : null,
                  ),
                  if (_fields.isNotEmpty)
                    ListTile(
                      title: Text(context.l10n.attendanceEnd),
                      // Ionic: disabled ion-datetime-button (read-only chip)
                      trailing: IonDatetimeChip(text: PlanUtils.formatTime(_end)),
                    ),
                ],
              ),
            ],
          ),
        ),
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

  Widget _buildAttendanceCard(PlanAttendance? att) {
    final org = ref.watch(currentOrganisationProvider).valueOrNull;
    // Ionic: ion-list [inset] with header "Zugehöriger Termin" + reset button;
    // the items have lines="none".
    return IonInsetList(
      header: context.l10n.planningRelatedAttendance,
      headerTrailing: IconButton(
        color: AppColors.primary,
        tooltip: context.l10n.planningResetPlan,
        icon: const Icon(Icons.refresh),
        onPressed: _resetPlan,
      ),
      dividerIndent: null,
      children: [
        if (_attendances.isNotEmpty)
          IonSelect<int>(
            key: ValueKey(_attId),
            label: context.l10n.planningCurrent,
            value: _attId,
            items: [
              for (final a in _attendances)
                if (a.id != null)
                  DropdownMenuItem(value: a.id, child: Text(_attLabel(a), overflow: TextOverflow.ellipsis)),
            ],
            onChanged: _selectAttendance,
          )
        else
          ListTile(title: Text(context.l10n.planningFlutterNoEvents)),
        if (att != null && (att.notes ?? '').isNotEmpty) ...[
          const Divider(height: 1, indent: 16),
          ListTile(
            title: Text(context.l10n.planningAttendanceNotes,
                style: const TextStyle(fontSize: 12, color: AppColors.medium)),
            subtitle: Text(att.notes!),
          ),
        ],
        if (att != null) ...[
          SwitchListTile.adaptive(
            title: Text(context.l10n.planningShareWithMembers),
            value: _sharePlan,
            onChanged: (v) async {
              setState(() => _sharePlan = v);
              try {
                await _updateFlags({'share_plan': v});
              } catch (_) {
                if (mounted) setState(() => _sharePlan = !v);
              }
            },
          ),
          if (org != null)
            SwitchListTile.adaptive(
              title: Text(context.l10n.planningOrgPlan),
              value: _isOrgPlan,
              onChanged: (v) async {
                setState(() => _isOrgPlan = v);
                try {
                  await _updateFlags({'is_org_plan': v});
                } catch (_) {
                  if (mounted) setState(() => _isOrgPlan = !v);
                }
              },
            ),
          IonStackedInput(
            controller: _titleController,
            label: context.l10n.planningHeadingLabel,
            hint: context.l10n.planningDefaultTitle,
            onFocusLost: _onTitleFocusLost,
          ),
        ],
        // MISC2: "Branding einbeziehen" (only when logo/text configured)
        if (ref.watch(hasBrandingProvider))
          SwitchListTile.adaptive(
            title: Text(context.l10n.planningIncludeBranding),
            value: ref.watch(includeBrandingProvider),
            onChanged: (v) => ref.read(includeBrandingProvider.notifier).state = v,
          ),
        // Ionic: two small clear buttons (expand="full") side by side.
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () => _navigate(-1),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: IonButtonLabel(context.l10n.planningPrevious),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: () => _navigate(1),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: IonButtonLabel(context.l10n.planningNext),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
