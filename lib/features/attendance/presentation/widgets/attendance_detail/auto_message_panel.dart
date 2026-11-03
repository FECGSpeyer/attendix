import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/auto_message_providers.dart';
import '../../../../../core/providers/debug_providers.dart';
import '../../../../../core/providers/profile_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/models/auto_message/auto_message.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../messages/presentation/auto_message_texts.dart';
import '../../../../messages/presentation/pages/message_compose_page.dart';
import '../../../../settings/presentation/widgets/settings_list.dart';

/// One person of the Termin as the panel needs it.
class AutoMessagePanelPerson {
  const AutoMessagePanelPerson({
    required this.personId,
    required this.personAttendanceId,
    required this.name,
    required this.status,
    this.left = false,
  });

  final int personId;
  final String? personAttendanceId;
  final String name;
  final AttendanceStatus status;
  final bool left;
}

/// Ionic panel `startOf`: start of the Termin (type start time as fallback,
/// all-day Termine start at midnight).
DateTime autoMessageTerminStart(Attendance att, AttendanceType? type) {
  final parsed = DateTime.tryParse(att.date)?.toLocal() ?? DateTime.now();
  final day = DateTime(parsed.year, parsed.month, parsed.day);
  final time = (att.startTime?.isNotEmpty ?? false) ? att.startTime : type?.startTime;
  if (time == null || time.isEmpty || (type?.allDay ?? false)) return day;
  final parts = time.split(':').map((p) => int.tryParse(p) ?? 0).toList();
  return DateTime(day.year, day.month, day.day, parts[0], parts.length > 1 ? parts[1] : 0);
}

/// Ionic panel `endOf`: end of the Termin (multi-day, type end time,
/// 2 hours after the start without an end time).
DateTime autoMessageTerminEnd(Attendance att, AttendanceType? type) {
  final start = autoMessageTerminStart(att, type);
  final days = (att.durationDays ?? 1) < 1 ? 1 : (att.durationDays ?? 1);
  final endTime = (att.endTime?.isNotEmpty ?? false) ? att.endTime : type?.endTime;
  final noStart = !(att.startTime?.isNotEmpty ?? false) && !(type?.startTime?.isNotEmpty ?? false);
  if ((type?.allDay ?? false) || (noStart && (endTime == null || endTime.isEmpty))) {
    return DateTime(start.year, start.month, start.day + days);
  }
  if (endTime == null || endTime.isEmpty) return start.add(const Duration(hours: 2));
  final parts = endTime.split(':').map((p) => int.tryParse(p) ?? 0).toList();
  final end = DateTime(
    start.year,
    start.month,
    start.day + days - 1,
    parts[0],
    parts.length > 1 ? parts[1] : 0,
  );
  return end.isAfter(start) ? end : end.add(const Duration(days: 1));
}

/// Unexcused people of a Termin (status absent, not left).
List<AutoMessagePanelPerson> unexcusedPeople(List<AutoMessagePanelPerson> people) =>
    people.where((p) => p.status == AttendanceStatus.absent && !p.left).toList();

/// Ionic "Unentschuldigte anschreiben": the compose dialog with the
/// unexcused people as fixed recipients and a prefilled text, linked to the
/// Termin so they can answer.
Future<void> openWriteUnexcused(
  BuildContext context,
  WidgetRef ref, {
  required Attendance attendance,
  required String typeName,
  required List<AutoMessagePanelPerson> people,
}) async {
  final unexcused = unexcusedPeople(people);
  if (unexcused.isEmpty || attendance.id == null) return;
  final l10n = context.l10n;
  final tenant = ref.read(currentTenantProvider);
  final termin = (attendance.typeInfo?.isNotEmpty ?? false) ? attendance.typeInfo! : typeName;
  final datum = formatTerminDate(attendance.date);
  final instanz =
      (tenant?.longName.isNotEmpty ?? false) ? tenant!.longName : (tenant?.shortName ?? '');
  await openMessageCompose(
    context,
    preset: MessageComposePreset(
      playerIds: unexcused.map((p) => p.personId).toList(),
      attendanceId: attendance.id,
      allowResponses: true,
      recipientsLabel: l10n.autoMessagesManualRecipients(unexcused.length),
      title: l10n.autoMessagesManualTitle,
      content: textToDoc(l10n.autoMessagesManualBody(termin, datum, instanz)),
    ),
  );
}

typedef _PanelData =
    ({List<AutoMessageRule> rules, List<AutoMessageRun> runs, List<AttendanceResponse> responses});

final _autoMessagePanelProvider = FutureProvider.autoDispose.family<_PanelData, int>((
  ref,
  attendanceId,
) async {
  final repo = ref.watch(autoMessageRepositoryWithTenantProvider);
  if (!repo.hasTenantId)
    return (
      rules: <AutoMessageRule>[],
      runs: <AutoMessageRun>[],
      responses: <AttendanceResponse>[],
    );
  final results = await Future.wait([
    repo.getRules(),
    repo.getRunsForAttendance(attendanceId),
    repo.getResponsesForAttendance(attendanceId),
  ]);
  return (
    rules: results[0] as List<AutoMessageRule>,
    runs: results[1] as List<AutoMessageRun>,
    responses: results[2] as List<AttendanceResponse>,
  );
});

/// On a Termin (admins/responsibles, Ionic 4.18 `app-auto-message-panel`):
/// what the automatic messages do for it ("geht um 23:30 raus" / "ging an
/// 4 Personen", Diesmal aussetzen) and the members' answers to confirm or
/// reject. Shown once the Termin has started.
class AutoMessagePanel extends ConsumerStatefulWidget {
  const AutoMessagePanel({
    super.key,
    required this.attendance,
    required this.attendanceType,
    required this.people,
  });

  final Attendance attendance;
  final AttendanceType? attendanceType;
  final List<AutoMessagePanelPerson> people;

  @override
  ConsumerState<AutoMessagePanel> createState() => _AutoMessagePanelState();
}

class _AutoMessagePanelState extends ConsumerState<AutoMessagePanel> {
  final Set<String> _busy = {};

  /// Locally decided answers (id → state) until the next reload.
  final Map<String, String> _decided = {};

  int get _id => widget.attendance.id!;

  String _nameOf(AttendanceResponse r) =>
      widget.people.where((p) => p.personAttendanceId == r.personAttendanceId).firstOrNull?.name ??
      '';

  Future<void> _suspend(AutoMessageRule rule) async {
    final profile = ref.read(ownProfileProvider).valueOrNull?.person;
    final name =
        profile != null
            ? '${profile.firstName} ${profile.lastName}'.trim()
            : (ref.read(supabaseClientProvider).auth.currentUser?.email ?? '');
    try {
      await ref.read(autoMessageRepositoryWithTenantProvider).suspend(rule, _id, name);
      ref.invalidate(_autoMessagePanelProvider(_id));
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.autoMessagesSaveFailed);
    }
  }

  Future<void> _unsuspend(AutoMessageRun run) async {
    try {
      await ref.read(autoMessageRepositoryWithTenantProvider).unsuspend(run.id);
      ref.invalidate(_autoMessagePanelProvider(_id));
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.autoMessagesSaveFailed);
    }
  }

  void _openRun(AutoMessageRule rule, AutoMessageRun run) {
    if (run.messageId != null) {
      context.push('/messages/${run.messageId}');
    } else {
      context.push('/settings/auto-messages/${rule.id}?tab=history');
    }
  }

  Future<void> _decide(AttendanceResponse r, bool accept) async {
    final repo = ref.read(autoMessageRepositoryWithTenantProvider);
    if (_busy.contains(r.id)) return;
    final l10n = context.l10n;
    final action =
        accept
            ? (r.wasPresent ? l10n.autoMessagesSetPresent : l10n.autoMessagesExcuse)
            : l10n.autoMessagesReject;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder:
          (ctx) => AppAlertDialog(
            title: Text(_nameOf(r)),
            content: Text(
              accept
                  ? (r.wasPresent
                      ? l10n.autoMessagesDecideAcceptPresent
                      : l10n.autoMessagesDecideAcceptReason)
                  : l10n.autoMessagesDecideReject,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: accept ? null : TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(action),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy.add(r.id));
    try {
      await repo.decideResponse(r.id, accept);
      if (!mounted) return;
      setState(() => _decided[r.id] = accept ? 'accepted' : 'rejected');
      ToastHelper.showSuccess(
        context,
        accept ? l10n.autoMessagesDecidedAccepted : l10n.autoMessagesDecidedRejected,
      );
    } catch (_) {
      if (mounted) ToastHelper.showError(context, l10n.autoMessagesSaveFailed);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(effectiveRoleProvider);
    if (!(role.isAdmin || role.isResponsible) || widget.attendance.id == null) {
      return const SizedBox.shrink();
    }
    final start = autoMessageTerminStart(widget.attendance, widget.attendanceType);
    if (start.isAfter(DateTime.now())) return const SizedBox.shrink();
    final data = ref.watch(_autoMessagePanelProvider(_id)).valueOrNull;
    if (data == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final end = autoMessageTerminEnd(widget.attendance, widget.attendanceType);
    final typeId = widget.attendance.typeId;
    final states =
        [
              for (final rule in data.rules)
                if (!(rule.typeIds?.isNotEmpty ?? false) || rule.typeIds!.contains(typeId))
                  (
                    rule: rule,
                    run: data.runs.where((x) => x.ruleId == rule.id).firstOrNull,
                    sendAt: end.add(Duration(minutes: rule.delayMinutes)),
                  ),
            ]
            // Rules that are on, plus anything that already happened for this Termin.
            .where(
              (s) =>
                  (s.rule.enabled &&
                      (s.rule.enabledAt == null || !end.isBefore(s.rule.enabledAt!))) ||
                  s.run != null,
            )
            .toList();
    final responses = [
      for (final r in data.responses) _decided.containsKey(r.id) ? r.withState(_decided[r.id]!) : r,
    ];
    final pending = responses.where((r) => r.isPending).length;
    final dateTime = DateFormat('${dateFmt()}, HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in states)
          _Banner(
            icon: s.run?.status == 'sent' ? Icons.send_outlined : Icons.timer_outlined,
            title: switch (s.run?.status) {
              null when s.sendAt.isAfter(DateTime.now()) => l10n.autoMessagesPanelWillSend(
                s.rule.name,
                DateFormat('HH:mm').format(s.sendAt),
              ),
              null => l10n.autoMessagesPanelPending(s.rule.name),
              'sent' => l10n.autoMessagesPanelSent(s.rule.name, s.run!.recipientCount),
              'suspended' => l10n.autoMessagesPanelSuspended(s.rule.name),
              'not_recorded' => l10n.autoMessagesPanelNotRecorded(s.rule.name),
              _ => l10n.autoMessagesPanelNone(s.rule.name),
            },
            subtitle: switch (s.run?.status) {
              null when s.sendAt.isAfter(DateTime.now()) => l10n.autoMessagesPanelWillSendHint,
              null => l10n.autoMessagesPanelPendingHint,
              'sent' =>
                s.run!.createdAt == null ? null : dateTime.format(s.run!.createdAt!.toLocal()),
              'suspended' => l10n.autoMessagesHistRowSuspended(
                s.run!.createdByName ?? l10n.commonUnknown,
              ),
              _ => null,
            },
            action:
                s.run == null && s.sendAt.isAfter(DateTime.now())
                    ? (l10n.autoMessagesSuspend, () => _suspend(s.rule))
                    : s.run?.status == 'suspended'
                    ? (l10n.autoMessagesUnsuspend, () => _unsuspend(s.run!))
                    : s.run?.status == 'sent'
                    ? (l10n.autoMessagesWhoRead, () => _openRun(s.rule, s.run!))
                    : null,
          ),
        if (responses.isNotEmpty)
          SettingsListSection(
            title: l10n.autoMessagesPanelResponses(pending),
            children: [
              for (final r in responses)
                _ResponseRow(
                  response: r,
                  name: _nameOf(r),
                  busy: _busy.contains(r.id),
                  onDecide: (accept) => _decide(r, accept),
                ),
            ],
          ),
      ],
    );
  }
}

/// Ionic `.banner`: primary-bordered card with icon, bold text, hint and an
/// outline button.
class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.title, this.subtitle, this.action});

  final IconData icon;
  final String title;
  final String? subtitle;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ios ? IonIos.itemBackground(context) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14.4, fontWeight: FontWeight.w700, height: 1.35),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 12.8, color: AppColors.medium),
                    ),
                  ),
                if (action != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: OutlinedButton(
                      onPressed: action!.$2,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: IonButtonLabel(action!.$1),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One answer: icon per kind, name, reason, buttons side by side
/// (Ionic 06a659fc) or the decided state.
class _ResponseRow extends StatelessWidget {
  const _ResponseRow({
    required this.response,
    required this.name,
    required this.busy,
    required this.onDecide,
  });

  final AttendanceResponse response;
  final String name;
  final bool busy;
  final ValueChanged<bool> onDecide;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = response;
    final detail =
        r.wasPresent
            ? l10n.autoMessagesPanelSaysPresent
            : '${l10n.autoMessageReason(r.reasonCode)}${(r.text?.isNotEmpty ?? false) ? ': ${r.text}' : ''}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            r.wasPresent ? Icons.back_hand_outlined : Icons.chat_bubble_outline,
            color: AppColors.medium,
            size: 22,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? l10n.commonUnknown : name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(detail, style: const TextStyle(fontSize: 14, color: AppColors.medium)),
                if (r.isPending)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: busy ? null : () => onDecide(true),
                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                          child: IonButtonLabel(
                            r.wasPresent ? l10n.autoMessagesSetPresent : l10n.autoMessagesExcuse,
                          ),
                        ),
                        OutlinedButton(
                          onPressed: busy ? null : () => onDecide(false),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.medium,
                          ),
                          child: IonButtonLabel(l10n.autoMessagesReject),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${l10n.autoMessageResponseState(r.state)}${(r.decidedByName?.isNotEmpty ?? false) ? ' · ${r.decidedByName}' : ''}',
                      style: const TextStyle(fontSize: 12.8, color: AppColors.medium),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
