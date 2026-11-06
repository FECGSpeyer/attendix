import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/teacher_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/teacher_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../teachers/presentation/pages/teachers_list_page.dart' show showAddTeacherSheet;
import '../../data/rd_manage_logic.dart' show RdManageEntry;
import '../widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../widgets/manage/rd_manage_list.dart';

/// REDESIGN: Verwaltung › Lehrer in the template "Verwaltungsliste"
/// (replaces `/settings/teachers` while the Beta is on). Name, instruments
/// and "n Spieler" per teacher, like the old page. Admins and
/// Verantwortliche add ("+", the old sheet) and open a teacher; Beobachter
/// only see the list (old page: the route is open to them, tap and "+" not).
/// Teachers have no order (old page: by name from the database), so there is
/// no "Reihenfolge ändern".
class RdTeachersPage extends ConsumerWidget {
  const RdTeachersPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(teachersProvider);
    ref.invalidate(studentCountsProvider);
    ref.invalidate(enrichedTeachersProvider);
    await ref.read(enrichedTeachersProvider.future).catchError((_) => const <Teacher>[]);
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    // The sheet returns null when closed or when creating failed; only a
    // new error state of the notifier means it failed.
    final before = ref.read(teacherNotifierProvider);
    final created = await showAddTeacherSheet(context, ref);
    if (!context.mounted) return;
    final after = ref.read(teacherNotifierProvider);
    if (created?.id != null) {
      context.push(RedesignRoutes.teacherEdit(created!.id!));
    } else if (!identical(after, before) && after.hasError) {
      ToastHelper.showError(context, l10n.redesignTeachersListAddFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    // Old page: isAdmin = Admin or Verantwortliche.
    final isAdmin = role.isAdmin || role.isResponsible;
    final async = ref.watch(enrichedTeachersProvider);
    final teachers = async.valueOrNull;

    return RdManageListPage(
      title: rdManageTitle(l10n, RdManageEntry.teachers),
      intro: l10n.redesignTeachersListIntro,
      sections:
          teachers == null
              ? null
              : rdTeacherSections(
                l10n,
                teachers,
                onTap: isAdmin ? (id) => context.push(RedesignRoutes.teacherEdit(id)) : null,
              ),
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(enrichedTeachersProvider),
      emptyText: l10n.redesignTeachersListEmpty,
      emptyIcon: Icons.school_outlined,
      addLabel: l10n.redesignTeachersListAdd,
      onAdd: isAdmin ? () => _add(context, ref) : null,
      onRefresh: () => _refresh(ref),
    );
  }
}

/// The teachers as one list without heading, in the order of the old page.
/// A teacher without players shows the count in red (old page: danger badge).
List<RdManageListSection> rdTeacherSections(
  AppLocalizations l10n,
  List<Teacher> teachers, {
  void Function(int id)? onTap,
}) => [
  RdManageListSection(
    items: [
      for (final t in teachers)
        RdManageListItem(
          id: t.id ?? t.name,
          title: t.name,
          subtitle: (t.insNames ?? '').isEmpty ? null : t.insNames,
          count: l10n.teachersPlayerCount(t.playerCount ?? 0),
          countWarn: (t.playerCount ?? 0) == 0,
          onTap: onTap == null || t.id == null ? null : () => onTap(t.id!),
        ),
    ],
  ),
];
