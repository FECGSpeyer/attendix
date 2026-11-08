import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../l10n/l10n.dart';
import '../../data/rd_manage_logic.dart' show RdManageEntry;
import '../widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../widgets/manage/rd_manage_list.dart';
import '../widgets/manage/rd_type_create_sheet.dart';

/// REDESIGN: Verwaltung › Anwesenheits-Typen in the template
/// "Verwaltungsliste" (replaces the list of `/settings/types` while the Beta
/// is on). Time and default status as subtitle; "Reihenfolge ändern" behind
/// "•••". A type and "+" open the existing type page for now.
class RdAttendanceTypesPage extends ConsumerStatefulWidget {
  const RdAttendanceTypesPage({super.key});

  @override
  ConsumerState<RdAttendanceTypesPage> createState() => _RdAttendanceTypesPageState();
}

class _RdAttendanceTypesPageState extends ConsumerState<RdAttendanceTypesPage> {
  Future<void> _refresh() async {
    ref.invalidate(attendanceTypesProvider);
    await ref.read(attendanceTypesProvider.future).catchError((_) => const <AttendanceType>[]);
  }

  /// Old page: the ids in the new order (`reorderTypes`); on an error the
  /// moved order stays.
  Future<bool> _saveOrder(List<AttendanceType> types, List<RdManageListSection> sections) async {
    final l10n = context.l10n;
    final stored = {for (final t in types) if (t.id != null) t.id!};
    final ids = [
      for (final s in sections)
        for (final item in s.items)
          if (stored.contains(item.id)) item.id as String,
    ];
    var ok = false;
    try {
      ok = await ref.read(attendanceTypeNotifierProvider.notifier).reorderTypes(ids);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return ok;
    if (ok) {
      ToastHelper.showSuccess(context, l10n.typeSettingsOrderSaved);
    } else {
      ToastHelper.showError(context, l10n.redesignManageListOrderFailed);
    }
    return ok;
  }

  Future<void> _add() async {
    final id = await showRdTypeCreateSheet(context);
    if (id == null || !mounted) return;
    await context.push('/settings/types/$id');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(attendanceTypesProvider);
    final types = async.valueOrNull;

    return RdManageListPage(
      title: rdManageTitle(l10n, RdManageEntry.attendanceTypes),
      intro: l10n.redesignTypesListIntro,
      sections:
          types == null
              ? null
              : [
                RdManageListSection(
                  items: [
                    for (final (i, t) in types.indexed)
                      RdManageListItem(
                        // Types without id (never stored) are not sorted.
                        id: t.id ?? 'unsaved-$i',
                        title: t.name,
                        subtitle: rdAttendanceTypeSubtitle(l10n, t),
                        onTap: t.id == null ? null : () => context.push('/settings/types/${t.id}'),
                      ),
                  ],
                ),
              ],
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(attendanceTypesProvider),
      emptyText: l10n.redesignTypesListEmpty,
      emptyIcon: Icons.category_outlined,
      addLabel: l10n.redesignTypesListAdd,
      // A name and "Startet wie" in a sheet, then the new type's page.
      onAdd: _add,
      onReorder: types == null ? null : (sections) => _saveOrder(types, sections),
      onRefresh: _refresh,
    );
  }
}

/// "19:00–21:00 · Standard: Anwesend · Ausgeblendet".
String rdAttendanceTypeSubtitle(AppLocalizations l10n, AttendanceType type) {
  String hhmm(String? t) => t == null ? '' : (t.length >= 5 ? t.substring(0, 5) : t);
  final time =
      type.allDay
          ? l10n.redesignTypesListAllDayDays(type.durationDays ?? 1)
          : [hhmm(type.startTime), hhmm(type.endTime)].where((t) => t.isNotEmpty).join('–');
  return [
    time,
    l10n.redesignTypesListDefaultStatus(type.defaultStatus.label),
    if (!type.visible) l10n.redesignTypesListHidden,
  ].where((s) => s.isNotEmpty).join(' · ');
}
