import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/providers/plan_providers.dart';
import '../../../../../core/providers/team_org_providers.dart'; // PROTOCOL
import '../../../../../core/services/plan_export_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/plan_utils.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/models/plan/plan.dart';
import '../../../../planning/presentation/pages/plan_viewer_page.dart';
import '../../../../planning/presentation/widgets/plan_export_actions.dart';
import '../../../../planning/presentation/widgets/plan_field_dialogs.dart';
import '../../../../planning/presentation/widgets/plan_view_list.dart';
import '../../../../team_organization/presentation/widgets/attendance_protocol_section.dart'; // PROTOCOL

/// Accordion widget for displaying attendance plan/schedule.
///
/// ORG_PLANS: renders the Ionic plan format (`time`/`end`, Programmblöcke,
/// Notizen, several plans per Termin) and exports via [PlanExportService]
/// (PDF, 2x A5, Bild, Telegram). [onExportPdf] / [onSendViaTelegram] are kept
/// for API compatibility and are no longer used.
class PlanAccordion extends ConsumerStatefulWidget {
  const PlanAccordion({
    super.key,
    required this.attendance,
    required this.onEdit,
    required this.onExportPdf,
    required this.onSharePlanChanged,
    this.onCreate,
    this.onSendViaTelegram,
    this.initiallyExpanded = false,
  });

  final Attendance attendance;
  final VoidCallback onEdit;
  final VoidCallback onExportPdf;
  final void Function(bool) onSharePlanChanged;
  final VoidCallback? onCreate;
  final VoidCallback? onSendViaTelegram;
  final bool initiallyExpanded;

  @override
  ConsumerState<PlanAccordion> createState() => _PlanAccordionState();
}

class _PlanAccordionState extends ConsumerState<PlanAccordion> {
  final ExpansionTileController _controller = ExpansionTileController();
  bool _wasInitiallyExpanded = false;
  int _planIndex = -1;

  @override
  void didUpdateWidget(PlanAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Expand the tile when initiallyExpanded changes from false to true
    if (widget.initiallyExpanded && !_wasInitiallyExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.expand();
        }
      });
    }
    _wasInitiallyExpanded = widget.initiallyExpanded;
  }

  /// Plan columns of the Termin; falls back to `attendance.plan` while loading.
  PlanAttendance _planAttendance() {
    final id = widget.attendance.id;
    final loaded = id == null ? null : ref.watch(planAttendanceByIdProvider(id)).valueOrNull;
    if (loaded != null) {
      // The detail page holds the freshest `plan` (realtime); keep extra plans from the plan query.
      Plan? plan = loaded.plan;
      final raw = widget.attendance.plan;
      if (raw != null && raw.isNotEmpty) {
        try {
          plan = Plan.fromJson(raw);
        } catch (_) {}
      }
      return loaded.copyWith(plan: plan);
    }
    Plan? plan;
    final raw = widget.attendance.plan;
    if (raw != null && raw.isNotEmpty) {
      try {
        plan = Plan.fromJson(raw);
      } catch (_) {}
    }
    return PlanAttendance(
      id: id,
      date: widget.attendance.date,
      durationDays: widget.attendance.durationDays,
      plan: plan,
      typeInfo: widget.attendance.typeInfo,
      sharePlan: widget.attendance.sharePlan,
    );
  }

  String _title(PlanAttendance att, Plan plan) {
    final t = plan.title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return (att.typeInfo?.isNotEmpty ?? false) ? att.typeInfo! : 'Ablaufplan';
  }

  Future<void> _export(PlanAttendance att, List<Plan> plans, int index) async {
    PlanExportPage page(int i) {
      final p = plans[i];
      final label = plans.length > 1 ? ' · ${PlanUtils.planLabel(att, i, plans)}' : '';
      return PlanExportPage(
        title: _title(att, p),
        subtitle: '${PlanUtils.longDate(PlanUtils.planDate(att, i, plans) ?? DateTime.tryParse(att.date))}$label',
        time: p.time,
        end: p.end,
        fields: p.fields,
      );
    }

    final d = DateTime.tryParse(att.date);
    final date = d == null ? '' : '_${d.day.toString().padLeft(2, '0')}_${d.month.toString().padLeft(2, '0')}_${d.year}';
    await showPlanExportSheet(
      context,
      ref,
      pages: () => [page(index)],
      fileName: '${_title(att, plans[index])}$date',
      extraActions: [
        if (plans.length > 1)
          const PlanSheetAction('all', 'PDF exportieren (alle Pläne)', icon: Icons.picture_as_pdf),
      ],
      onExtraAction: (_) => runPlanExport(
        context,
        ref,
        PlanExportAction.pdf,
        pages: [for (var i = 0; i < plans.length; i++) page(i)],
        fileName: '${_title(att, plans[index])}$date',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final att = _planAttendance();
    final plans = PlanUtils.allPlans(att);
    if (_planIndex < 0 || _planIndex >= plans.length) {
      _planIndex = plans.isEmpty ? 0 : PlanUtils.todayPlanIndex(att).clamp(0, plans.length - 1);
    }
    final plan = plans.isEmpty ? null : plans[_planIndex];
    final hasPlan = plan != null && plan.fields.isNotEmpty;
    final date = plan == null ? null : PlanUtils.planDate(att, _planIndex, plans) ?? DateTime.tryParse(att.date);
    // PROTOCOL: Tagesordnung of protocol types ("Themen aufnehmen", TOP → Thema)
    final protocolType = ref.watch(protocolTypeByIdProvider(widget.attendance.typeId));
    final hasProtocol = protocolType?.enableProtocol ?? false;
    final canAddTopics = hasProtocol && ref.watch(isTeamLeaderProvider) && _planIndex == 0 && widget.attendance.id != null;
    // UX_ATT: Ionic rows below the plan: Themen aufnehmen, Ablaufplan
    // bearbeiten / erstellen, Teilen (export sheet). "Mit Mitgliedern teilen"
    // lives in the planning page like in Ionic.
    const primaryStyle = TextStyle(color: AppColors.primary);
    final addTopicsRow = ListTile(
      dense: true,
      leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
      title: const Text('Themen aufnehmen', style: primaryStyle),
      onTap: () => openAgendaPickerForAttendance(context, ref,
          attendanceId: widget.attendance.id!, type: protocolType),
    );

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      child: ExpansionTile(
        controller: _controller,
        initiallyExpanded: widget.initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(hasProtocol ? 'Ablaufplan & Tagesordnung' : 'Ablaufplan'),
        children: [
          if (!hasPlan) ...[
            if (canAddTopics) addTopicsRow,
            ListTile(
              dense: true,
              title: const Text('Ablaufplan erstellen', style: primaryStyle),
              onTap: widget.onCreate ?? widget.onEdit,
            ),
          ] else ...[
            if (plans.length > 1)
              PlanChips(
                labels: [for (var i = 0; i < plans.length; i++) PlanUtils.planLabel(att, i, plans)],
                selected: _planIndex,
                onSelected: (i) => setState(() => _planIndex = i),
              ),
            PlanViewList(
              plan: plan,
              date: date,
              showStartEnd: true,
              onFieldTap: hasProtocol && plan.fields.any((f) => f.agendaItemId != null)
                  ? (i) => openPlanFieldTopic(context, ref, plan.fields[i].agendaItemId)
                  : null,
            ),
            if (canAddTopics) addTopicsRow,
            ListTile(
              dense: true,
              title: const Text('Ablaufplan bearbeiten', style: primaryStyle),
              onTap: widget.onEdit,
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.ios_share, color: AppColors.primary),
              title: const Text('Teilen', style: primaryStyle),
              onTap: () => _export(att, plans, _planIndex),
            ),
            // Flutter-only extra: read-only / live plan viewer
            ListTile(
              dense: true,
              leading: const Icon(Icons.play_circle_outline, color: AppColors.primary),
              title: const Text('Ablaufplan anzeigen', style: primaryStyle),
              onTap: () => showPlanViewer(
                context,
                attendance: att,
                title: _title(att, plan),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
