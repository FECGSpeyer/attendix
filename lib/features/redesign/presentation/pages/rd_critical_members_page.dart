import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../data/providers/rd_critical_providers.dart';
import '../../data/rd_critical_logic.dart';
import '../../data/rd_members_logic.dart' show rdCriticalMembers;
import '../widgets/manage/rd_manage_list.dart';
import '../widgets/rd_split_view.dart' show RdSplitView, rdUseSplit;
import '../widgets/rd_widgets.dart' show rdBack;
import 'rd_person_page.dart' show RdPersonPage;

/// REDESIGN: the current Problemfälle as a page of their own (template
/// "Verwaltungsliste"). Pushed from "Heute" and Verwaltung › Problemfälle,
/// so "‹ zurück" and the swipe back return there; before, those rows only
/// switched to the Mitglieder tab with a filter set. The same set as Heute
/// and the Mitglieder filter (server flag `isCritical`, active members),
/// each with why and the attendance in percent; a tap opens the person.
///
/// Wide screens: the list on the left, the tapped person on the right (like
/// the Mitglieder split), so the way back to this list stays visible.
class RdCriticalMembersPage extends ConsumerStatefulWidget {
  const RdCriticalMembersPage({super.key, this.from});

  /// The page below ('heute' / 'verwaltung'), for the back link.
  final String? from;

  @override
  ConsumerState<RdCriticalMembersPage> createState() => _RdCriticalMembersPageState();
}

class _RdCriticalMembersPageState extends ConsumerState<RdCriticalMembersPage> {
  /// Person open on the right of the split.
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final split = rdUseSplit(context);
    final list = _list(context, split: split);
    if (!split) return list;
    final selected = _selected;
    return RdSplitView(
      list: list,
      detail: selected == null ? null : RdPersonPage(key: ValueKey('rd-critical-person-$selected'), personId: selected),
      selectedId: selected,
      emptyText: context.l10n.redesignSplitMembersEmpty,
    );
  }

  Widget _list(BuildContext context, {required bool split}) {
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    final async = ref.watch(realtimePlayersProvider);
    // TENANT: never the old group's list after a group or account switch.
    final people = role.canSeePeopleTab ? rdLoadedValue(async) : const <Person>[];
    final percentages = ref.watch(playerAttendancePercentagesProvider).valueOrNull ?? const <int, int>{};
    final reasons = rdCriticalContextOf(ref);

    final critical = people == null ? null : (rdCriticalMembers(people)..sort(_byName));
    String? subtitle(Person x) {
      final reason = reasons?.reasonOf(x);
      final parts = [
        if ((x.groupName ?? '').isNotEmpty) x.groupName!,
        if (reason != null) rdCriticalHitText(reason.rule, reason.result, l10n),
      ];
      return parts.isEmpty ? null : parts.join(' · ');
    }

    final (backLabel, backTo) = switch (widget.from) {
      'heute' => (l10n.redesignTabToday, RedesignRoutes.today),
      'verwaltung' => (l10n.rdAdminCritical, RedesignRoutes.critical),
      _ => (l10n.redesignTabMembers, RedesignRoutes.members),
    };

    return RdManageListPage(
      title: l10n.rdCriticalMembersTitle,
      intro: l10n.rdCriticalMembersIntro,
      backLabel: backLabel,
      // Opened by its URL the parent /mitglieder lies beneath: go to the
      // named origin then, pop only when pushed.
      onBack: () => rdBack(context, backTo),
      sections:
          critical == null
              ? null
              : [
                if (critical.isNotEmpty)
                  RdManageListSection(
                    items: [
                      for (final x in critical)
                        RdManageListItem(
                          id: x.id ?? x.fullName,
                          title: x.fullName,
                          subtitle: subtitle(x),
                          count:
                              x.id == null || percentages[x.id] == null
                                  ? null
                                  : l10n.redesignMembersPercent(percentages[x.id]!),
                          onTap:
                              x.id == null
                                  ? null
                                  : split
                                  ? () => setState(() => _selected = x.id)
                                  : () => context.push(RedesignRoutes.person(x.id!)),
                        ),
                    ],
                  ),
              ],
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(realtimePlayersProvider),
      emptyText: l10n.rdCriticalMembersEmpty,
      emptyIcon: Icons.check_circle_outline,
      onRefresh: () async {
        ref.invalidate(realtimePlayersProvider);
        ref.invalidate(playerAttendancePercentagesProvider);
      },
    );
  }
}

int _byName(Person a, Person b) {
  final last = a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
  return last != 0 ? last : a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
}
