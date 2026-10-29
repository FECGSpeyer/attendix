import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/plan_export_service.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/plan/plan.dart';
import '../widgets/plan_export_actions.dart';
import '../widgets/plan_view_list.dart';
import '../widgets/ion_items.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive_platform.dart' show useIosLook; // IOS_PAGES3
import '../../../../shared/widgets/adaptive/app_toolbar.dart' show ToolbarButtonGroup; // IOS_PAGES3

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

  PlanExportPage _page(int i) {
    final p = _plans[i];
    final date = _labels.isNotEmpty ? PlanUtils.planDate(widget.attendance, i, _plans) : DateTime.tryParse(widget.attendance.date);
    final label = _labels.isNotEmpty ? ' · ${_labels[i]}' : '';
    final title = (p.title?.trim().isNotEmpty ?? false) ? p.title!.trim() : (widget.title ?? context.l10n.plansRunSheet);
    return PlanExportPage(
      title: title,
      subtitle: '${PlanUtils.longDate(date)}$label',
      time: p.time,
      end: p.end,
      fields: p.fields,
    );
  }

  String get _fileName {
    final date = _date;
    return '${_title}_${date != null ? '${date.day.toString().padLeft(2, '0')}_${date.month.toString().padLeft(2, '0')}_${date.year}' : ''}';
  }

  Future<void> _export() async {
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
        pages: choice.all ? [for (var i = 0; i < _plans.length; i++) _page(i)] : [_page(_index)],
        fileName: _fileName,
      );
      return;
    }
    // P10_SELF_PLAN: Ionic plan-viewer export sheet (no image entry).
    await showPlanExportSheet(
      context,
      ref,
      pages: () => [_page(_index)],
      fileName: _fileName,
      pdfLabel: context.l10n.planningExportPdf,
      pdf2xLabel: context.l10n.planningExportPdfA5,
      withImage: false,
    );
  }

  @override
  Widget build(BuildContext context) {
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
    ),
  ));
}
