import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/duty_providers.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../duty/presentation/widgets/duty_actions.dart';
import '../../../../duty/presentation/widgets/self_service_duty_section.dart'
    show openDutiesTileSubtitle, showOpenDutiesSheet;
import '../rd_widgets.dart';
import 'rd_today_common.dart';

/// REDESIGN: the Dienstplan part of "Meine Termine"
/// ([SelfServiceDutySection]) for persons in a duty circle: own duties to
/// confirm ("Bitte bestätigen") and "Offene Dienste". Duty Termine without
/// an own assignment are not answered in the lists
/// (`rdSignoutDataProvider`); they are taken over here through the
/// existing sheet (`duty_take` with its checks), confirmed and declined
/// through the existing duty actions.
class RdDutySection extends ConsumerWidget {
  const RdDutySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.rd;
    final overview = ref.watch(myDutyOverviewProvider).valueOrNull;
    if (overview == null || overview.person == null) return const SizedBox.shrink();
    if (!overview.inDutyCircle && overview.requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (overview.requests.isNotEmpty) ...[
          const SizedBox(height: 24),
          RdSectionHeader(l10n.signoutPleaseConfirm),
          for (final r in overview.requests)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RdCard(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RdEventRow(
                      date: r.termin.attendance.date,
                      title: r.termin.title,
                      meta: l10n.signoutYouAreAssigned,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: RdPrimaryButton(
                              label: l10n.commonConfirm,
                              color: p.present,
                              onPressed: () => confirmDutyAction(context, ref, r.pa.id!, r.termin.attendance.id!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RdOutlineButton(
                              label: l10n.signoutCannot,
                              onPressed: () => selfServiceDeclineDutyAction(context, ref, r.pa.id!, r.termin),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (overview.inDutyCircle) ...[
          const SizedBox(height: 24),
          RdGroupedList(
            children: [
              RdListRow(
                leading: RdRowIcon(Icons.headset_mic_outlined),
                title: l10n.signoutOpenDuties,
                subtitle: openDutiesTileSubtitle(overview.openDuties.length),
                onTap: () => showOpenDutiesSheet(context),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
