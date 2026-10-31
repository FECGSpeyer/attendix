import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/providers/self_service_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../l10n/l10n.dart';
import '../../rd_actions.dart';
import '../join/rd_join_sheet.dart';
import '../rd_widgets.dart';

/// REDESIGN: "Heute" of Bewerber (canvas R4): the application is being
/// checked; no tabs besides "Ich".
class RdApplicantToday extends ConsumerWidget {
  const RdApplicantToday({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    final player = ref.watch(currentSelfServicePlayerProvider).valueOrNull;
    final group = tenant?.longName.isNotEmpty == true ? tenant!.longName : (tenant?.shortName ?? '');

    return RdPage(
      onRefresh: () async {
        ref.invalidate(currentTenantUserProvider);
        ref.invalidate(currentSelfServicePlayerProvider);
      },
      children: [
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(l10n.redesignApplicantTitle, style: RdType.largeTitle(p)),
        ),
        const SizedBox(height: 18),
        RdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: p.soft, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(Icons.hourglass_top_rounded, color: p.softText),
              ),
              const SizedBox(height: 14),
              if (player != null && player.firstName.isNotEmpty)
                Text(
                  l10n.redesignTodayGreeting(player.firstName),
                  style: RdType.meta(p, size: 15),
                ),
              const SizedBox(height: 4),
              Text(
                group.isEmpty ? l10n.redesignApplicantWaiting : l10n.redesignApplicantWaitingFor(group),
                style: RdType.cardTitle(p),
              ),
              const SizedBox(height: 14),
              // UX B2: what happens next.
              _Step(
                done: true,
                text: player?.createdAt == null
                    ? l10n.redesignJoinStepReceivedNoDate
                    : l10n.redesignJoinStepReceived(DateFormat('d.M.').format(player!.createdAt!.toLocal())),
              ),
              _Step(number: 2, text: l10n.redesignJoinStepCheck),
              _Step(number: 3, text: l10n.redesignJoinStepNotify),
            ],
          ),
        ),
        const SizedBox(height: 24),
        RdOutlineButton(
          label: l10n.redesignApplicantOtherGroup,
          icon: Icons.group_add_outlined,
          // UX B1: join with the invitation link, not "Neue Instanz".
          onPressed: () => showRdJoinSheet(context),
        ),
        const SizedBox(height: 10),
        RdOutlineButton(
          label: l10n.redesignMeLogout,
          icon: Icons.logout,
          color: p.absent,
          onPressed: () => rdLogout(context, ref),
        ),
      ],
    );
  }
}

/// One step of "how it goes on" (done = check mark).
class _Step extends StatelessWidget {
  const _Step({required this.text, this.number, this.done = false});

  final String text;
  final int? number;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: done ? p.presentSoft : p.track, shape: BoxShape.circle),
            child: done
                ? Icon(Icons.check, size: 16, color: p.present)
                : Text('$number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.text2)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: RdType.body(p))),
        ],
      ),
    );
  }
}
