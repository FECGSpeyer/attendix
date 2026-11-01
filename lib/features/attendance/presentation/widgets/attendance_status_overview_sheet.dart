import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/layout/ion_modal_handle.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart';
import '../../../../shared/widgets/display/ion_badge_text.dart';

/// PARITY_R3: Ionic `StatusInfoComponent` (⋮ → Status-Übersicht), a sheet
/// modal with breakpoints [0, 0.5, 0.75] (initial 0.5).
void showStatusOverviewSheet(
  BuildContext context, {
  required Map<AttendanceStatus, int> statusCounts,
  required int total,
}) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatusOverviewSheet(
      statusCounts: statusCounts,
      total: total,
    ),
  );
}

/// PARITY_R5: counts of the Ionic `StatusInfoComponent`: every person row
/// of the Termin (`players` = all person_attendances, only narrowed to the
/// helper's group – never by the search or the status filter); a person
/// without a known status counts as Neutral.
({Map<AttendanceStatus, int> counts, int total}) statusOverviewCounts(
  Iterable<int> personIds,
  Map<int, AttendanceStatus> statuses,
) {
  final counts = {for (final s in AttendanceStatus.values) s: 0};
  var total = 0;
  for (final id in personIds) {
    final s = statuses[id] ?? AttendanceStatus.neutral;
    counts[s] = counts[s]! + 1;
    total++;
  }
  return (counts: counts, total: total);
}

/// Statuses of the Ionic status overview, in Ionic order
/// (`getAvailableStatuses`).
const _overviewOrder = [
  AttendanceStatus.present,
  AttendanceStatus.excused,
  AttendanceStatus.late,
  AttendanceStatus.lateExcused,
  AttendanceStatus.absent,
  AttendanceStatus.neutral,
];

/// PARITY_R3: identical to the Ionic `StatusInfoComponent`:
/// toolbar "Status-Übersicht" with an end ✕, `ion-content color="light"
/// class="ion-padding"` and an inset list – list header
/// "Gesamt: N Personen", then one row per status with a count > 0
/// (`ion-badge` slot start, min-width 32, + label). Without people one
/// centred grey row "Keine Personen vorhanden".
class StatusOverviewSheet extends StatelessWidget {
  final Map<AttendanceStatus, int> statusCounts;
  final int total;

  const StatusOverviewSheet({
    super.key,
    required this.statusCounts,
    required this.total,
  });

  static String _label(BuildContext context, AttendanceStatus status) {
    final l10n = context.l10n;
    return switch (status) {
      AttendanceStatus.present => l10n.commonStatusPresent,
      AttendanceStatus.excused => l10n.commonStatusExcused,
      AttendanceStatus.late => l10n.commonStatusLateShort,
      AttendanceStatus.lateExcused => l10n.attendanceLateExcusedParen,
      AttendanceStatus.absent => l10n.commonStatusAbsent,
      AttendanceStatus.neutral => l10n.commonStatusNeutral,
    };
  }

  /// Ionic `getStatusColor`.
  static Color _color(AttendanceStatus status) => switch (status) {
        AttendanceStatus.present => AppColors.success,
        AttendanceStatus.excused => AppColors.warning,
        AttendanceStatus.late => AppColors.tertiary,
        AttendanceStatus.lateExcused => AppColors.rosa,
        AttendanceStatus.absent => AppColors.danger,
        AttendanceStatus.neutral => AppColors.statusNeutral,
      };

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    final theme = Theme.of(context);
    final rows = <Widget>[
      for (final status in _overviewOrder)
        if ((statusCounts[status] ?? 0) > 0)
          IonItem(
            leading: StatusCountBadge(
              count: statusCounts[status]!,
              color: _color(status),
            ),
            title: Text(_label(context, status)),
          ),
    ];
    if (rows.isEmpty) {
      rows.add(IonItem(
        title: SizedBox(
          width: double.infinity,
          child: Text(
            context.l10n.attendanceNoPeople,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.medium),
          ),
        ),
      ));
    }

    // ion-content color="light": iOS grouped background, md `light`
    // (#f4f5f8, dark palette #222428).
    final background = ios
        ? theme.scaffoldBackgroundColor
        : AppColors.adaptive(context, AppColors.light);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.75,
      snap: true,
      snapSizes: const [0.5],
      expand: false,
      builder: (context, scrollController) {
        final sheet = Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: ios
                ? const BorderRadius.vertical(
                    top: Radius.circular(kIonModalSheetRadius))
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ios)
                IonModalHeader(
                  title: Text(context.l10n.attendanceStatusOverview),
                )
              else
                IonSheetHeader(
                  title: context.l10n.attendanceStatusOverview,
                  end: const [IonCloseButton()],
                ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  // ion-padding around the inset list.
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    IonListHeader(context.l10n.attendanceTotalPeople(total)),
                    IonInsetList(
                      // Ionic inset item lines start at the label.
                      dividerIndent: 64,
                      children: rows,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        return ios ? IonModalHandleOverlay(child: sheet) : sheet;
      },
    );
  }
}

/// Ionic `ion-badge` with a count (status-info `min-width: 32px`, centred):
/// iOS padding 3/8, radius 10; md padding 3/4/4/4, radius 4; 13px bold in
/// the colour's contrast.
class StatusCountBadge extends StatelessWidget {
  const StatusCountBadge({super.key, required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.adaptive(context, color);
    // Ionic palettes: black text on warning; the dark palette also uses
    // black on success and medium.
    final blackText = color == AppColors.warning ||
        (dark &&
            (color == AppColors.success || color == AppColors.statusNeutral));
    return Container(
      constraints: const BoxConstraints(minWidth: 32),
      padding: ios
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : const EdgeInsets.fromLTRB(4, 3, 4, 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ios ? 10 : 4),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        // PARITY_R8: real bold (700) also on the web
        style: ionBadgeTextStyle(
            color: blackText ? Colors.black : Colors.white),
      ),
    );
  }
}
