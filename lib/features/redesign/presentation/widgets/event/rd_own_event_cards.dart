import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/signout_providers.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/auto_message/auto_message.dart' show autoMessageResponseUntil;
import '../../../../../data/models/plan/plan.dart';
import '../../../../../data/models/song/song.dart';
import '../../../../../data/repositories/sign_in_out_repository.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../messages/presentation/auto_message_texts.dart';
import '../../../../messages/presentation/widgets/attendance_response_page.dart';
import '../../../../songs/presentation/widgets/song_file_opener.dart';
import '../../../data/providers/rd_event_details_providers.dart';
import '../../../data/rd_dates.dart';
import '../../../data/rd_event_details_logic.dart';
import '../../../data/rd_works_logic.dart' show rdFileKind;
import '../rd_widgets.dart';
import '../today/rd_today_common.dart' show RdLinkButton;
import 'rd_event_now.dart';

/// REDESIGN (concept "Termin-Bereich neu", Schritt 3): the card at the top
/// of a member's Termin: "Jetzt im Ablauf" with "Deine Noten öffnen" while
/// it runs, "Deine Anwesenheit" afterwards.

/// Label, tone and icon of the own status: before the Termin "Du bist
/// eingeplant", "Du kommst später", "Abgemeldet"; once it is over the
/// recorded status. The reason follows in quotes.
({String label, RdTone tone, IconData icon}) rdOwnStatusLook(
  AppLocalizations l10n,
  AttendanceStatus status, {
  required bool ended,
  String? note,
}) {
  final look = switch (status) {
    AttendanceStatus.present =>
      (label: ended ? l10n.commonStatusPresent : l10n.redesignOwnPlanned, tone: RdTone.present, icon: Icons.check),
    AttendanceStatus.late || AttendanceStatus.lateExcused =>
      (label: ended ? l10n.redesignStatusLate : l10n.redesignOwnComingLater, tone: RdTone.late, icon: Icons.schedule),
    AttendanceStatus.excused => (
        label: ended ? l10n.redesignStatusExcused : l10n.redesignTodayNoDone,
        tone: RdTone.excused,
        icon: Icons.event_busy_outlined,
      ),
    AttendanceStatus.absent => (label: l10n.redesignStatusAbsent, tone: RdTone.absent, icon: Icons.close),
    AttendanceStatus.neutral => (
        label: ended ? l10n.redesignOwnNotRecorded : l10n.redesignOwnNoAnswer,
        tone: RdTone.primary,
        icon: Icons.remove,
      ),
  };
  final reason = (note ?? '').trim();
  if (reason.isEmpty || status == AttendanceStatus.present || status == AttendanceStatus.neutral) return look;
  return (label: '${look.label} · „$reason“', tone: look.tone, icon: look.icon);
}

/// "✓ Du bist eingeplant" on a soft background in the status colour.
class RdStatusBox extends StatelessWidget {
  const RdStatusBox({super.key, required this.label, required this.tone, required this.icon});

  final String label;
  final RdTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final fg = p.toneColor(tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: p.toneSoft(tone), borderRadius: BorderRadius.circular(p.buttonRadius)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
          ),
        ],
      ),
    );
  }
}

/// Opens the own score of a Werk; several files (e.g. two parts) in a
/// sheet to pick from.
Future<void> rdOpenOwnNotes(BuildContext context, List<SongFile> notes) async {
  if (notes.isEmpty) return;
  if (notes.length == 1) return openSongFile(context, notes.first);
  final file = await showModalBottomSheet<SongFile>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: RdGroupedList(children: [
          for (final f in notes)
            RdListRow(
              leading: const RdRowIcon(Icons.description_outlined),
              title: f.fileName,
              subtitle: rdFileKind(f),
              onTap: () => Navigator.of(ctx).pop(f),
            ),
        ]),
      ),
    ),
  );
  if (file != null && context.mounted) await openSongFile(context, file);
}

/// Läuft (concept S2): "Jetzt im Ablauf · bis 17:20", the current row,
/// "Deine Noten öffnen" when it is a Werk with own scores, what follows,
/// and the own status ("Du bist dabei").
class RdOwnNowCard extends ConsumerWidget {
  const RdOwnNowCard({super.key, required this.attendance, required this.plan, this.onLate, this.now});

  final CrossTenantPersonAttendance attendance;
  final Plan plan;

  /// "Ich komme später …" while that is still possible.
  final VoidCallback? onLate;

  /// For tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final att = attendance;
    final program = att.attendanceId == null
        ? null
        : ref
            .watch(rdOwnProgramProvider(
                (tenantId: att.tenantId, attendanceId: att.attendanceId!, personId: att.personId)))
            .valueOrNull;
    final status = att.status == AttendanceStatus.present
        ? (label: l10n.redesignOwnIn, tone: RdTone.present, icon: Icons.check)
        : rdOwnStatusLook(l10n, att.status, ended: false, note: att.notes);
    final color = p.toneColor(status.tone);

    Widget? notesButton(RdPlanSlot slot) {
      final songId = slot.field.songId;
      if (program == null || songId == null) return null;
      final item = program.items.where((i) => i.song?.id == songId).firstOrNull;
      if (item == null) return null;
      final notes = rdMyNotes(item.song, program.instrumentId, isChoir: program.isChoir);
      if (notes.isEmpty) return null;
      return RdPrimaryButton(
        key: const Key('rd-own-now-notes'),
        label: l10n.redesignOwnOpenMine,
        icon: Icons.description_outlined,
        onPressed: () => rdOpenOwnNotes(context, notes),
      );
    }

    return RdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RdPlanNow(day: EventListUtils.parse(att.date), plan: plan, action: notesButton, now: now),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(status.icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status.label,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
          if (onLate != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: RdLinkButton(label: l10n.redesignTodayLater, onPressed: onLate!),
            ),
        ],
      ),
    );
  }
}

/// Danach (concept S3): "Deine Anwesenheit" with the recorded status. When
/// the Leitung asked for a reason by message, "Grund nachtragen" and "Ich
/// war doch da" right here (the same answers as in the message, 7 days).
class RdOwnAttendanceCard extends ConsumerWidget {
  const RdOwnAttendanceCard({super.key, required this.attendance, this.now});

  final CrossTenantPersonAttendance attendance;

  /// For tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final att = attendance;
    final look = rdOwnStatusLook(l10n, att.status, ended: true, note: att.notes);
    final key = att.id == null ? null : (tenantId: att.tenantId, personAttendanceId: att.id!);
    final info = key == null ? null : ref.watch(rdOwnResponseInfoProvider(key)).valueOrNull;
    final own = info?.own;
    final current = now ?? DateTime.now();
    // Same window as in the message (MessageTerminSection).
    final until = autoMessageResponseUntil(att.date);
    final open = until != null && !current.isAfter(until);
    final daysLeft = until == null ? 0 : rdDaysBetween(current, until);
    final canAnswer = info != null && open && (own == null || own.isPending);
    final showAnswer = info != null && (att.status == AttendanceStatus.absent || own != null);

    Future<void> respond(String kind) async {
      final termin = [att.eventTitle, att.readableDate].where((s) => s.isNotEmpty).join(' · ');
      final state = await openAttendanceResponse(context, messageId: info!.messageId, termin: termin, kind: kind);
      if (state == null || !context.mounted) return;
      ToastHelper.showSuccess(
        context,
        state == 'accepted' ? l10n.autoMessagesRespDoneInstant : l10n.autoMessagesRespDone,
      );
      ref.invalidate(rdOwnResponseInfoProvider(key!));
      ref.invalidate(signoutDataProvider);
    }

    return RdCard(
      key: const Key('rd-own-attendance'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.redesignOwnYourAttendance, style: RdType.cardTitle(p)),
          const SizedBox(height: 12),
          RdStatusBox(label: look.label, tone: look.tone, icon: look.icon),
          if (showAnswer) ...[
            const SizedBox(height: 10),
            Text(
              own != null
                  ? [
                      l10n.autoMessageResponseState(own.state),
                      if (own.reasonCode != null) l10n.autoMessageReason(own.reasonCode),
                      if (own.wasPresent) l10n.autoMessagesRespWasThere,
                    ].join(' · ')
                  : [
                      l10n.redesignOwnAskReason,
                      if (canAnswer) l10n.redesignOwnAnswerDays(daysLeft),
                    ].join(' '),
              style: RdType.body(p).copyWith(fontSize: 14),
            ),
            if (canAnswer) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: RdPrimaryButton(
                  key: const Key('rd-own-respond-reason'),
                  label: own != null ? l10n.autoMessagesRespChange : l10n.autoMessagesRespAddReason,
                  onPressed: () => respond('reason'),
                ),
              ),
              if (own == null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: RdOutlineButton(
                    key: const Key('rd-own-respond-present'),
                    label: l10n.autoMessagesRespWasThere,
                    onPressed: () => respond('was_present'),
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
