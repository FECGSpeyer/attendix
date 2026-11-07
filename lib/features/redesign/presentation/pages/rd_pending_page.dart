import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../data/rd_manage_logic.dart' show RdManageEntry;
import '../widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../widgets/manage/rd_manage_list.dart';

/// REDESIGN: Verwaltung › Freigaben in the template "Verwaltungsliste"
/// (replaces the old pending sheet while the Beta is on; leads only). The
/// persons waiting for approval (live) with their e-mail; a tap opens
/// "Anfrage prüfen" ([RedesignRoutes.approvalReview]: duplicate check,
/// approve / decline). Once the last person is done the page goes back to
/// the Verwaltung.
class RdPendingPage extends ConsumerStatefulWidget {
  const RdPendingPage({super.key});

  @override
  ConsumerState<RdPendingPage> createState() => _RdPendingPageState();
}

class _RdPendingPageState extends ConsumerState<RdPendingPage> {
  /// The list had persons since the page opened (an empty list right away
  /// stays, with its empty card).
  bool _hadPersons = false;

  /// Emptied while the review page was on top: leave when it returns.
  bool _leaveWhenBack = false;

  void _leaveIfDone() {
    if (!mounted || !_hadPersons) return;
    final persons = rdLoadedValue(ref.read(realtimePendingPlayersProvider));
    if (persons == null || persons.isNotEmpty) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent == false) {
      _leaveWhenBack = true;
      return;
    }
    _leaveWhenBack = false;
    // Leave exactly this route through its own (shell) navigator, where it is
    // the top route (checked above), never `context.pop()`: that pops the
    // topmost route of the app and would close a sheet of the root navigator
    // (e.g. the group switcher) instead.
    final navigator = Navigator.of(context);
    if (route != null && navigator.canPop()) {
      navigator.pop();
    } else {
      GoRouter.of(context).go(RedesignRoutes.manage);
    }
  }

  Future<void> _open(int id) async {
    await context.push(RedesignRoutes.approvalReview(id));
    // The list follows the realtime provider (like the old sheet); it may
    // have been emptied while the review page was on top.
    if (mounted && _leaveWhenBack) _leaveIfDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(realtimePendingPlayersProvider);
    // TENANT: never the old group's list after a group or account switch.
    final persons = rdLoadedValue(async);
    if (persons != null && persons.isNotEmpty) _hadPersons = true;
    ref.listen(realtimePendingPlayersProvider, (_, next) {
      final list = rdLoadedValue(next);
      if (list == null) return;
      if (list.isNotEmpty) {
        _hadPersons = true;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => _leaveIfDone());
      }
    });

    return RdManageListPage(
      title: rdManageTitle(l10n, RdManageEntry.approvals),
      intro: l10n.redesignPendingListIntro,
      sections: persons == null
          ? null
          : [
              RdManageListSection(
                items: [
                  for (final p in persons)
                    RdManageListItem(
                      id: p.id ?? p.fullName,
                      title: p.fullName,
                      subtitle: (p.email ?? '').isEmpty ? null : p.email,
                      onTap: p.id == null ? null : () => _open(p.id!),
                    ),
                ],
              ),
            ],
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(realtimePendingPlayersProvider),
      emptyText: l10n.redesignPendingListEmpty,
      emptyIcon: Icons.how_to_reg_outlined,
      onRefresh: () async {
        ref.invalidate(realtimePendingPlayersProvider);
        await ref.read(realtimePendingPlayersProvider.future).catchError((_) => const <Person>[]);
      },
    );
  }
}
