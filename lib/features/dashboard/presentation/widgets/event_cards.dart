import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dashboard_utils.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/dashboard/dashboard_event.dart';
import '../../../../data/models/dashboard/dashboard_models.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../planning/presentation/pages/plan_viewer_page.dart';
import 'dashboard_card.dart';
import '../../../../l10n/l10n.dart';

String _timeRange(Attendance a) {
  if (a.startTime == null || a.startTime!.isEmpty) return '';
  final end = a.endTime != null && a.endTime!.isNotEmpty ? ' – ${a.endTime}' : '';
  return ' · ${l10nWithoutContext.homeDashboardFlutterTimeRange('${a.startTime}$end')}';
}

DashTone _percTone(int perc) {
  if (perc >= 75) return DashTone.green;
  if (perc >= 50) return DashTone.orange;
  return DashTone.red;
}

/// "Termine" — next Termin (detailed) and last Termin (compact).
class NextEventCard extends ConsumerWidget {
  const NextEventCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardNextEventProvider);
    final role = ref.watch(effectiveRoleProvider);
    final canOpen = role == Role.admin ||
        role == Role.responsible ||
        role == Role.helper ||
        role == Role.voiceLeaderHelper;

    Future<void> open(int? id) async {
      if (!canOpen || id == null) return;
      await context.push('/attendance/$id');
      ref.invalidate(dashboardNextEventProvider);
    }

    return DashboardCard(
      icon: Icons.calendar_today_outlined,
      title: context.l10n.homeDashboardEvents,
      subtitle: context.l10n.homeDashboardNextAndLast,
      strip: DashStrips.event,
      child: async.when(
        loading: () => const DashLoading(),
        error: (e, _) => DashEmptyRow(icon: Icons.error_outline, text: context.l10n.homeDashboardFlutterLoadFailed(e)),
        data: (s) {
          final next = s.nextEvent;
          final last = s.lastEvent;
          if (next == null && last == null) {
            return DashEmptyRow(
              icon: Icons.calendar_today_outlined,
              text: context.l10n.homeDashboardNoEvents,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (next != null) ...[
                DashDivider(context.l10n.teamOrgNextEvent),
                _nextRow(context, next, () => open(next.attendance.id), canOpen),
                if ((next.attendance.notes ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.description_outlined, size: 16, color: AppColors.medium),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            next.attendance.notes!,
                            style: const TextStyle(fontSize: 13.5, color: AppColors.medium),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (s.nextTotal > 0) ...[
                  _statGrid(context, s),
                  _percRow(context, s),
                ],
              ],
              if (last != null) ...[
                DashDivider(context.l10n.homeDashboardLastEvent),
                DashRow(
                  onTap: canOpen ? () => open(last.attendance.id) : null,
                  showDivider: false,
                  leading: DashTile.date(
                    DashboardUtils.parse(last.attendance.date) ?? DateTime.now(),
                    tone: DashTone.muted,
                  ),
                  title: last.attendance.typeInfo ?? '',
                  subtitle: context.l10n
                      .homeDashboardLastSummary(s.lastPresent, s.lastTotal, s.lastExcused),
                  trailing: DashChip(label: '${s.lastPerc}%', tone: _percTone(s.lastPerc)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _nextRow(BuildContext context, DashboardEvent next, VoidCallback onTap, bool canOpen) {
    final date = DashboardUtils.parse(next.attendance.date) ?? DateTime.now();
    final isToday = DashboardUtils.isSameDay(date, DateTime.now());
    return DashRow(
      onTap: canOpen ? onTap : null,
      leading: DashTile.date(date, tone: DashTone.blue, solid: isToday),
      title: next.attendance.typeInfo ?? '',
      subtitle: '${DashboardUtils.weekday(date)}${_timeRange(next.attendance)}',
      trailing: DashMeta(DashboardUtils.relativeDays(date)),
    );
  }

  Widget _statGrid(BuildContext context, NextEventSummary s) {
    Widget box(DashTone tone, String value, String label, {VoidCallback? onTap}) {
      return Expanded(
        child: Material(
          color: tone.bg(context),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Column(
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: tone.fg(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: tone.fg(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final l10n = context.l10n;
    final excusedLabel = s.nextShiftWorkers > 0
        ? '${l10n.homeDashboardSignedOut}\n${l10n.homeDashboardShiftCount(s.nextShiftWorkers)}'
        : l10n.homeDashboardSignedOut;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          box(DashTone.green, '${s.nextPresent}', l10n.commonStatusPresent),
          const SizedBox(width: 8),
          box(
            DashTone.orange,
            '${s.nextExcused}',
            excusedLabel,
            onTap: s.nextExcused > 0 ? () => _showExcused(context, s) : null,
          ),
          const SizedBox(width: 8),
          box(DashTone.muted, '${s.nextNeutral}', l10n.protocolOpen),
        ],
      ),
    );
  }

  Widget _percRow(BuildContext context, NextEventSummary s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.homeDashboardAverage, style: const TextStyle(fontSize: 13, color: AppColors.medium)),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '${s.nextPerc}%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' · ${context.l10n.homeDashboardTotalCount(s.nextTotal)}'),
                ]),
                style: const TextStyle(fontSize: 13, color: AppColors.medium),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.nextPerc / 100,
              minHeight: 6,
              backgroundColor: DashTone.muted.bg(context),
              color: DashTone.blue.from,
            ),
          ),
        ],
      ),
    );
  }

  void _showExcused(BuildContext context, NextEventSummary s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.3,
        maxChildSize: 1,
        builder: (context, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(context.l10n.homeDashboardSignOuts, style: Theme.of(context).textTheme.titleMedium),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  for (final p in s.nextExcusedPersons)
                    ListTile(
                      title: Text('${p.firstName ?? ''} ${p.lastName ?? ''}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((p.groupName ?? '').isNotEmpty) Text(p.groupName!),
                          if ((p.notes ?? '').isNotEmpty) Text(p.notes!),
                        ],
                      ),
                      trailing: Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: p.status == AttendanceStatus.lateExcused
                            ? AppColors.warning
                            : AppColors.primary,
                        labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                        label: Text(
                          '${p.status == AttendanceStatus.lateExcused ? context.l10n.homeDashboardLateExcusedShort : context.l10n.commonStatusExcused}'
                          '${isWorkExcused(p.notes) ? ' · ${context.l10n.homeDashboardShift}' : ''}',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Aktuelle Werke" — songs planned from today on.
class CurrentSongsCard extends ConsumerWidget {
  const CurrentSongsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardCurrentSongsProvider);
    return DashboardCard(
      icon: Icons.music_note_outlined,
      title: context.l10n.homeDashboardCurrentSongs,
      subtitle: context.l10n.homeDashboardPlannedSongs,
      strip: DashStrips.songs,
      child: async.when(
        loading: () => const DashLoading(),
        error: (e, _) => DashEmptyRow(icon: Icons.error_outline, text: context.l10n.homeDashboardFlutterLoadFailed(e)),
        data: (entries) {
          if (entries.isEmpty) {
            return DashEmptyRow(
              icon: Icons.music_note_outlined,
              text: context.l10n.homeDashboardNoPlannedSongs,
            );
          }
          return Column(
            children: [
              for (final e in entries) _row(context, e),
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, DashboardSongEntry e) {
    final number = e.number == null ? '' : '${e.prefix ?? ''}${e.number}';
    final date = DashboardUtils.parse(e.date);
    final parts = [e.conductorName, e.typeLabel]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    final subtitle = parts.isNotEmpty
        ? parts.join(' · ')
        : (date != null ? DashboardUtils.weekdayDayMonth(date) : e.dateLabel);
    return DashRow(
      onTap: () => context.push('/settings/songs/${e.songId}'),
      leading: DashTile(
        tone: DashTone.purple,
        main: number,
        smallMain: number.length > 3,
      ),
      title: e.name,
      subtitle: subtitle,
      trailing: date != null ? DashMeta(DashboardUtils.relativeDays(date)) : null,
    );
  }
}

/// "Aktueller Ablaufplan" — plan of the next Termin with live progress.
class CurrentPlanCard extends ConsumerStatefulWidget {
  const CurrentPlanCard({super.key});

  @override
  ConsumerState<CurrentPlanCard> createState() => _CurrentPlanCardState();
}

class _CurrentPlanCardState extends ConsumerState<CurrentPlanCard> {
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _ensureTicker(bool isToday) {
    if (isToday && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!isToday && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dashboardCurrentPlanProvider);
    return async.when(
      loading: () => DashboardCard(
        icon: Icons.list_alt,
        title: context.l10n.homeDashboardCurrentPlan,
        subtitle: '',
        strip: DashStrips.plan,
        child: DashLoading(),
      ),
      // Ionic renders nothing when there is no plan.
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) {
          _ensureTicker(false);
          return const SizedBox.shrink();
        }
        final now = DateTime.now();
        final isToday = DashboardUtils.isSameDay(data.planDay, now);
        _ensureTicker(isToday);
        return _buildPlan(context, data, isToday, now);
      },
    );
  }

  /// INTEGRATION: opens the plan viewer like Ionic (PlanViewerComponent
  /// modal), falling back to the Termin when the plan cannot be parsed.
  void _openPlan(BuildContext context, CurrentPlanData data, String typeName) {
    final att = data.event.attendance;
    PlanAttendance? planAtt;
    try {
      planAtt = PlanAttendance.fromJson({
        ...att.toJson(),
        'extra_plans': data.event.extraPlans,
      });
    } catch (_) {
      planAtt = null;
    }
    if (planAtt != null) {
      showPlanViewer(context, attendance: planAtt, title: typeName);
    } else if (att.id != null) {
      context.push('/attendance/${att.id}');
    }
  }

  Widget _buildPlan(BuildContext context, CurrentPlanData data, bool isToday, DateTime now) {
    final att = data.event.attendance;
    final plan = data.plan;
    final fields = DashboardUtils.planFields(plan);
    final numbers = DashboardUtils.fieldNumbers(fields);
    final positionCount = fields.where((f) => !DashboardUtils.isGroupHead(f)).length;
    final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const [];
    final type = types.where((t) => t.id == att.typeId).firstOrNull;
    final typeName = type?.name ?? att.typeInfo ?? att.type ?? '';

    // Start times of all fields.
    final start = DashboardUtils.planStart(plan['time']?.toString(), data.planDay);
    final startTimes = <String>[];
    if (start != null) {
      var current = start;
      for (final f in fields) {
        startTimes.add(DashboardUtils.hhmm(current));
        current = current.add(Duration(minutes: DashboardUtils.fieldMinutes(f)));
      }
    }

    // Live state.
    var isLive = false;
    if (isToday) {
      final s = DashboardUtils.planStart(
        data.multiPlan ? plan['time']?.toString() : (att.startTime ?? plan['time']?.toString()),
        data.planDay,
      );
      final e = DashboardUtils.planStart(
        data.multiPlan ? plan['end']?.toString() : (att.endTime ?? plan['end']?.toString()),
        data.planDay,
      );
      if (s != null && e != null) {
        final sd = DateTime(data.planDay.year, data.planDay.month, data.planDay.day, s.hour, s.minute);
        final ed = DateTime(data.planDay.year, data.planDay.month, data.planDay.day, e.hour, e.minute);
        isLive = now.isAfter(sd) && now.isBefore(ed);
      }
    }

    var activeIndex = -1;
    String countdown = '';
    if (isLive && start != null) {
      var current = start;
      for (var i = 0; i < fields.length; i++) {
        if (DashboardUtils.isGroupHead(fields[i])) continue;
        current = current.add(Duration(minutes: DashboardUtils.fieldMinutes(fields[i])));
        if (now.isBefore(current)) {
          activeIndex = i;
          final remaining = current.difference(now).inSeconds.clamp(0, 1 << 31);
          final h = remaining ~/ 3600;
          final m = (remaining % 3600) ~/ 60;
          final sec = remaining % 60;
          String two(int v) => v.toString().padLeft(2, '0');
          countdown = h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
          break;
        }
      }
    }

    final dateLabel = isToday ? context.l10n.teamOrgTodayCap : DashboardUtils.longDate(data.planDay);
    final planTimes = context.l10n.homeDashboardPlanTimes(
      DashboardUtils.formatTime(plan['time']?.toString()),
      DashboardUtils.formatTime(plan['end']?.toString()),
      positionCount,
    );

    return DashboardCard(
      icon: Icons.list_alt,
      title: context.l10n.homeDashboardCurrentPlan,
      subtitle: typeName,
      strip: DashStrips.plan,
      onTap: () => _openPlan(context, data, typeName),
      trailing: isLive
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                context.l10n.homeDashboardLive,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      child: Column(
        children: [
          DashRow(
            leading: DashTile.date(data.planDay, tone: DashTone.teal, solid: isToday),
            title: dateLabel,
            subtitle: planTimes,
            trailing: const Icon(Icons.chevron_right, color: AppColors.medium),
          ),
          for (var i = 0; i < fields.length; i++)
            _fieldRow(
              context,
              fields[i],
              numbers[i],
              past: isLive && i < activeIndex,
              active: isLive && i == activeIndex,
              countdown: countdown,
              startTime: i < startTimes.length ? startTimes[i] : '',
              isLast: i == fields.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _fieldRow(
    BuildContext context,
    Map<String, dynamic> field,
    String number, {
    required bool past,
    required bool active,
    required String countdown,
    required String startTime,
    required bool isLast,
  }) {
    final isHead = DashboardUtils.isGroupHead(field);
    final isChild = field['groupId'] != null && '${field['groupId']}'.isNotEmpty;
    final conductor = field['conductor']?.toString() ?? '';
    return Container(
      color: active ? DashTone.teal.bg(context) : null,
      padding: EdgeInsets.fromLTRB(isChild ? 34 : 16, 8, 12, 8),
      decoration: null,
      child: Opacity(
        opacity: past ? 0.5 : 1,
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                number,
                style: const TextStyle(fontSize: 13, color: AppColors.medium),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: field['name']?.toString() ?? '',
                    style: TextStyle(
                      fontWeight: isHead || active ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                  if (conductor.isNotEmpty)
                    TextSpan(
                      text: ' · $conductor',
                      style: const TextStyle(color: AppColors.medium),
                    ),
                ]),
                style: const TextStyle(fontSize: 14.5),
              ),
            ),
            if (active)
              DashChip(label: countdown, tone: DashTone.teal, solid: true)
            else
              DashMeta(startTime),
          ],
        ),
      ),
    );
  }
}
