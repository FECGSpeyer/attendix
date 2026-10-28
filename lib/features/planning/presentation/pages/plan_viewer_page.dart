import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/plan_export_service.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/plan/plan.dart';
import '../widgets/plan_export_actions.dart';
import '../widgets/plan_view_list.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

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

  Future<void> _export() async {
    var all = false;
    if (_labels.length > 1) {
      final scope = await showAppActionSheet<bool>(
        context,
        actions: [
          AppActionSheetAction(value: false, label: context.l10n.planningOnlyLabel(_labels[_index])),
          AppActionSheetAction(value: true, label: context.l10n.planningAllPlans(_labels.length)),
        ],
      );
      if (scope == null) return;
      all = scope;
    }
    if (!mounted) return;
    final date = _date;
    await showPlanExportSheet(
      context,
      ref,
      pages: () => all ? [for (var i = 0; i < _plans.length; i++) _page(i)] : [_page(_index)],
      fileName: '${_title}_${date != null ? '${date.day.toString().padLeft(2, '0')}_${date.month.toString().padLeft(2, '0')}_${date.year}' : ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;
    return Scaffold(
      appBar: AppBar(
        // Ionic: modal with close button at the start.
        leading: IconButton(
          tooltip: context.l10n.commonClose,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(date != null ? DateFormat(dateFmt()).format(date) : _title),
        actions: [
          if (_isLiveNow())
            IconButton(
              tooltip: _live ? context.l10n.planningFlutterLiveModeEnd : context.l10n.planningFlutterLiveMode,
              icon: Icon(_live ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _live ? Colors.red : null),
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.l10n.planningNoPlanAvailable),
            )
          else
            Card(
              margin: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(_title, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  PlanViewList(
                    plan: _plan,
                    date: date,
                    liveMode: _live,
                    fieldWarning: widget.fieldWarning,
                  ),
                ],
              ),
            ),
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
