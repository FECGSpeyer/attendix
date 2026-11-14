import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/duty_utils.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../data/repositories/duty_repository.dart' show DutyTermin;
import '../pages/unavailability_page.dart';
import 'duty_actions.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/ion_button.dart';
import '../../../../shared/widgets/adaptive/ion_button_label.dart';
import '../../../planning/presentation/widgets/rd_plan_widgets.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../redesign/presentation/widgets/today/rd_today_common.dart';

/// Dienstplan part of "Meine Termine" (self service): "Bitte bestätigen",
/// and – when the tenant uses the Dienstplan view – "Nächster Dienst",
/// "Offene Dienste", "Meine Dienste" and "Regelmäßig verhindert".
///
/// Outside the Dienstplan view a compact "Offene Dienste" tile is shown for
/// persons in a duty circle.
/// UX_SELF: which part of the Dienstplan block is rendered. Ionic places the
/// stats below the greeting, "Bitte bestätigen" before "Meine Aufgaben" and
/// the Dienstplan lists after the planned absences.
enum SelfServiceDutyPart { all, stats, requests, dutyView }

class SelfServiceDutySection extends ConsumerWidget {
  const SelfServiceDutySection({
    super.key,
    this.part = SelfServiceDutyPart.all,
    this.showOtherTermine = false,
    this.otherTermineCount = 0,
    this.otherTermineNames = '',
    this.onToggleOtherTermine,
    this.onReportAbsence,
    this.onOpenDuty,
    this.chipsFor,
  });

  /// P10_SELF_PLAN: tap on a row of "Meine Dienste" (Ionic
  /// presentActionSheetForChoice of that Termin).
  final void Function(int attendanceId)? onOpenDuty;

  /// P10_SELF_PLAN: chips (Ablaufplan, Infos, Anhang, Dateien, Route) of
  /// the "Nächster Dienst" card.
  final List<Widget> Function(int attendanceId)? chipsFor;

  final SelfServiceDutyPart part;
  final bool showOtherTermine;
  final int otherTermineCount;
  final String otherTermineNames;
  final VoidCallback? onToggleOtherTermine;

  /// UX_SELF: "Abwesenheit melden" entry of the Dienstplan view (only when
  /// planned absences are allowed).
  final VoidCallback? onReportAbsence;

  bool _shows(SelfServiceDutyPart p) => part == SelfServiceDutyPart.all || part == p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(myDutyOverviewProvider).valueOrNull;
    if (overview == null || overview.person == null) return const SizedBox.shrink();
    if (!overview.inDutyCircle && overview.requests.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];

    if (_shows(SelfServiceDutyPart.stats)) {
      if (overview.useDutyView) {
        children.add(_DutyStats(overview: overview));
      } else if (overview.inDutyCircle && part == SelfServiceDutyPart.all) {
        // UX_SELF: on "Meine Termine" this is a greet tile next to "Aktuelle Werke".
        children.add(Card(
          margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
          child: ListTile(
            leading: Icon(AppIcons.headsetMicOutlined, color: AppColors.primary),
            title: Text(context.l10n.signoutOpenDuties),
            subtitle: Text(openDutiesTileSubtitle(overview.openDuties.length)),
            trailing: Icon(AppIcons.chevronRight),
            onTap: () => showOpenDutiesSheet(context),
          ),
        ));
      }
    }

    // "Bitte bestätigen"
    if (_shows(SelfServiceDutyPart.requests) && overview.requests.isNotEmpty) {
      children.add(_DutyAnchor(
        id: 'duty-requests',
        child: _SectionTitle(title: context.l10n.signoutPleaseConfirm, count: overview.requests.length),
      ));
      for (final r in overview.requests) {
        children.add(Card(
          margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.termin.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 2),
                Text(dutyEventMetaLine(r.termin), style: const TextStyle(color: AppColors.medium)),
                const SizedBox(height: 6),
                DutyPill(text: context.l10n.signoutYouAreAssigned, color: AppColors.warningDark),
                const SizedBox(height: AppDimensions.paddingS),
                Row(
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                      onPressed: () => confirmDutyAction(context, ref, r.pa.id!, r.termin.attendance.id!),
                      child: IonButtonLabel(context.l10n.commonConfirm),
                    ),
                    const SizedBox(width: AppDimensions.paddingS),
                    OutlinedButton(
                      onPressed: () => selfServiceDeclineDutyAction(context, ref, r.pa.id!, r.termin),
                      child: IonButtonLabel(context.l10n.signoutCannot),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));
      }
    }

    if (_shows(SelfServiceDutyPart.dutyView) && overview.useDutyView) {
      // "Nächster Dienst"
      final next = overview.confirmed.isNotEmpty ? overview.confirmed.first : null;
      if (next != null) {
        // Ionic has no duty-mine anchor here; with a single confirmed duty
        // the month tile scrolls to "Nächster Dienst" instead of nothing.
        final title = _SectionTitle(title: context.l10n.signoutNextDuty);
        children.add(overview.confirmed.length > 1
            ? title
            : _DutyAnchor(id: 'duty-mine', child: title));
        children.add(Card(
          margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(next.termin.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 2),
                Text(dutyEventMetaLine(next.termin), style: const TextStyle(color: AppColors.medium)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    DutyPill(text: context.l10n.signoutYou, color: AppColors.primary),
                    for (final name in overview.teamOf(next.termin)) DutyPill(text: name, color: AppColors.medium),
                  ],
                ),
                // P10_SELF_PLAN: Ionic `eventChips` of the next duty
                if (chipsFor != null && next.termin.attendance.id != null)
                  ...chipsFor!(next.termin.attendance.id!),
                const SizedBox(height: AppDimensions.paddingS),
                OutlinedButton(
                  onPressed: () => selfServiceDeclineDutyAction(context, ref, next.pa.id!, next.termin),
                  child: IonButtonLabel(context.l10n.signoutCannotAfterAll),
                ),
              ],
            ),
          ),
        ));
      }

      // "Offene Dienste" (preview, urgent first)
      final preview = [...overview.openDuties]
        ..sort((a, b) => (isUrgentDuty(b) ? 1 : 0) - (isUrgentDuty(a) ? 1 : 0));
      children.add(_DutyAnchor(id: 'duty-open', child: _SectionTitle(
        title: context.l10n.signoutOpenDuties,
        action: overview.openDuties.length > 3
            ? TextButton(
                onPressed: () => showOpenDutiesSheet(context),
                child: Text(context.l10n.signoutAllCount(overview.openDuties.length)),
              )
            : null,
      )));
      children.add(Card(
        margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
        child: Column(
          children: [
            if (preview.isEmpty)
              ListTile(
                title: Text(context.l10n.signoutAllDutiesFilled, style: const TextStyle(color: AppColors.medium)),
              ),
            for (final t in preview.take(3))
              ListTile(
                title: Text(t.title),
                subtitle: Text('${_dateShort(t)}${isUrgentDuty(t) ? ' · ${context.l10n.signoutUrgent}' : ''} · ${_dutyMeta(t)}'),
                // Ionic `ion-button slot="end" size="small"` (solid
                // primary); the Beta design keeps its tonal button.
                trailing: context.rdSkin == null
                    ? IonButton(
                        label: context.l10n.commonApply,
                        small: true,
                        onPressed: () => takeDutyAction(context, ref, t.attendance.id!),
                      )
                    : FilledButton.tonal(
                  onPressed: () => takeDutyAction(context, ref, t.attendance.id!),
                  child: IonButtonLabel(context.l10n.commonApply),
                ),
              ),
          ],
        ),
      ));

      // "Meine Dienste"
      final mine = overview.confirmed.skip(1).toList();
      if (mine.isNotEmpty) {
        children.add(_DutyAnchor(
          id: 'duty-mine',
          child: _SectionTitle(title: context.l10n.signoutMyDuties, count: mine.length),
        ));
        children.add(Card(
          margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
          child: Column(
            children: [
              for (final d in mine)
                ListTile(
                  title: Text(d.termin.title),
                  subtitle: Text(
                    '${_dateLine(d.termin)}'
                    '${overview.teamOf(d.termin).isNotEmpty ? context.l10n.signoutWithTeam(overview.teamOf(d.termin).join(', ')) : ''}',
                  ),
                  trailing: DutyPill(text: context.l10n.signoutConfirmed, color: AppColors.successDark),
                  // P10_SELF_PLAN: Ionic opens the Termin action sheet.
                  onTap: onOpenDuty == null || d.termin.attendance.id == null
                      ? null
                      : () => onOpenDuty!(d.termin.attendance.id!),
                ),
            ],
          ),
        ));
      } else if (next == null) {
        // Ionic: empty `duty-mine` anchor at this position.
        children.add(const _DutyAnchor(id: 'duty-mine', child: SizedBox.shrink()));
      }

      children.add(Card(
        margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
        child: Column(
          children: [
            if (otherTermineCount > 0)
              ListTile(
                title: Text(context.l10n.signoutMoreEvents),
                subtitle: Text(otherTermineNames.isEmpty
                    ? '$otherTermineCount'
                    : '$otherTermineCount · $otherTermineNames'),
                trailing: Icon(showOtherTermine ? AppIcons.expandLess : AppIcons.expandMore),
                onTap: onToggleOtherTermine,
              ),
            ListTile(
              leading: Icon(AppIcons.eventBusyOutlined),
              title: Text(context.l10n.signoutRegularlyUnavailable),
              trailing: Icon(AppIcons.chevronRight),
              onTap: () => openUnavailabilityPage(context, personId: overview.person!.id!),
            ),
            if (onReportAbsence != null)
              ListTile(
                leading: Icon(AppIcons.calendarTodayOutlined),
                title: Text(context.l10n.signoutReportAbsence),
                trailing: Icon(AppIcons.chevronRight),
                onTap: onReportAbsence,
              ),
          ],
        ),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// Subtitle of the "Offene Dienste" tile (Ionic signout greet tile).
String openDutiesTileSubtitle(int count) => count == 0
    ? l10nWithoutContext.dutyFlutterAllFilled
    : l10nWithoutContext.tasksOpenCount(count);

String _dateShort(DutyTermin t) {
  final d = DateTime.tryParse(t.attendance.date)?.toLocal();
  if (d == null) return t.attendance.date;
  return '${weekdayShortNames[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';
}

String _dateLine(DutyTermin t) {
  final time = t.attendance.startTime ?? t.type.startTime;
  final timeText = time != null && time.length >= 5 ? ' · ${l10nWithoutContext.dutyFlutterTimeOClock(time.substring(0, 5))}' : '';
  return '${_dateShort(t)}$timeText';
}

/// Ionic `getEventMeta(att, true, false)` on the duty cards ("Bitte
/// bestätigen", "Nächster Dienst"): "Di., 05.11.2026 · 19:00–21:00", only
/// the start time without an end time; no place.
String dutyEventMetaLine(DutyTermin t) {
  final a = t.attendance;
  return EventListUtils.meta([
    EventListUtils.readableDate(a.date, allDay: t.type.allDay, durationDays: t.type.durationDays),
    EventListUtils.timeRange(a.startTime ?? t.type.startTime, a.endTime ?? t.type.endTime),
  ]);
}

String _dutyMeta(DutyTermin t) {
  final time = t.attendance.startTime ?? t.type.startTime;
  final timeText = time != null && time.length >= 5 ? '${time.substring(0, 5)} · ' : '';
  return '$timeText${l10nWithoutContext.signoutDutyOccupied(t.occupied, t.required)}';
}

/// One open duty with "Ich übernehme". On small phones or with large text
/// the button moves below title and date, next to them it would leave the
/// title no room.
Widget _openDutyTile(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Widget button,
}) {
  final narrow = MediaQuery.sizeOf(context).width < MediaQuery.textScalerOf(context).scale(360);
  if (!narrow) {
    return ListTile(title: Text(title), subtitle: Text(subtitle), trailing: button);
  }
  return ListTile(
    title: Text(title),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(subtitle),
        const SizedBox(height: 8),
        button,
      ],
    ),
  );
}

/// Sheet "Offene Dienste" with "Ich übernehme" and "Regelmäßig verhindert".
Future<void> showOpenDutiesSheet(BuildContext context) {
  if (context.rdSkin != null) return _rdOpenDutiesSheet(context);
  // Ionic openDuties modal: [initialBreakpoint]="0.75"
  // [breakpoints]="[0, 0.75, 1]", toolbar with ion-title and the end button
  // "Schließen".
  return showIonSheet<void>(
    context,
    breakpoints: const [0, 0.75, 1],
    initialBreakpoint: 0.75,
    builder: (ctx, scroll) => Consumer(
        builder: (ctx, ref, _) {
          final overview = ref.watch(myDutyOverviewProvider).valueOrNull;
          final open = overview?.openDuties ?? const <DutyTermin>[];
          return IonSheetScaffold(
            title: context.l10n.signoutOpenDuties,
            end: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: IonButtonLabel(context.l10n.commonClose)),
            ],
            body: ListView(
            controller: scroll,
            padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
            children: [
              if (open.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  child: Text(context.l10n.signoutAllDutiesFilled, textAlign: TextAlign.center),
                ),
              for (final t in open)
                _openDutyTile(
                  ctx,
                  title: t.title,
                  subtitle: '${_dateShort(t)} · ${_dutyMeta(t)}',
                  button: FilledButton(
                    onPressed: () => takeDutyAction(ctx, ref, t.attendance.id!),
                    child: IonButtonLabel(context.l10n.signoutIllTakeIt),
                  ),
                ),
              const Divider(),
              if (overview?.person?.id != null)
                ListTile(
                  leading: Icon(AppIcons.eventBusyOutlined),
                  title: Text(context.l10n.signoutRegularlyUnavailable),
                  subtitle: Text(context.l10n.signoutRegularlyUnavailableHint),
                  trailing: Icon(AppIcons.chevronRight),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    openUnavailabilityPage(context, personId: overview!.person!.id!);
                  },
                ),
            ],
            ),
          );
        },
    ),
  );
}

/// Scrolls the duty section [id] (`duty-mine`, `duty-requests`, `duty-open`)
/// into view (Ionic `scrollToSection`). Returns false when the section is not
/// built (not shown, or outside the built part of a lazy list).
bool scrollToDutySection(String id) => _DutyAnchor.scrollTo(id);

/// Ionic `scrollToSection(id)` targets (`duty-mine`, `duty-requests`,
/// `duty-open`): each section title registers its context, a tap on a stat
/// tile scrolls it into view. A registry instead of GlobalKeys, so two
/// mounted sections never clash.
/// Beta (redesign) "Offene Dienste": one row per open duty with a
/// "Ich übernehme" button, then "Regelmäßig verhindert".
Future<void> _rdOpenDutiesSheet(BuildContext context) {
  return showRdPlanSheet<void>(
    context,
    title: context.l10n.signoutOpenDuties,
    builder: (ctx, _) => [
      Consumer(
        builder: (ctx, ref, _) {
          final p = ctx.rd;
          final overview = ref.watch(myDutyOverviewProvider).valueOrNull;
          final open = overview?.openDuties ?? const <DutyTermin>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (open.isEmpty)
                RdInfoCard(text: ctx.l10n.signoutAllDutiesFilled, icon: Icons.check_circle_outline)
              else
                RdGroupedList(
                  children: [
                    for (final t in open)
                      RdListRow(
                        leading: const RdRowIcon(Icons.volunteer_activism_outlined),
                        title: t.title,
                        subtitle: '${_dateShort(t)} · ${_dutyMeta(t)}',
                        showChevron: false,
                        // Below title and date, so a small phone with large
                        // text keeps the title readable.
                        footer: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () => takeDutyAction(ctx, ref, t.attendance.id!),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                            child: Text(ctx.l10n.signoutIllTakeIt,
                                style: TextStyle(color: p.link, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                  ],
                ),
              if (overview?.person?.id != null) ...[
                const SizedBox(height: 16),
                RdGroupedList(
                  children: [
                    RdListRow(
                      leading: const RdRowIcon(Icons.event_busy_outlined),
                      title: ctx.l10n.signoutRegularlyUnavailable,
                      subtitle: ctx.l10n.signoutRegularlyUnavailableHint,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        openUnavailabilityPage(context, personId: overview!.person!.id!);
                      },
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    ],
  );
}

class _DutyAnchor extends StatefulWidget {
  const _DutyAnchor({required this.id, required this.child});

  final String id;
  final Widget child;

  static final Map<String, BuildContext> _contexts = {};

  static bool scrollTo(String id) {
    final ctx = _contexts[id];
    if (ctx == null || !ctx.mounted) return false;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    return true;
  }

  @override
  State<_DutyAnchor> createState() => _DutyAnchorState();
}

class _DutyAnchorState extends State<_DutyAnchor> {
  @override
  Widget build(BuildContext context) {
    _DutyAnchor._contexts[widget.id] = context;
    return widget.child;
  }

  @override
  void dispose() {
    if (identical(_DutyAnchor._contexts[widget.id], context)) {
      _DutyAnchor._contexts.remove(widget.id);
    }
    super.dispose();
  }
}

class _DutyStats extends StatelessWidget {
  const _DutyStats({required this.overview});

  final MyDutyOverview overview;

  @override
  Widget build(BuildContext context) {
    Widget stat(int value, String label, String section, {bool warn = false}) => Expanded(
          child: Card(
            color: warn ? AppColors.warning.withAlpha(46) : null,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _DutyAnchor.scrollTo(section),
              child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingM, horizontal: 4),
              child: Column(
                children: [
                  Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingS),
      child: Row(
        children: [
          stat(overview.dutiesThisMonth, context.l10n.signoutDutiesThisMonth(overview.dutiesThisMonth), 'duty-mine'),
          stat(overview.requests.length, context.l10n.signoutToConfirm, 'duty-requests',
              warn: overview.requests.isNotEmpty),
          stat(overview.openDuties.length, context.l10n.signoutOpenInTeam, 'duty-open'),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count, this.action});

  final String title;
  final int? count;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, 4),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          if (count != null) ...[
            const SizedBox(width: 8),
            DutyPill(text: '$count', color: AppColors.primary),
          ],
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}
