import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/models/shift/shift_instance.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../../../../l10n/l10n.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // PARITY_R5

/// Shows the Ionic "calculate shifts" modal (full height sheet, close button
/// at the end, plain list "Berechnete Schichten").
void showShiftPreviewSheet(BuildContext context, ShiftPlan plan, {ShiftInstance? startInstance}) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 1,
      child: ShiftPreviewSheet(plan: plan, startInstance: startInstance),
    ),
  );
}

/// One computed day of the preview.
class ComputedShift {
  const ComputedShift({
    required this.date,
    required this.free,
    required this.startTime,
    required this.endTime,
    required this.duration,
  });

  final DateTime date;
  final bool free;
  final String startTime;
  final String endTime;
  final double duration;
}

/// Mirrors Ionic `ShiftPage.calculateShifts`: starts at the fixed shift's
/// date (or Monday of next week) and walks the definition cycle day by day.
List<ComputedShift> computeShiftPreview(ShiftPlan plan, {ShiftInstance? startInstance, DateTime? now}) {
  final defs = plan.definition;
  if (defs.isEmpty) return const [];

  DateTime start;
  final instanceDate = startInstance?.dateTime;
  if (instanceDate != null) {
    start = DateTime(instanceDate.year, instanceDate.month, instanceDate.day);
  } else {
    final base = now ?? DateTime.now();
    final nextWeek = DateTime(base.year, base.month, base.day + 7);
    // dayjs().day(1): Monday of that (Sunday based) week.
    start = DateTime(nextWeek.year, nextWeek.month, nextWeek.day + 1 - nextWeek.weekday % 7);
  }
  final end = DateTime(start.year, start.month, start.day + 30);

  final result = <ComputedShift>[];
  var current = start;
  var day = 0;
  while (current.isBefore(end)) {
    for (final def in defs) {
      for (var i = 0; i < def.repeatCount; i++) {
        final date = DateTime(start.year, start.month, start.day + day);
        final parts = def.startTime.split(':');
        final startAt = DateTime(date.year, date.month, date.day,
            int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0,
            int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0);
        final endAt = startAt.add(Duration(minutes: (def.duration * 60).round()));
        final sameDay = endAt.year == date.year && endAt.month == date.month && endAt.day == date.day;
        final endText = DateFormat('HH:mm').format(endAt);
        result.add(ComputedShift(
          date: date,
          free: def.free,
          startTime: def.startTime,
          endTime: sameDay ? endText : '$endText (+1)',
          duration: def.duration,
        ));
        day++;
      }
    }
    current = DateTime(current.year, current.month, current.day + defs.length);
  }
  return result;
}

/// Preview content of the computed shifts.
class ShiftPreviewSheet extends StatelessWidget {
  final ShiftPlan plan;
  final ShiftInstance? startInstance;

  const ShiftPreviewSheet({
    super.key,
    required this.plan,
    this.startInstance,
  });

  String _hours(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  @override
  Widget build(BuildContext context) {
    final shifts = computeShiftPreview(plan, startInstance: startInstance);
    final dateFormat = DateFormat('EEE, ${dateFmt()}', currentIntlLocale());

    return Column(
      children: [
        AppBar(
          toolbarHeight: ionModalToolbarHeight(context), // PARITY_R5
          automaticallyImplyLeading: false,
          primary: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.l10n.commonClose,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: shifts.length + 1,
            separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(height: 1, indent: 16),
            itemBuilder: (context, index) {
              if (index == 0) {
                return IonListHeader(
                  title: context.l10n.shiftsComputed,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                );
              }
              final cs = shifts[index - 1];
              return ListTile(
                title: Text(dateFormat.format(cs.date)),
                subtitle: Text(
                  cs.free
                      ? context.l10n.shiftsFree
                      : context.l10n.shiftsComputedLine(cs.startTime, cs.endTime, _hours(cs.duration)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
