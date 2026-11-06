import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/plan_export_service.dart';
import '../../../../data/models/attendance/attendance.dart' show AttendanceType;
import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/plan/plan.dart';
import '../widgets/plan_export_actions.dart';
import '../widgets/plan_view_list.dart';
import '../widgets/ion_items.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive_platform.dart' show useIosLook;
import '../../../../shared/widgets/adaptive/app_toolbar.dart' show ToolbarButtonGroup;
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';

/// Read-only Ablaufplan with chips for several plans, live mode and export
/// (Ionic `PlanViewerComponent`). Opened as full screen dialog.
class PlanViewerPage extends ConsumerStatefulWidget {
  const PlanViewerPage({
    super.key,
    required this.attendance,
    this.plan,
    this.title,
    this.defaultLive = false,
    this.onEdit,
    this.fieldWarning,
    this.songAction,
  });

  /// Termin (date + plans). For ad-hoc plans only `date` and `plan` are set.
  final PlanAttendance attendance;

  /// Explicit plan to show (otherwise the Termin's plans with chips).
  final Plan? plan;
  final String? title;
  final bool defaultLive;

  /// Shows an edit button; called with the index of the shown plan.
  final void Function(int planIndex)? onEdit;
  final String? Function(PlanField field)? fieldWarning;

  /// Ionic 4.17.26: rows of Werke open the score options (member views).
  final VoidCallback? Function(PlanField field)? songAction;

  @override
  ConsumerState<PlanViewerPage> createState() => _PlanViewerPageState();
}

class _PlanViewerPageState extends ConsumerState<PlanViewerPage> {
  late List<Plan> _plans;
  List<String> _labels = const [];
  int _index = 0;
  int _todayIndex = -1;
  bool _live = false;

  @override
  void initState() {
    super.initState();
    final att = widget.attendance;
    final all = PlanUtils.allPlans(att);
    if (widget.plan == null && all.length > 1) {
      _plans = all;
      _labels = [for (var i = 0; i < all.length; i++) PlanUtils.planLabel(att, i, all)];
      _index = PlanUtils.todayPlanIndex(att);
      final d = PlanUtils.planDate(att, _index, all);
      final now = DateTime.now();
      _todayIndex = d != null && d.year == now.year && d.month == now.month && d.day == now.day ? _index : -1;
    } else {
      _plans = [widget.plan ?? att.plan ?? const Plan()];
    }
    _live = widget.defaultLive || _isLiveNow();
  }

  Plan get _plan => _plans[_index];

  DateTime? get _date =>
      _labels.isNotEmpty ? PlanUtils.planDate(widget.attendance, _index, _plans) : DateTime.tryParse(widget.attendance.date);

  bool _isLiveNow() => PlanUtils.isLiveNow(_date, _plan.time, _plan.fields);

  String get _title {
    final t = _plan.title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return widget.title ?? context.l10n.plansRunSheet;
  }

  PlanExportPage _page(int i, AttendanceType? type) {
    final p = _plans[i];
    final date = _labels.isNotEmpty ? PlanUtils.planDate(widget.attendance, i, _plans) : DateTime.tryParse(widget.attendance.date);
    final label = _labels.isNotEmpty ? ' · ${_labels[i]}' : '';
    return PlanExportPage(
      title: _exportTitle(p, type),
      subtitle: '${PlanUtils.longDate(date)}$label',
      time: p.time,
      end: p.end,
      fields: p.fields,
    );
  }

  /// Ionic plan viewer export: plan title, else `Utils.getPlanningTitle(type,
  /// typeInfo)` of the Termin's type; plans without a known type (shared /
  /// org plans) keep the title they were opened with.
  String _exportTitle(Plan p, AttendanceType? type) {
    final t = p.title?.trim();
    if (t != null && t.isNotEmpty) return t;
    if (type == null) return widget.title ?? context.l10n.plansRunSheet;
    return PlanUtils.planningTitle(
      planningTitle: type.planningTitle,
      typeName: type.name,
      typeInfo: widget.attendance.typeInfo,
    );
  }

  String _fileName(AttendanceType? type) {
    final date = _date;
    return '${_exportTitle(_plan, type)}_${date != null ? '${date.day.toString().padLeft(2, '0')}_${date.month.toString().padLeft(2, '0')}_${date.year}' : ''}';
  }

  Future<void> _export() async {
    // Resolved before the sheet: titles and file names use the same type.
    final type = await resolvePlanAttendanceType(ref, widget.attendance);
    if (!mounted) return;
    if (_labels.isNotEmpty) {
      // Ionic: openPlanShareSheet (segment "Nur …" / "Alle n Pläne" + options).
      final choice = await showPlanShareSheet(
        context,
        ref,
        currentLabel: _labels[_index],
        planCount: _labels.length,
      );
      if (choice == null || !mounted) return;
      await runPlanExport(
        context,
        ref,
        choice.action,
        pages: choice.all ? [for (var i = 0; i < _plans.length; i++) _page(i, type)] : [_page(_index, type)],
        fileName: choice.all ? '${_fileName(type)}_alle' : _fileName(type),
      );
      return;
    }
    // P10_SELF_PLAN: Ionic plan-viewer export sheet (no image entry).
    await showPlanExportSheet(
      context,
      ref,
      pages: () => [_page(_index, type)],
      fileName: _fileName(type),
      pdfLabel: context.l10n.planningExportPdf,
      pdf2xLabel: context.l10n.planningExportPdfA5,
      withImage: false,
    );
  }

  void _select(int i) => setState(() {
    _index = i;
    _live = _isLiveNow();
  });

  /// REDESIGN (Termin-Werkzeuge T1): Beta detail page. "Ganzer Ablauf /
  /// Jetzt" replaces the live button, plans are chips, ••• exports.
  Widget _buildBeta(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final date = _date;
    final startMin = PlanUtils.parseTimeToMinutes(_plan.time);
    final meta = [
      if (date != null) PlanUtils.longDate(date),
      if (startMin != null && _plan.fields.isNotEmpty)
        '${PlanUtils.formatMinutes(startMin)}–${PlanUtils.formatMinutes(startMin + PlanUtils.totalMinutes(_plan.fields))}',
    ].join(' · ');
    final liveNow = _isLiveNow();
    return RdPage(
      children: [
        Row(
          children: [
            Expanded(
              child: RdBackLink(label: l10n.redesignPlanBack, onTap: () => Navigator.of(context).maybePop()),
            ),
            if (widget.onEdit != null) ...[
              RdCircleButton(
                key: const Key('rd-plan-view-edit'),
                icon: Icons.edit_outlined,
                label: l10n.attendanceEditRunSheet,
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onEdit!(_index);
                },
              ),
              const SizedBox(width: 8),
            ],
            RdCircleButton(
              key: const Key('rd-plan-view-more'),
              icon: Icons.more_horiz,
              label: l10n.planningExport,
              onPressed: _export,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(_title, style: RdType.title(p))),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(meta, style: RdType.meta(p, size: 15)),
        ],
        if (_labels.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _labels.length; i++)
                RdChoiceChip(
                  label: i == _todayIndex ? '${_labels[i]} · ${l10n.redesignEventPlanNowPill}' : _labels[i],
                  selected: i == _index,
                  onTap: () => _select(i),
                ),
            ],
          ),
        ],
        if (liveNow) ...[
          const SizedBox(height: 16),
          RdSegmented<bool>(
            values: const [true, false],
            selected: _live,
            labelOf: (v) => v ? l10n.redesignPlanViewNow : l10n.redesignPlanViewWhole,
            onChanged: (v) => setState(() => _live = v),
          ),
        ],
        const SizedBox(height: 16),
        if (_plan.fields.isEmpty)
          RdCard(
            child: Text(l10n.planningNoPlanAvailable, textAlign: TextAlign.center, style: RdType.body(p)),
          )
        else
          RdCard(
            padding: EdgeInsets.zero,
            child: PlanViewList(
              plan: _plan,
              date: date,
              liveMode: _live,
              fieldWarning: widget.fieldWarning,
              songAction: widget.songAction,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.rdSkin != null) return _buildBeta(context);
    final date = _date;
    return Scaffold(
      appBar: AppBar(
        // Ionic: modal with close button at the start.
        // IOS_PAGES3: iOS → ion-buttons in a Liquid Glass capsule.
        leadingWidth: useIosLook(context) ? 68 : null,
        leading: ToolbarButtonGroup(children: [
          IconButton(
            tooltip: context.l10n.commonClose,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ]),
        title: Text(date != null ? DateFormat(dateFmt()).format(date) : _title),
        actions: [
          ToolbarButtonGroup(children: [
          if (_isLiveNow())
            IconButton(
              tooltip: _live ? context.l10n.planningFlutterLiveModeEnd : context.l10n.planningFlutterLiveMode,
              // Ionic: radio / radio-outline, danger while live.
              color: _live ? AppColors.danger : AppColors.primary,
              icon: Icon(_live ? Icons.sensors : Icons.sensors_outlined),
              onPressed: () => setState(() => _live = !_live),
            ),
          if (widget.onEdit != null)
            IconButton(
              tooltip: context.l10n.attendanceEditRunSheet,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onEdit!(_index);
              },
            ),
          IconButton(
            tooltip: context.l10n.planningExport,
            icon: const Icon(Icons.ios_share),
            onPressed: _export,
          ),
          ]),
        ],
      ),
      body: ListView(
        children: [
          if (_labels.isNotEmpty)
            PlanChips(
              labels: _labels,
              selected: _index,
              todayIndex: _todayIndex,
              onSelected: (i) => setState(() {
                _index = i;
                _live = _isLiveNow();
              }),
            ),
          if (_plan.fields.isEmpty)
            // Ionic: ion-card with "Kein Ablaufplan vorhanden".
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.l10n.planningNoPlanAvailable, textAlign: TextAlign.center),
              ),
            )
          else
            // Ionic: ion-list [inset] with header "Ablauf".
            IonInsetList(
              header: context.l10n.planningRunSheet,
              children: [
                PlanViewList(
                  plan: _plan,
                  date: date,
                  liveMode: _live,
                  fieldWarning: widget.fieldWarning,
                  songAction: widget.songAction,
                ),
              ],
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Opens the plan viewer as full screen dialog.
Future<void> showPlanViewer(
  BuildContext context, {
  required PlanAttendance attendance,
  Plan? plan,
  String? title,
  bool defaultLive = false,
  void Function(int planIndex)? onEdit,
  String? Function(PlanField field)? fieldWarning,
  VoidCallback? Function(PlanField field)? songAction,
}) {
  return Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => PlanViewerPage(
      attendance: attendance,
      plan: plan,
      title: title,
      defaultLive: defaultLive,
      onEdit: onEdit,
      fieldWarning: fieldWarning,
      songAction: songAction,
    ),
  ));
}
