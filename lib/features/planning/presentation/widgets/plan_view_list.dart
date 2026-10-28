import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../l10n/l10n.dart';
import 'ion_items.dart';

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
    final numbers = PlanUtils.topNumbers(fields);
    final start = PlanUtils.parseTimeToMinutes(plan.time);
    final now = DateTime.now();
    final active = widget.liveMode ? PlanUtils.activeIndex(widget.date, plan.time, fields, now) : -1;
    final activeField = active >= 0 && active < fields.length ? fields[active] : null;
    final startCountdown = widget.liveMode ? PlanUtils.startCountdown(widget.date, plan.time, now) : '';

    final theme = Theme.of(context);
    // Ionic plan-viewer (iOS): h2 weight 500, grey `p` lines, grey ion-note
    // minutes at the end, full item lines.
    const pStyle = TextStyle(color: AppColors.medium, fontSize: 14);
    const noteStyle = TextStyle(color: AppColors.medium, fontSize: 15);
    final children = <Widget>[];
    if (widget.showStartEnd) {
      children.add(ListTile(
        title: Text(context.l10n.attendanceStartLabel, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: startCountdown.isNotEmpty
            ? Text(startCountdown, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500))
            : null,
        trailing: Text(context.l10n.attendanceTimeOClock(PlanUtils.formatTime(plan.time)), style: noteStyle),
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
      final warning = widget.fieldWarning?.call(f);
      if (warning != null && warning.isNotEmpty) {
        lines.add(Text(warning, style: const TextStyle(color: AppColors.danger, fontSize: 14)));
      }
      if (isHead && start != null) {
        final conductor = (f.conductor ?? '').isNotEmpty ? ' | ${f.conductor}' : '';
        lines.add(Text('${PlanUtils.groupRange(start, fields, i)}$conductor', style: pStyle));
      } else if (!isNote && start != null) {
        final conductor = (f.conductor ?? '').isNotEmpty ? ' | ${f.conductor}' : '';
        lines.add(Text('${PlanUtils.formatMinutes(PlanUtils.startMinutesAt(start, fields, i))}$conductor',
            style: pStyle));
      }
      if (!isNote && (f.info ?? '').isNotEmpty) {
        lines.add(Text(f.info!, style: pStyle.copyWith(fontStyle: FontStyle.italic)));
      }

      Widget? trailing;
      if (!isNote) {
        trailing = isActive
            ? IonBadge(
                label: PlanUtils.activeCountdown(widget.date, plan.time, fields, active, now),
                color: AppColors.primary,
              )
            : Text(
                context.l10n.planningMinShort(PlanUtils.displayMinutes(f, fields)),
                style: isHead
                    ? noteStyle.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF808289))
                    : noteStyle,
              );
      }
      final extra = widget.trailingBuilder?.call(i);
      if (extra != null) {
        trailing = Row(mainAxisSize: MainAxisSize.min, children: [if (trailing != null) trailing, extra]);
      }

      Widget row = ListTile(
        onTap: widget.onFieldTap != null ? () => widget.onFieldTap!(i) : null,
        // Ionic `.group-child`: --padding-start 34px.
        contentPadding: EdgeInsets.only(left: isChild ? 34 : 16, right: 16),
        // Ionic plan-viewer `fieldName`: "TOP n · Titel" for agenda fields.
        title: Text(
          PlanUtils.fieldDisplayName(f, numbers),
          style: TextStyle(
            fontWeight: isHead ? FontWeight.w700 : (isActive ? FontWeight.w600 : FontWeight.w500),
            fontStyle: isNote ? FontStyle.italic : FontStyle.normal,
            color: isActive ? AppColors.primary : (isNote ? AppColors.medium : null),
          ),
        ),
        subtitle: lines.isEmpty
            ? null
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines),
        trailing: trailing,
      );
      if (isChild) {
        // Ionic `.group-child::before`: 2px grey line at 20px.
        row = Stack(children: [
          row,
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            child: Container(width: 2, color: theme.brightness == Brightness.dark ? const Color(0xFF444444) : const Color(0xFFCCCCCC)),
          ),
        ]);
      }
      children.add(Opacity(
        // Ionic `.done-slot`: opacity .4
        opacity: isDone ? 0.4 : 1,
        child: Container(
          // Ionic `.active-slot` / `.active-group`: tinted + 3px primary border.
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary.withValues(alpha: 0.12) : null,
            border: isActive || isActiveGroup
                ? const Border(left: BorderSide(color: AppColors.primary, width: 3))
                : null,
          ),
          child: row,
        ),
      ));
    }

    if (widget.showStartEnd) {
      final end = plan.end.isNotEmpty
          ? PlanUtils.formatTime(plan.end)
          : (start != null ? PlanUtils.formatMinutes(start + PlanUtils.totalMinutes(fields)) : '');
      if (end.isNotEmpty) {
        children.add(ListTile(
          title: Text(context.l10n.attendanceEnd),
          trailing: Text(context.l10n.attendanceTimeOClock(end), style: noteStyle),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 16),
          children[i],
        ],
      ],
    );
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
    // Ionic app-plan-chips: ion-chip (13px), selected = color primary,
    // others outline medium; horizontally scrolling row.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _PlanChip(
                label: i == todayIndex ? '${labels[i]} ${context.l10n.planningToday}' : labels[i],
                selected: i == selected,
                onTap: () {
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

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.medium;
    final shape = StadiumBorder(
      side: selected ? BorderSide.none : BorderSide(color: AppColors.medium.withValues(alpha: 0.32)),
    );
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? AppColors.primaryDark : color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
