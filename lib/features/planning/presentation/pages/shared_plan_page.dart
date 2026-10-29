import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/plan_export_service.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../data/repositories/public_plan_repository.dart';
import '../widgets/plan_export_actions.dart';
import '../widgets/plan_field_dialogs.dart';
import '../widgets/plan_fields_editor.dart';
import '../widgets/plan_view_list.dart';
import '../widgets/ion_items.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Public plan link without login (Ionic `SharedPlanPage`, route `/plan`).
///
/// - `?id=<attendance>&key=<share_key>[&edit=<share_edit_key>]`: plan of a Termin
/// - `?key=<shared_plans.id>[&edit=<edit_key>]`: ad-hoc plan
/// SOL_FIX10: whether the app is visible for [state] (null = unknown, e.g.
/// before the first lifecycle event → treated as visible).
bool isAppVisible(AppLifecycleState? state) =>
    state == null ||
    state == AppLifecycleState.resumed ||
    state == AppLifecycleState.inactive;

/// SOL_FIX10: display values of an ad-hoc plan, taken completely from
/// [plan] (Ionic loadSharedPlan): empty/cleared values stay empty, only the
/// title falls back to [fallbackTitle].
({String title, String date, String time, String end, List<PlanField> fields})
    sharedPlanDisplay(SharedPlan plan, String fallbackTitle) => (
          title: (plan.planTitle?.isNotEmpty ?? false) ? plan.planTitle! : fallbackTitle,
          date: plan.date ?? '',
          time: plan.time ?? '',
          end: plan.endTime ?? '',
          fields: [...plan.fields],
        );

class SharedPlanPage extends ConsumerStatefulWidget {
  const SharedPlanPage({super.key, this.attendanceId, this.shareKey, this.editKey});

  final int? attendanceId;
  final String? shareKey;
  final String? editKey;

  @override
  ConsumerState<SharedPlanPage> createState() => _SharedPlanPageState();
}

class _SharedPlanPageState extends ConsumerState<SharedPlanPage> {
  bool _loading = true;
  bool _notFound = false;
  bool _editMode = false;

  PlanAttendance? _att;
  SharedPlan? _shared;
  List<String> _labels = const [];
  int _planIndex = 0;
  int _todayIndex = -1;

  String _title = '';
  String _date = '';
  String _time = '';
  String _end = '';
  List<PlanField> _fields = [];

  bool _live = false;
  RealtimeChannel? _channel;
  Timer? _liveCheck;

  /// SOL_FIX8: readers of a read-only link (no edit key) get no realtime
  /// channel — `postgres_changes` payloads carry the full row including the
  /// edit keys. Instead the page re-fetches the whitelisted public columns
  /// every [refreshInterval] (like org_plan_public_page) and applies the
  /// same fields Ionic's realtime handlers update (Termin: plan +
  /// extra_plans; ad-hoc: title, time, end, fields). Paused while the app
  /// is in the background.
  static const Duration refreshInterval = Duration(seconds: 15);
  Timer? _refreshTimer;
  bool _refreshing = false;
  AppLifecycleListener? _lifecycle;

  /// SOL_FIX25: read once while mounted; [dispose] (unwatch) and writes
  /// that finish after dispose must not use `ref`.
  late final PublicPlanRepository _repo = ref.read(publicPlanRepositoryProvider);

  /// SOL_FIX25: edit link writes run one after another (a write starts only
  /// when the previous one finished) and each builds its payload from the
  /// current full state when it starts, so an older state can never be
  /// written last.
  Future<bool> _writeChain = Future<bool>.value(true);

  /// SOL_FIX25: a write is queued but has not started yet; further edits
  /// join it (it reads the newest state when it starts).
  bool _writeQueued = false;

  /// SOL_FIX25: writes queued or running.
  int _pendingWrites = 0;

  /// SOL_FIX25: the editor holds edits that are not stored yet (also after
  /// a failed write, so the next switch retries instead of dropping them).
  bool _dirty = false;

  /// SOL_FIX25: bumped on every edit; a finished write only clears
  /// [_dirty] when nothing was edited since it started.
  int _editGen = 0;

  /// SOL_FIX25: a plan switch is waiting for the pending writes.
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _repo; // SOL_FIX25: capture the repository while mounted.
    // SOL_FIX10: registered BEFORE the initial fetch, so a hide/show while
    // the plan is still loading is not missed.
    _lifecycle = AppLifecycleListener(
      onHide: _stopRefresh,
      onShow: () {
        if (!mounted || !_pollingAllowed) return;
        _refresh();
        _startRefresh();
      },
    );
    _load();
    // Re-evaluate whether the live toggle is offered.
    _liveCheck = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _liveCheck?.cancel();
    _stopRefresh();
    _lifecycle?.dispose();
    final channel = _channel;
    if (channel != null) _repo.unwatch(channel);
    super.dispose();
  }

  Future<void> _load() async {
    final key = widget.shareKey;
    if (key == null || key.isEmpty) {
      setState(() {
        _notFound = true;
        _loading = false;
      });
      return;
    }
    try {
      if (widget.attendanceId != null) {
        await _loadAttendancePlan(widget.attendanceId!, key);
      } else {
        await _loadSharedPlan(key);
      }
    } catch (_) {
      _notFound = true;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _live = !_notFound && _isLiveNow();
    });
    if (!_notFound && !_editMode) {
      // SOL_FIX10: loaded while the app is hidden → the onShow handler
      // starts polling once the app is visible again.
      if (isAppVisible(WidgetsBinding.instance.lifecycleState)) _startRefresh();
    }
  }

  /// Read-only link loaded and still valid: polling may run.
  bool get _pollingAllowed => !_loading && !_notFound && !_editMode;

  // ---------------------------------------------------------------------------
  // Read-only refresh (SOL_FIX8)
  // ---------------------------------------------------------------------------

  void _startRefresh() {
    _refreshTimer?.cancel();
    if (!_pollingAllowed) return;
    _refreshTimer = Timer.periodic(refreshInterval, (_) => _refresh());
  }

  void _stopRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _refresh() async {
    final key = widget.shareKey;
    if (_refreshing || !mounted || _editMode || key == null) return;
    _refreshing = true;
    try {
      final id = widget.attendanceId;
      if (id != null) {
        final fresh = await _repo.getSharedAttendancePlan(id, key);
        if (!mounted) return;
        if (fresh == null || fresh.plan == null) return _onLinkGone();
        _applyFreshAttendance(fresh);
      } else {
        final fresh = await _repo.getSharedPlan(key);
        if (!mounted) return;
        if (fresh == null) return _onLinkGone();
        _applyFreshSharedPlan(fresh);
      }
    } catch (_) {
      // Network hiccup: keep showing the last state, retry on the next tick.
    } finally {
      _refreshing = false;
    }
  }

  /// The plan was deleted or the share link revoked: stop showing it.
  void _onLinkGone() {
    _stopRefresh();
    setState(() {
      _notFound = true;
      _live = false;
    });
  }

  Future<void> _loadAttendancePlan(int id, String key) async {
    final att = await _repo.getSharedAttendancePlan(id, key);
    if (att == null || att.plan == null) {
      _notFound = true;
      return;
    }
    _att = att;
    final plans = PlanUtils.allPlans(att);
    if (plans.length > 1) {
      _labels = [for (var i = 0; i < plans.length; i++) PlanUtils.planLabel(att, i, plans)];
      _planIndex = PlanUtils.todayPlanIndex(att);
      final d = PlanUtils.planDate(att, _planIndex, plans);
      final now = DateTime.now();
      _todayIndex = d != null && d.year == now.year && d.month == now.month && d.day == now.day ? _planIndex : -1;
    }
    _applyAttendancePlan();
    final edit = widget.editKey;
    if (edit != null && edit.isNotEmpty && await _repo.verifySharedAttendanceEditKey(id, key, edit)) {
      _editMode = true;
      _channel = _repo.watchSharedAttendancePlan(id, _onAttendanceUpdate);
    }
  }

  void _applyAttendancePlan() {
    final att = _att;
    if (att == null) return;
    final plans = PlanUtils.allPlans(att);
    final plan = _planIndex < plans.length ? plans[_planIndex] : (att.plan ?? const Plan());
    _title = (plan.title?.isNotEmpty ?? false) ? plan.title! : (att.typeInfo ?? '');
    final date = _planIndex > 0 ? PlanUtils.planDate(att, _planIndex, plans) : null;
    _date = date != null
        ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        : att.date;
    _time = plan.time;
    _end = plan.end;
    _fields = [...plan.fields];
  }

  void _onAttendanceUpdate(Map<String, dynamic> row) {
    final att = _att;
    if (!mounted || att == null || row['plan'] == null) return;
    try {
      final fresh = PlanAttendance.fromJson({
        ...att.toJson(),
        'plan': row['plan'],
        'extra_plans': row['extra_plans'],
      });
      // SOL_FIX25: while own edits are pending (or being written) the echo
      // of an older write must not reset the editor: only the base row (the
      // other plans) is taken over; the next write stores the editor on top.
      if (_dirty || _pendingWrites > 0) {
        setState(() {
          _att = fresh;
          final plans = PlanUtils.allPlans(fresh);
          _labels = plans.length > 1
              ? [for (var i = 0; i < plans.length; i++) PlanUtils.planLabel(fresh, i, plans)]
              : const [];
          _planIndex = _planIndex.clamp(0, plans.length - 1);
        });
        return;
      }
      _applyFreshAttendance(fresh);
    } catch (_) {}
  }

  /// SOL_FIX10: takes over the complete fresh Termin state (date, type,
  /// plan + extra_plans) instead of patching the old one.
  void _applyFreshAttendance(PlanAttendance updated) {
    if (!mounted) return;
    setState(() {
      _att = updated;
      final plans = PlanUtils.allPlans(updated);
      _labels = plans.length > 1
          ? [for (var i = 0; i < plans.length; i++) PlanUtils.planLabel(updated, i, plans)]
          : const [];
      _planIndex = _planIndex.clamp(0, plans.length - 1);
      _applyAttendancePlan();
    });
  }

  Future<void> _loadSharedPlan(String key) async {
    final plan = await _repo.getSharedPlan(key);
    if (plan == null) {
      _notFound = true;
      return;
    }
    _setSharedPlan(plan);
    final edit = widget.editKey;
    if (edit != null && edit.isNotEmpty && await _repo.verifySharedPlanEditKey(key, edit)) {
      _editMode = true;
      _channel = _repo.watchSharedPlan(key, _onSharedUpdate);
    }
  }

  /// Ionic loadSharedPlan: every displayed value comes from [plan]; empty
  /// values stay empty (title falls back to "Ablaufplan").
  void _setSharedPlan(SharedPlan plan) {
    final display = sharedPlanDisplay(plan, l10nWithoutContext.plansRunSheet);
    _shared = plan;
    _title = display.title;
    _date = display.date;
    _time = display.time;
    _end = display.end;
    _fields = display.fields;
  }

  /// SOL_FIX10: read-only refresh — the fresh row replaces the whole state
  /// (incl. date and cleared title/time/end/fields), so live calculation and
  /// export use exactly what is stored now.
  void _applyFreshSharedPlan(SharedPlan fresh) {
    if (!mounted) return;
    setState(() {
      _setSharedPlan(fresh);
      if (!_isLiveNow()) _live = false;
    });
  }

  /// Realtime payload of a verified edit link (Ionic
  /// subscribeSharedPlanRealtime: title/time only overwritten when set).
  void _onSharedUpdate(Map<String, dynamic> row) {
    if (!mounted) return;
    try {
      final updated = SharedPlan.fromJson({..._shared!.toJson(), ...row});
      // SOL_FIX25: an echo of an older own write never resets pending edits.
      if (_dirty || _pendingWrites > 0) {
        _shared = updated;
        return;
      }
      setState(() {
        _shared = updated;
        if (updated.planTitle?.isNotEmpty ?? false) _title = updated.planTitle!;
        if (updated.time?.isNotEmpty ?? false) _time = updated.time!;
        if (updated.endTime?.isNotEmpty ?? false) _end = updated.endTime!;
        _fields = [...updated.fields];
      });
    } catch (_) {}
  }

  DateTime? get _dateTime => DateTime.tryParse(_date);

  bool _isLiveNow() => PlanUtils.isLiveNow(_dateTime, _time, _fields);

  Plan get _plan => Plan(time: _time, end: _end, fields: _fields, title: _title);

  /// SOL_FIX25: in edit mode a plan switch waits until every pending edit
  /// of the open plan is stored; a failed write keeps the open plan (and its
  /// edits) instead of loading another plan over them.
  Future<void> _selectPlan(int index) async {
    if (index == _planIndex || _switching) return;
    if (_editMode && (_dirty || _pendingWrites > 0)) {
      _switching = true;
      final bool ok;
      try {
        ok = await _flushSaves();
      } finally {
        _switching = false;
      }
      if (!ok || !mounted) return;
    }
    setState(() {
      _planIndex = index;
      _applyAttendancePlan();
      _live = _isLiveNow();
    });
  }

  // ---------------------------------------------------------------------------
  // Edit mode
  // ---------------------------------------------------------------------------

  /// SOL_FIX25: marks the editor dirty and queues a write behind the running
  /// one. True when the newest state (as of the write's start) was stored.
  Future<bool> _save() {
    _dirty = true;
    _editGen++;
    _recomputeEnd();
    return _queueWrite();
  }

  Future<bool> _queueWrite() {
    // A queued write that has not started yet picks up this state too.
    if (_writeQueued) return _writeChain;
    _writeQueued = true;
    _pendingWrites++;
    final next = _writeChain.then((_) async {
      _writeQueued = false;
      try {
        return await _writeNow();
      } finally {
        _pendingWrites--;
      }
    });
    _writeChain = next;
    return next;
  }

  /// SOL_FIX25: waits until every edit is stored; false when a write failed
  /// (running writes are awaited first, a failed one is not retried here).
  Future<bool> _flushSaves() async {
    while (_dirty || _pendingWrites > 0) {
      final ok = _pendingWrites > 0 ? await _writeChain : await _queueWrite();
      if (!ok || !mounted) return false;
    }
    return true;
  }

  /// REVIEW_FIX3: same stored format as planning_page (Ionic calculateEnd:
  /// "YYYY-MM-DDTHH:mm").
  /// SOL_FIX12: an ad-hoc plan's end is based on its own date (a bare
  /// "HH:mm" start must not fall back to today).
  void _recomputeEnd() {
    final start = PlanUtils.parseTimeToMinutes(_time);
    final endBase = _shared != null && _att == null && !_time.contains('T') && _date.isNotEmpty
        ? '${_date.length >= 10 ? _date.substring(0, 10) : _date}T${PlanUtils.formatTime(_time)}'
        : _time;
    if (start != null) _end = PlanUtils.computeEndIso(endBase, _fields);
  }

  /// SOL_FIX25: one write, built from the current full state when it starts
  /// (`_att` = latest stored row incl. the other plans, plus the editor).
  Future<bool> _writeNow() async {
    if (!_dirty) return true;
    final key = widget.shareKey!;
    final editKey = widget.editKey!;
    final editGen = _editGen;
    _recomputeEnd();
    try {
      final att = _att;
      if (att?.id != null) {
        final plans = PlanUtils.allPlans(att);
        final base = _planIndex < plans.length ? plans[_planIndex] : const Plan();
        final edited = base.copyWith(
          time: _time,
          end: _end,
          fields: _fields,
          title: _title.isEmpty ? null : _title,
        );
        final Map<String, dynamic> update;
        if (plans.length > 1) {
          plans[_planIndex] = edited;
          update = PlanUtils.splitPlans(plans);
        } else {
          update = {'plan': edited.toJson()};
        }
        await _repo.updateSharedAttendancePlan(att!.id!, key, editKey, update);
        // The stored row; other fields of `_att` may have changed meanwhile
        // (realtime), the plan columns are exactly what was written.
        _att = PlanAttendance.fromJson({...(_att ?? att).toJson(), ...update});
      } else if (_shared != null) {
        // SOL_FIX12: the recomputed end is persisted together with time + fields.
        await _repo.updateSharedPlan(key, editKey, fields: _fields, title: _title, time: _time, endTime: _end);
      }
      if (editGen == _editGen) _dirty = false;
      return true;
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.plansSaveFailed);
      return false;
    }
  }

  Future<void> _editTitle() async {
    if (!_editMode) return;
    final title = await showPlanTextPrompt(
      context,
      title: context.l10n.plansEditTitle,
      initialValue: _title,
      hint: context.l10n.plansTitle,
    );
    if (title == null || title.trim().isEmpty) return;
    setState(() => _title = title.trim());
    await _save();
  }

  Future<void> _editStartTime() async {
    if (!_editMode) return;
    final m = PlanUtils.parseTimeToMinutes(_time) ?? 10 * 60;
    final picked = await showAppTimePicker(
      context: context,
      helpText: context.l10n.plansEditStartTime,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final hhmm = PlanUtils.formatMinutes(picked.hour * 60 + picked.minute);
    setState(() => _time = _date.isNotEmpty && _shared != null ? '${_date}T$hhmm' : hhmm);
    await _save();
  }

  Future<void> _showAddMenu(BuildContext anchor) async {
    // Ionic: ion-popover anchored to the "+" in the list header.
    final action = await showIonPopover<String>(
      anchor,
      items: [
        PopupMenuItem(value: 'field', child: Text(context.l10n.planningAddField)),
        PopupMenuItem(value: 'note', child: Text(context.l10n.planningAddNoteField)),
      ],
    );
    if (action == null || !mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (action == 'field') {
      final r = await showPlanFieldDialog(
        context,
        title: context.l10n.planningAddField,
        conductorHint: context.l10n.plansPerformerOptional,
        withMinutes: false,
        confirmText: context.l10n.attendanceAdd,
      );
      if (r == null) return;
      setState(() => _fields = [
            ..._fields,
            PlanField(id: '${r.name}-$now', name: r.name, conductor: r.conductor, info: r.info, time: '20'),
          ]);
    } else {
      final r = await showPlanFieldDialog(
        context,
        title: context.l10n.planningAddNoteField,
        nameLabel: context.l10n.planningNote,
        nameHint: context.l10n.planningEnterNote,
        emptyNameMessage: context.l10n.plansEnterNotePlease,
        withConductor: false,
        withInfo: false,
        withMinutes: false,
      );
      if (r == null) return;
      setState(() => _fields = [..._fields, PlanField(id: 'noteFld ${r.name}-$now', name: r.name, conductor: '', time: '0')]);
    }
    await _save();
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _export() async {
    final date = _dateTime;
    final label = _labels.isNotEmpty ? ' · ${_labels[_planIndex]}' : '';
    final title = _title.isNotEmpty ? _title : context.l10n.plansRunSheet;
    await showPlanExportSheet(
      context,
      ref,
      withImage: false,
      pages: () => [
        PlanExportPage(
          title: title,
          subtitle: '${PlanUtils.longDate(date)}$label',
          time: _time,
          end: _end,
          fields: _fields,
        ),
      ],
      fileName: title,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final date = _dateTime;
    final liveNow = !_loading && !_notFound && _isLiveNow();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(date != null ? PlanUtils.longDate(date) : _title),
        // IOS_PAGES3: iOS → the end ion-buttons share one glass capsule
        actions: [
          ToolbarButtonGroup(children: [
          if (liveNow)
            IconButton(
              tooltip: context.l10n.planningFlutterLive,
              // Ionic: radio / radio-outline, danger while live.
              color: _live ? AppColors.danger : AppColors.primary,
              icon: Icon(_live ? Icons.sensors : Icons.sensors_outlined),
              onPressed: () => setState(() => _live = !_live),
            ),
          if (!_loading && !_notFound)
            IconButton(tooltip: context.l10n.planningExport, icon: const Icon(Icons.ios_share), onPressed: _export),
          ]),
        ],
      ),
      body: _buildBody(date),
    );
  }

  Widget _buildBody(DateTime? date) {
    if (_loading) return const Center(child: AppSpinner());
    if (_notFound) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.plansNotFound),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (_labels.isNotEmpty)
          PlanChips(labels: _labels, selected: _planIndex, todayIndex: _todayIndex, onSelected: _selectPlan),
        // Ionic: ion-list [inset]; header = plan title (+ edit icon and the
        // "+" popover trigger in edit mode); start/end as ion-note.
        IonInsetList(
          headerWidget: IonListHeader(
            trailing: _editMode
                ? Builder(
                    builder: (anchor) => IconButton(
                      color: AppColors.primary,
                      tooltip: context.l10n.attendanceAdd,
                      icon: const Icon(Icons.add),
                      onPressed: () => _showAddMenu(anchor),
                    ),
                  )
                : null,
            titleWidget: GestureDetector(
              onTap: _editMode ? _editTitle : null,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: _title),
                if (_editMode)
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.edit_outlined, size: 15, color: AppColors.medium),
                    ),
                  ),
              ])),
            ),
          ),
          dividerIndent: _editMode ? 16 : null,
          children: _editMode
              ? [
                  ListTile(
                    title: Text(context.l10n.attendanceStartLabel),
                    trailing: IonNote(context.l10n.attendanceTimeOClock(PlanUtils.formatTime(_time))),
                    onTap: _editStartTime,
                  ),
                  PlanFieldsEditor(
                    fields: _fields,
                    startTime: PlanUtils.formatTime(_time),
                    onChanged: (f) {
                      setState(() => _fields = PlanUtils.normalizeGroups(f));
                      unawaited(_save());
                    },
                  ),
                  if (_end.isNotEmpty)
                    ListTile(
                      title: Text(context.l10n.attendanceEnd),
                      trailing: IonNote(context.l10n.attendanceTimeOClock(PlanUtils.formatTime(_end))),
                    ),
                ]
              : [PlanViewList(plan: _plan, date: date, liveMode: _live)],
        ),
      ],
    );
  }
}
