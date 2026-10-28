import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duty_utils.dart';
import '../pages/unavailability_page.dart';
import 'duty_actions.dart';

/// Dienstplan part of "Meine Termine" (self service): "Bitte bestätigen",
/// and – when the tenant uses the Dienstplan view – "Nächster Dienst",
/// "Offene Dienste", "Meine Dienste" and "Regelmäßig verhindert".
///
/// Outside the Dienstplan view a compact "Offene Dienste" tile is shown for
/// persons in a duty circle.
class SelfServiceDutySection extends ConsumerWidget {
  const SelfServiceDutySection({
    super.key,
    this.showOtherTermine = false,
    this.otherTermineCount = 0,
    this.onToggleOtherTermine,
  });

  final bool showOtherTermine;
  final int otherTermineCount;
  final VoidCallback? onToggleOtherTermine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(myDutyOverviewProvider).valueOrNull;
    if (overview == null || overview.person == null) return const SizedBox.shrink();
    if (!overview.inDutyCircle && overview.requests.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];

    if (overview.useDutyView) {
      children.add(_DutyStats(overview: overview));
    } else if (overview.inDutyCircle) {
      children.add(Card(
        margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
        child: ListTile(
          leading: const Icon(Icons.headset_mic_outlined, color: AppColors.primary),
          title: const Text('Offene Dienste'),
          subtitle: Text(overview.openDuties.isEmpty
              ? 'alles besetzt'
              : overview.openDuties.length == 1
                  ? '1 offen'
                  : '${overview.openDuties.length} offen'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showOpenDutiesSheet(context),
        ),
      ));
    }

    // "Bitte bestätigen"
    if (overview.requests.isNotEmpty) {
      children.add(_SectionTitle(title: 'Bitte bestätigen', count: overview.requests.length));
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
                Text(_dateLine(r.termin), style: const TextStyle(color: AppColors.medium)),
                const SizedBox(height: 6),
                const DutyPill(text: 'Du bist eingeteilt', color: AppColors.warningDark),
                const SizedBox(height: AppDimensions.paddingS),
                Row(
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                      onPressed: () => confirmDutyAction(context, ref, r.pa.id!, r.termin.attendance.id!),
                      child: const Text('Bestätigen'),
                    ),
                    const SizedBox(width: AppDimensions.paddingS),
                    OutlinedButton(
                      onPressed: () => declineDutyAction(context, ref, r.pa.id!, r.termin.attendance.id!),
                      child: const Text('Kann nicht'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));
      }
    }

    if (overview.useDutyView) {
      // "Nächster Dienst"
      final next = overview.confirmed.isNotEmpty ? overview.confirmed.first : null;
      if (next != null) {
        children.add(const _SectionTitle(title: 'Nächster Dienst'));
        children.add(Card(
          margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(next.termin.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 2),
                Text(_dateLine(next.termin), style: const TextStyle(color: AppColors.medium)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const DutyPill(text: 'Du', color: AppColors.primary),
                    for (final name in overview.teamOf(next.termin)) DutyPill(text: name, color: AppColors.medium),
                  ],
                ),
                const SizedBox(height: AppDimensions.paddingS),
                OutlinedButton(
                  onPressed: () => declineDutyAction(context, ref, next.pa.id!, next.termin.attendance.id!),
                  child: const Text('Kann doch nicht'),
                ),
              ],
            ),
          ),
        ));
      }

      // "Offene Dienste" (preview, urgent first)
      final preview = [...overview.openDuties]
        ..sort((a, b) => (isUrgentDuty(b) ? 1 : 0) - (isUrgentDuty(a) ? 1 : 0));
      children.add(_SectionTitle(
        title: 'Offene Dienste',
        action: overview.openDuties.length > 3
            ? TextButton(
                onPressed: () => showOpenDutiesSheet(context),
                child: Text('Alle ${overview.openDuties.length}'),
              )
            : null,
      ));
      children.add(Card(
        margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
        child: Column(
          children: [
            if (preview.isEmpty)
              const ListTile(
                title: Text('Gerade sind alle Dienste besetzt. Danke!', style: TextStyle(color: AppColors.medium)),
              ),
            for (final t in preview.take(3))
              ListTile(
                title: Text(t.title),
                subtitle: Text('${_dateShort(t)}${isUrgentDuty(t) ? ' · Dringend' : ''} · ${_dutyMeta(t)}'),
                trailing: FilledButton.tonal(
                  onPressed: () => takeDutyAction(context, ref, t.attendance.id!),
                  child: const Text('Übernehmen'),
                ),
              ),
          ],
        ),
      ));

      // "Meine Dienste"
      final mine = overview.confirmed.skip(1).toList();
      if (mine.isNotEmpty) {
        children.add(_SectionTitle(title: 'Meine Dienste', count: mine.length));
        children.add(Card(
          margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
          child: Column(
            children: [
              for (final d in mine)
                ListTile(
                  title: Text(d.termin.title),
                  subtitle: Text(
                    '${_dateLine(d.termin)}'
                    '${overview.teamOf(d.termin).isNotEmpty ? ' · mit ${overview.teamOf(d.termin).join(', ')}' : ''}',
                  ),
                  trailing: const DutyPill(text: 'bestätigt', color: AppColors.successDark),
                  onLongPress: () => declineDutyAction(context, ref, d.pa.id!, d.termin.attendance.id!),
                ),
            ],
          ),
        ));
      }

      children.add(Card(
        margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
        child: Column(
          children: [
            if (otherTermineCount > 0)
              ListTile(
                title: const Text('Weitere Termine'),
                subtitle: Text('$otherTermineCount'),
                trailing: Icon(showOtherTermine ? Icons.expand_less : Icons.expand_more),
                onTap: onToggleOtherTermine,
              ),
            ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: const Text('Regelmäßig verhindert'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openUnavailabilityPage(context, personId: overview.person!.id!),
            ),
          ],
        ),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

String _dateShort(DutyTermin t) {
  final d = DateTime.tryParse(t.attendance.date)?.toLocal();
  if (d == null) return t.attendance.date;
  return '${weekdayShortNames[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';
}

String _dateLine(DutyTermin t) {
  final time = t.attendance.startTime ?? t.type.startTime;
  final timeText = time != null && time.length >= 5 ? ' · ${time.substring(0, 5)} Uhr' : '';
  return '${_dateShort(t)}$timeText';
}

String _dutyMeta(DutyTermin t) {
  final time = t.attendance.startTime ?? t.type.startTime;
  final timeText = time != null && time.length >= 5 ? '${time.substring(0, 5)} · ' : '';
  return '$timeText${t.occupied} von ${t.required} besetzt';
}

/// Sheet "Offene Dienste" with "Ich übernehme" and "Regelmäßig verhindert".
Future<void> showOpenDutiesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (ctx, scroll) => Consumer(
        builder: (ctx, ref, _) {
          final overview = ref.watch(myDutyOverviewProvider).valueOrNull;
          final open = overview?.openDuties ?? const <DutyTermin>[];
          return ListView(
            controller: scroll,
            children: [
              ListTile(
                title: const Text('Offene Dienste', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Schließen')),
              ),
              const Divider(height: 1),
              if (open.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppDimensions.paddingL),
                  child: Text('Gerade sind alle Dienste besetzt. Danke!', textAlign: TextAlign.center),
                ),
              for (final t in open)
                ListTile(
                  title: Text(t.title),
                  subtitle: Text('${_dateShort(t)} · ${_dutyMeta(t)}'),
                  trailing: FilledButton(
                    onPressed: () => takeDutyAction(ctx, ref, t.attendance.id!),
                    child: const Text('Ich übernehme'),
                  ),
                ),
              const Divider(),
              if (overview?.person?.id != null)
                ListTile(
                  leading: const Icon(Icons.event_busy_outlined),
                  title: const Text('Regelmäßig verhindert'),
                  subtitle: const Text('z. B. jeden Mittwoch wegen der Kinderstunde'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    openUnavailabilityPage(context, personId: overview!.person!.id!);
                  },
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _DutyStats extends StatelessWidget {
  const _DutyStats({required this.overview});

  final MyDutyOverview overview;

  @override
  Widget build(BuildContext context) {
    Widget stat(int value, String label, {bool warn = false}) => Expanded(
          child: Card(
            color: warn ? AppColors.warning.withAlpha(46) : null,
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
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingS),
      child: Row(
        children: [
          stat(overview.dutiesThisMonth, overview.dutiesThisMonth == 1 ? 'Dienst diesen Monat' : 'Dienste diesen Monat'),
          stat(overview.requests.length, 'zu bestätigen', warn: overview.requests.isNotEmpty),
          stat(overview.openDuties.length, 'offen im Team'),
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
