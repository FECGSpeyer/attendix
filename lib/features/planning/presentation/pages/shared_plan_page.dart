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

  PublicPlanRepository get _repo => ref.read(publicPlanRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
    // Re-evaluate whether the live toggle is offered.
    _liveCheck = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _liveCheck?.cancel();
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
      final updated = PlanAttendance.fromJson({
        ...att.toJson(),
        'plan': row['plan'],
        'extra_plans': row['extra_plans'],
      });
      setState(() {
        _att = updated;
        final plans = PlanUtils.allPlans(updated);
        _labels = plans.length > 1
            ? [for (var i = 0; i < plans.length; i++) PlanUtils.planLabel(updated, i, plans)]
            : const [];
        _planIndex = _planIndex.clamp(0, plans.length - 1);
        _applyAttendancePlan();
      });
    } catch (_) {}
  }

  Future<void> _loadSharedPlan(String key) async {
    final plan = await _repo.getSharedPlan(key);
    if (plan == null) {
      _notFound = true;
      return;
    }
    _shared = plan;
    _title = (plan.planTitle?.isNotEmpty ?? false) ? plan.planTitle! : l10nWithoutContext.plansRunSheet;
    _date = plan.date ?? '';
    _time = plan.time ?? '';
    _end = plan.endTime ?? '';
    _fields = [...plan.fields];
    final edit = widget.editKey;
    if (edit != null && edit.isNotEmpty && await _repo.verifySharedPlanEditKey(key, edit)) {
      _editMode = true;
      _channel = _repo.watchSharedPlan(key, _onSharedUpdate);
    }
  }

  void _onSharedUpdate(Map<String, dynamic> row) {
    if (!mounted) return;
    try {
      final updated = SharedPlan.fromJson({..._shared!.toJson(), ...row});
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

  void _selectPlan(int index) {
    setState(() {
      _planIndex = index;
      _applyAttendancePlan();
      _live = _isLiveNow();
    });
  }

  // ---------------------------------------------------------------------------
  // Edit mode
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    final key = widget.shareKey!;
    final editKey = widget.editKey!;
    final start = PlanUtils.parseTimeToMinutes(_time);
    // REVIEW_FIX3: same stored format as planning_page (Ionic calculateEnd:
    // "YYYY-MM-DDTHH:mm").
    if (start != null) _end = PlanUtils.computeEndIso(_time, _fields);
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
        _att = PlanAttendance.fromJson({...att.toJson(), ...update});
      } else if (_shared != null) {
        await _repo.updateSharedPlan(key, editKey, fields: _fields, title: _title, time: _time);
      }
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.plansSaveFailed);
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
        actions: [
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
                      _save();
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
