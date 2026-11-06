import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/pages/left_players_page.dart' show LeftPlayersPage, leftPlayersProvider;
import '../../data/rd_manage_logic.dart' show RdManageEntry;
import '../widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../widgets/manage/rd_manage_list.dart';

/// REDESIGN: Verwaltung › Archiv in the template "Verwaltungsliste"
/// (replaces the old archive sheet while the Beta is on; leads only). The
/// persons who left, sorted by group like the old list, with group and
/// "Ausgetreten am …"; a tap opens the Beta person (the old list opened the
/// person page), the button on the right restores the person (old
/// confirmation).
class RdArchivePage extends ConsumerWidget {
  const RdArchivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(leftPlayersProvider);
    // TENANT: never the old group's list after a group or account switch.
    final players = rdLoadedValue(async);
    return RdManageListPage(
      title: rdManageTitle(l10n, RdManageEntry.archive),
      intro: l10n.redesignArchiveListIntro,
      sections: players == null ? null : [RdManageListSection(items: rdArchiveItems(context, ref, players))],
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(leftPlayersProvider),
      emptyText: l10n.redesignArchiveListEmpty,
      emptyIcon: Icons.archive_outlined,
      onRefresh: () async {
        ref.invalidate(leftPlayersProvider);
        await ref.read(leftPlayersProvider.future).catchError((_) => const <Person>[]);
      },
    );
  }
}

/// The rows of [RdArchivePage].
List<RdManageListItem> rdArchiveItems(BuildContext context, WidgetRef ref, List<Person> players) {
  final l10n = context.l10n;
  final format = DateFormat(dateFmt());
  String? leftOn(Person p) {
    final left = p.left;
    if (left == null) return null;
    final date = DateTime.tryParse(left);
    return l10n.settingsLeftOn(date == null ? left : format.format(date));
  }

  String? subtitle(Person p) {
    final parts = [
      if ((p.groupName ?? '').isNotEmpty) p.groupName!,
      if (leftOn(p) case final left?) left,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  return [
    for (final p in players)
      RdManageListItem(
        id: p.id ?? p.fullName,
        title: p.fullName,
        subtitle: subtitle(p),
        trailing: IconButton(
          key: ValueKey('rd-archive-restore-${p.id}'),
          icon: Icon(Icons.restore, color: context.rd.present),
          tooltip: l10n.redesignArchiveListRestore,
          onPressed: () => LeftPlayersPage.reactivateWithConfirmation(context, ref, p),
        ),
        onTap: p.id == null
            ? null
            : () async {
                await context.push(RedesignRoutes.person(p.id!));
                // Restored on the person page: show the current archive.
                if (context.mounted) ref.invalidate(leftPlayersProvider);
              },
      ),
  ];
}
