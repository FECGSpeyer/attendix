import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duty_utils.dart';
import 'duty_actions.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/ion_button_label.dart';

/// "Deine Dienste: bitte bestätigen" on the attendance list: own upcoming
/// assignments that still wait for confirmation (leaders confirm their own
/// duties here, they have no "Meine Termine" page). Cancelled duties are hidden.
class MyDutyRequestsSection extends ConsumerWidget {
  const MyDutyRequestsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myDutyOverviewProvider).valueOrNull?.requests ?? const [];
    if (requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.paddingS, top: AppDimensions.paddingXS),
          child: Text(
            context.l10n.dutyMyRequestsTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        for (final r in requests)
          Card(
            margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingS),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => context.push('/attendance/${r.termin.attendance.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.termin.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(_dateLabel(r.termin), style: const TextStyle(color: AppColors.medium, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => declineDutyAction(context, ref, r.pa.id!, r.termin.attendance.id!),
                    child: IonButtonLabel(context.l10n.signoutCannot),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                    onPressed: () => confirmDutyAction(context, ref, r.pa.id!, r.termin.attendance.id!),
                    child: IonButtonLabel(context.l10n.commonConfirm),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _dateLabel(DutyTermin t) {
    final d = DateTime.tryParse(t.attendance.date)?.toLocal();
    if (d == null) return t.attendance.date;
    final time = t.attendance.startTime ?? t.type.startTime;
    final timeText = time != null && time.length >= 5 ? ' · ${time.substring(0, 5)}' : '';
    return '${weekdayShortNames[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.$timeText';
  }
}
