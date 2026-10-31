import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/router/redesign_routes.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../data/repositories/sign_in_out_repository.dart' show CrossTenantPersonAttendance;
import '../../../../../l10n/l10n.dart';
import '../../../data/providers/rd_today_providers.dart' show rdSignoutDataProvider;
import '../../pages/rd_own_event_page.dart' show rdFindOwnEvent;
import '../rd_widgets.dart';
import '../today/rd_player_today.dart' show RdOwnAnswerSection;
import '../today/rd_today_common.dart' show RdInfoCard, RdLinkButton;

/// Own answer for one Termin as a sheet: Helfer answer for themselves from
/// the leader list of "Termine" (UX H1) without leaving it. Same answer
/// card, reasons and writes as on "Heute".
Future<void> showRdOwnAnswerSheet(BuildContext context, String personAttendanceId) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (_) => _OwnAnswerSheet(personAttendanceId: personAttendanceId),
  );
}

class _OwnAnswerSheet extends ConsumerWidget {
  const _OwnAnswerSheet({required this.personAttendanceId});

  final String personAttendanceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    // Looked up on every build so the card follows the answer just given.
    final data = ref.watch(rdSignoutDataProvider).valueOrNull;
    final att = data == null ? null : rdFindOwnEvent(data, personAttendanceId);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child:
            att == null
                ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
                : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RdEyebrow(l10n.redesignTodayYourAnswer),
                    const SizedBox(height: 6),
                    Semantics(header: true, child: Text(att.eventTitle, style: RdType.cardTitle(p))),
                    if (att.eventMeta(withDate: true).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(att.eventMeta(withDate: true), style: RdType.meta(p, size: 15)),
                    ],
                    const SizedBox(height: 14),
                    RdOwnAnswerSection(
                      key: ValueKey('rd-own-sheet-${att.id}'),
                      attendance: att,
                      showHeader: false,
                      showEvent: false,
                    ),
                    if (att.id != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RdLinkButton(
                          label: l10n.redesignTodayMore,
                          onPressed: () {
                            final router = GoRouter.of(context);
                            Navigator.of(context).pop();
                            router.push(RedesignRoutes.ownEvent(att.id!));
                          },
                        ),
                      ),
                  ],
                ),
      ),
    );
  }
}

/// Small "Du ✓" chip with the own answer in a leader row (UX H2). Tapping
/// it opens [showRdOwnAnswerSheet]; the row itself keeps opening the
/// recording.
class RdOwnStatusChip extends StatelessWidget {
  const RdOwnStatusChip({super.key, required this.attendance, required this.onTap});

  final CrossTenantPersonAttendance attendance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final (RdTone? tone, IconData icon, String status) = switch (attendance.status) {
      AttendanceStatus.present => (RdTone.present, Icons.check, l10n.redesignStatusYes),
      AttendanceStatus.late => (RdTone.late, Icons.schedule, l10n.redesignStatusLate),
      AttendanceStatus.lateExcused => (RdTone.late, Icons.schedule, l10n.redesignStatusLater),
      AttendanceStatus.excused => (RdTone.excused, Icons.close, l10n.redesignStatusExcused),
      AttendanceStatus.absent => (RdTone.absent, Icons.close, l10n.redesignStatusAbsent),
      AttendanceStatus.neutral => (null, Icons.help_outline, l10n.redesignStatusOpen),
    };
    final fg = tone == null ? p.text2 : p.toneColor(tone);
    final bg = tone == null ? p.track : p.toneSoft(tone);

    return Semantics(
      button: true,
      label: l10n.redesignEventsYourAnswerLabel(status),
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.redesignEventsYou, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
                  const SizedBox(width: 4),
                  Icon(icon, size: 16, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
