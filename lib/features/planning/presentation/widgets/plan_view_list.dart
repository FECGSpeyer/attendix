import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../l10n/l10n.dart';

/// Read-only list of an Ablaufplan with optional live mode (countdown of the
/// running Programmpunkt), ported from Ionic `PlanViewerComponent`.
class PlanViewList extends StatefulWidget {
  const PlanViewList({
    super.key,
    required this.plan,
    required this.date,
    this.liveMode = false,
    this.fieldWarning,
    this.onFieldTap,
    this.trailingBuilder,
    this.showStartEnd = true,
  });

  final Plan plan;

  /// Calendar day of the plan (needed for live mode).
  final DateTime? date;
  final bool liveMode;
  final String? Function(PlanField field)? fieldWarning;

  /// Edit mode of shared plans: tap on a row.
  final void Function(int index)? onFieldTap;

  /// Extra trailing widget per row (e.g. delete button in edit mode).
  final Widget? Function(int index)? trailingBuilder;
  final bool showStartEnd;

  @override
  State<PlanViewList> createState() => _PlanViewListState();
}

class _PlanViewListState extends State<PlanViewList> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(PlanViewList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.liveMode != widget.liveMode) _syncTimer();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (widget.liveMode) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final fields = plan.fields;
    final start = PlanUtils.parseTimeToMinutes(plan.time);
    final now = DateTime.now();
    final active = widget.liveMode ? PlanUtils.activeIndex(widget.date, plan.time, fields, now) : -1;
    final activeField = active >= 0 && active < fields.length ? fields[active] : null;
    final startCountdown = widget.liveMode ? PlanUtils.startCountdown(widget.date, plan.time, now) : '';

    final children = <Widget>[];
    if (widget.showStartEnd) {
      children.add(ListTile(
        dense: true,
        leading: const Icon(Icons.play_arrow, color: AppColors.success),
        title: Text(context.l10n.attendanceStartLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: startCountdown.isNotEmpty
            ? Text(startCountdown, style: const TextStyle(color: AppColors.primary))
            : null,
        trailing: Text(context.l10n.attendanceTimeOClock(PlanUtils.formatTime(plan.time))),
      ));
    }

    for (var i = 0; i < fields.length; i++) {
      final f = fields[i];
      if (PlanUtils.isAgendaPlaceholder(f)) continue;
      final isHead = PlanUtils.isGroupHead(f);
      final isNote = PlanUtils.isNote(f);
      final isChild = f.groupId != null;
      final isActive = widget.liveMode && i == active;
      final isActiveGroup = widget.liveMode && isHead && activeField?.groupId == f.id;
      final isDone = widget.liveMode && active >= 0 && i < active && !isActiveGroup;

      final lines = <Widget>[];
      if (isHead && start != null) {
        final conductor = (f.conductor ?? '').isNotEmpty ? ' | ${f.conductor}' : '';
        lines.add(Text('${PlanUtils.groupRange(start, fields, i)}$conductor'));
      } else if (!isNote && start != null) {
        final conductor = (f.conductor ?? '').isNotEmpty ? ' | ${f.conductor}' : '';
        lines.add(Text('${PlanUtils.formatMinutes(PlanUtils.startMinutesAt(start, fields, i))}$conductor'));
      }
      final warning = widget.fieldWarning?.call(f);
      if (warning != null && warning.isNotEmpty) {
        lines.add(Text(warning, style: const TextStyle(color: AppColors.danger)));
      }
      if (!isNote && (f.info ?? '').isNotEmpty) {
        lines.add(Text(f.info!, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)));
      }

      Widget? trailing;
      if (!isNote) {
        trailing = isActive
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  PlanUtils.activeCountdown(widget.date, plan.time, fields, active, now),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            : Text(context.l10n.planningMinShort(PlanUtils.displayMinutes(f, fields)),
                style: TextStyle(fontWeight: isHead ? FontWeight.bold : FontWeight.normal));
      }
      final extra = widget.trailingBuilder?.call(i);
      if (extra != null) {
        trailing = Row(mainAxisSize: MainAxisSize.min, children: [if (trailing != null) trailing, extra]);
      }

      children.add(Opacity(
        opacity: isDone ? 0.5 : 1,
        child: Container(
          margin: EdgeInsets.only(left: isChild ? 20 : 0),
          decoration: BoxDecoration(
            color: isActive || isActiveGroup
                ? AppColors.primary.withValues(alpha: 0.12)
                : isHead
                    ? AppColors.primary.withValues(alpha: 0.05)
                    : isNote
                        ? AppColors.medium.withValues(alpha: 0.08)
                        : null,
            border: isChild
                ? Border(left: BorderSide(color: AppColors.primary.withValues(alpha: 0.4), width: 2))
                : null,
          ),
          child: ListTile(
            dense: true,
            onTap: widget.onFieldTap != null ? () => widget.onFieldTap!(i) : null,
            title: Text(
              f.name,
              style: TextStyle(
                fontWeight: isHead || isActive ? FontWeight.bold : FontWeight.w500,
                fontStyle: isNote ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            subtitle: lines.isEmpty
                ? null
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines),
            trailing: trailing,
          ),
        ),
      ));
    }

    if (widget.showStartEnd) {
      final end = plan.end.isNotEmpty
          ? PlanUtils.formatTime(plan.end)
          : (start != null ? PlanUtils.formatMinutes(start + PlanUtils.totalMinutes(fields)) : '');
      if (end.isNotEmpty) {
        children.add(ListTile(
          dense: true,
          leading: const Icon(Icons.stop, color: AppColors.danger),
          title: Text(context.l10n.attendanceEnd, style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: Text(context.l10n.attendanceTimeOClock(end)),
        ));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// Small chip row to switch between the Ablaufpläne of one Termin.
class PlanChips extends StatelessWidget {
  const PlanChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.todayIndex = -1,
    this.trailing,
  });

  final List<String> labels;
  final int selected;
  final int todayIndex;
  final ValueChanged<int> onSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(i == todayIndex ? '${labels[i]} ${context.l10n.planningToday}' : labels[i]),
                selected: i == selected,
                onSelected: (_) {
                  if (i != selected) onSelected(i);
                },
              ),
            ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
