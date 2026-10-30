import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/group_providers.dart'; // P10_ATTENDANCE
import '../../../../../core/providers/plan_providers.dart';
import '../../../../../core/providers/song_providers.dart'; // P10_ATTENDANCE
import '../../../../../core/providers/tenant_providers.dart'; // P10_ATTENDANCE
import '../../../../../core/providers/team_org_providers.dart'; // PROTOCOL
import '../../../../../core/services/plan_export_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/plan_utils.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/models/plan/plan.dart';
import '../../../../planning/presentation/widgets/plan_export_actions.dart';
import '../../../../planning/presentation/widgets/plan_field_dialogs.dart';
import '../../../../planning/presentation/widgets/plan_view_list.dart';
import '../../../../songs/presentation/utils/song_utils.dart'; // P10_ATTENDANCE
import '../../../../team_organization/presentation/widgets/attendance_protocol_section.dart'; // PROTOCOL
import '../../../../../l10n/l10n.dart';
import 'attendance_accordion.dart';
import '../../../../../core/services/error_reporter.dart';

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
    this.onEditPlan,
    this.initiallyExpanded = false,
  });

  final Attendance attendance;
  final VoidCallback onEdit;
  final VoidCallback onExportPdf;
  final void Function(bool) onSharePlanChanged;
  final VoidCallback? onCreate;
  final VoidCallback? onSendViaTelegram;

  /// P10_ATTENDANCE: Ionic editPlan() opens the editor on the plan shown
  /// in the accordion (`initialPlanIndex: this.planIndex`). Falls back to
  /// [onEdit] / [onCreate] when not set.
  final void Function(int planIndex)? onEditPlan;
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
        } catch (e, st) {
          ErrorReporter.report(e, st, where: 'plan_accordion');
        }
      }
      return loaded.copyWith(plan: plan);
    }
    Plan? plan;
    final raw = widget.attendance.plan;
    if (raw != null && raw.isNotEmpty) {
      try {
        plan = Plan.fromJson(raw);
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'plan_accordion');
      }
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
    return (att.typeInfo?.isNotEmpty ?? false) ? att.typeInfo! : context.l10n.plansRunSheet;
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
          PlanSheetAction('all', context.l10n.planningExportPdfAll, icon: Icons.picture_as_pdf),
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

  /// P10_ATTENDANCE: Ionic `getMissingGroups(field.songId)` – red line
  /// under songs of the plan (not for "general" tenants).
  String? _missingGroups(PlanField field) {
    if (field.songId == null || ref.read(currentTenantProvider)?.type == 'general') return null;
    final songs = ref.read(songsProvider).valueOrNull ?? const [];
    final ids = songs.where((s) => s.id == field.songId).firstOrNull?.instrumentIds;
    if (ids == null || ids.isEmpty) return null;
    final text = SongUtils.missingInstrumentsText(
      ids,
      ref.read(groupsProvider).valueOrNull ?? const [],
      ref.read(groupCategoriesProvider).valueOrNull ?? const [],
    );
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    // P10_ATTENDANCE: keep the data of the missing-groups line loaded
    ref.watch(songsProvider);
    ref.watch(groupCategoriesProvider);
    final att = _planAttendance();
    final plans = PlanUtils.allPlans(att);
    if (_planIndex < 0 || _planIndex >= plans.length) {
      _planIndex = plans.isEmpty ? 0 : PlanUtils.todayPlanIndex(att).clamp(0, plans.length - 1);
    }
    final plan = plans.isEmpty ? null : plans[_planIndex];
    final hasPlan = plan != null && plan.fields.isNotEmpty;
    final date = plan == null ? null : PlanUtils.planDate(att, _planIndex, plans) ?? DateTime.tryParse(att.date);
    // P10_ATTENDANCE: Ionic isPlanLiveNow() → live mode (active slot +
    // countdown) from 5 min before the start until 15 min after the end.
    final liveMode = plan != null &&
        hasPlanFields(plan) &&
        PlanUtils.isLiveNow(date?.toLocal(), plan.time, plan.fields);
    // Ionic todayPlanChip: the chip of today's plan gets the "Heute" mark.
    final todayIndex = plans.length > 1 ? todayChipIndex(att, plans) : -1;
    void edit() => widget.onEditPlan != null
        ? widget.onEditPlan!(plans.isEmpty ? 0 : _planIndex)
        : widget.onEdit();
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
      title: Text(context.l10n.attendanceAddTopics, style: primaryStyle),
      onTap: () => openAgendaPickerForAttendance(context, ref,
          attendanceId: widget.attendance.id!, type: protocolType),
    );

    // IOS_DETAIL: shared accordion (iOS header look, Ionic state reset)
    return AttendanceAccordion(
        controller: _controller,
        initiallyExpanded: widget.initiallyExpanded,
        clipBehavior: Clip.none,
        title: Text(hasProtocol ? context.l10n.attendanceRunSheetAgenda : context.l10n.plansRunSheet),
        children: [
          if (!hasPlan) ...[
            if (canAddTopics) addTopicsRow,
            ListTile(
              dense: true,
              title: Text(context.l10n.attendanceCreateRunSheet, style: primaryStyle),
              onTap: widget.onEditPlan != null ? edit : (widget.onCreate ?? widget.onEdit),
            ),
          ] else ...[
            if (plans.length > 1)
              PlanChips(
                labels: [for (var i = 0; i < plans.length; i++) PlanUtils.planLabel(att, i, plans)],
                selected: _planIndex,
                todayIndex: todayIndex,
                onSelected: (i) => setState(() => _planIndex = i),
              ),
            PlanViewList(
              plan: plan,
              date: date,
              showStartEnd: true,
              liveMode: liveMode,
              fieldWarning: _missingGroups,
              onFieldTap: hasProtocol && plan.fields.any((f) => f.agendaItemId != null)
                  ? (i) => openPlanFieldTopic(context, ref, plan.fields[i].agendaItemId)
                  : null,
            ),
            if (canAddTopics) addTopicsRow,
            ListTile(
              dense: true,
              title: Text(context.l10n.attendanceEditRunSheet, style: primaryStyle),
              onTap: edit,
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.ios_share, color: AppColors.primary),
              title: Text(context.l10n.attendanceShare, style: primaryStyle),
              onTap: () => _export(att, plans, _planIndex),
            ),
            // UX_ATT: no extra "Ablaufplan anzeigen" row (not in Ionic; the
            // viewer opens from the Termine list).
          ],
        ],
    );
  }
}

/// P10_ATTENDANCE: Ionic `isPlanLiveNow` needs a time and at least one field.
bool hasPlanFields(Plan plan) => plan.time.isNotEmpty && plan.fields.isNotEmpty;

/// P10_ATTENDANCE: Ionic `todayPlanChip` – index of today's plan when that
/// plan's day is today, otherwise -1.
int todayChipIndex(PlanAttendance att, List<Plan> plans, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final index = PlanUtils.todayPlanIndex(att, n);
  if (index < 0 || index >= plans.length) return -1;
  final day = PlanUtils.planDate(att, index, plans)?.toLocal();
  if (day == null) return -1;
  return DateUtils.isSameDay(day, n) ? index : -1;
}
