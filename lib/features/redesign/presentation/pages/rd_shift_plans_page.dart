import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/shift_providers.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../../../../l10n/l10n.dart';
import '../../../shifts/presentation/pages/shifts_list_page.dart' show showCreateShiftPlanSheet;
import '../../data/rd_manage_logic.dart' show RdManageEntry;
import '../widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../widgets/manage/rd_manage_list.dart';

/// REDESIGN: Verwaltung › Schichtpläne in the template "Verwaltungsliste"
/// (replaces the list of `/settings/shifts` while the Beta is on). The
/// description as subtitle, the number of shifts (or the cycle) on the
/// right. A plan opens the existing plan page; "+" creates a plan like the
/// old page and then opens it.
class RdShiftPlansPage extends ConsumerWidget {
  const RdShiftPlansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(shiftsProvider);
    final plans = async.valueOrNull;

    Future<void> refresh() async {
      ref.invalidate(shiftsProvider);
      await ref.read(shiftsProvider.future).catchError((_) => const <ShiftPlan>[]);
    }

    return RdManageListPage(
      title: rdManageTitle(l10n, RdManageEntry.shiftPlans),
      intro: l10n.redesignShiftsListIntro,
      notice: l10n.redesignShiftsListImportant,
      sections:
          plans == null
              ? null
              : [
                RdManageListSection(
                  items: [
                    for (final (i, plan) in plans.indexed)
                      RdManageListItem(
                        id: plan.id ?? 'unsaved-$i',
                        title: plan.name,
                        subtitle: plan.description.trim().isEmpty ? null : plan.description.trim(),
                        count: rdShiftPlanCount(l10n, plan),
                        onTap: plan.id == null ? null : () => context.push('/settings/shifts/${plan.id}'),
                      ),
                  ],
                ),
              ],
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(shiftsProvider),
      emptyText: l10n.redesignShiftsListEmpty,
      emptyIcon: Icons.schedule,
      addLabel: l10n.redesignShiftsListAdd,
      onAdd: () => showCreateShiftPlanSheet(context, ref),
      onRefresh: refresh,
    );
  }
}

/// "3 Schichten" for a plan with fixed shifts, "Zyklus 7 Tage" for a
/// repeating plan, null for an empty plan.
String? rdShiftPlanCount(AppLocalizations l10n, ShiftPlan plan) {
  if (plan.shifts.isNotEmpty) return l10n.redesignShiftsListShifts(plan.shifts.length);
  if (plan.definition.isNotEmpty) return l10n.redesignShiftsListCycle(plan.cycleLengthDays);
  return null;
}
