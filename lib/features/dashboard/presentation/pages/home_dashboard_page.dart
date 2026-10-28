import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/dashboard/dashboard_models.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../team_organization/presentation/widgets/my_tasks_card.dart';
import '../widgets/event_cards.dart';
import '../widgets/people_cards.dart';

/// Home dashboard tab (Ionic `home-dashboard`): configurable set of cards in a
/// masonry-like grid (1 / 2 / 3 columns depending on width).
class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({super.key});

  static Widget? cardFor(String id) => switch (id) {
        DashboardCardIds.birthdays => const BirthdaysCard(),
        DashboardCardIds.nextEvent => const NextEventCard(),
        DashboardCardIds.memberChanges => const MemberChangesCard(),
        DashboardCardIds.absences => const AbsencesCard(),
        DashboardCardIds.criticalPersons => const CriticalPersonsCard(),
        DashboardCardIds.currentSongs => const CurrentSongsCard(),
        DashboardCardIds.currentPlan => const CurrentPlanCard(),
        DashboardCardIds.myTasks => const MyTasksCard(),
        _ => null,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(visibleDashboardCardsProvider);
    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const <Tenant>[];
    final tenant = ref.watch(currentTenantProvider);
    final widgets = cards.map((c) => cardFor(c.id)).whereType<Widget>().toList();

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : const Color(0xFFF4F5F8),
      appBar: AppBar(
        title: tenants.length > 1
            ? _TenantSwitcher(tenants: tenants, current: tenant)
            : const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Dashboard konfigurieren',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings/dashboard'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => refreshDashboardCards(ref),
        child: widgets.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                    child: Column(
                      children: [
                        const Icon(Icons.grid_view, size: 48, color: AppColors.medium),
                        const SizedBox(height: 16),
                        const Text(
                          'Alle Karten sind ausgeblendet. Konfiguriere das Dashboard unter Einstellungen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.medium),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => context.push('/settings/dashboard'),
                          child: const Text('Dashboard konfigurieren'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 1200 ? 3 : (width >= 768 ? 2 : 1);
                  if (columns == 1) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      children: widgets,
                    );
                  }
                  // Column-wise distribution like CSS `column-count`.
                  final perColumn = (widgets.length / columns).ceil();
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var c = 0; c < columns; c++)
                          Expanded(
                            child: Column(
                              children: widgets
                                  .skip(c * perColumn)
                                  .take(perColumn)
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Tenant switcher in the app bar (Ionic popover "tenant-switcher-dashboard").
class _TenantSwitcher extends ConsumerWidget {
  const _TenantSwitcher({required this.tenants, required this.current});

  final List<Tenant> tenants;
  final Tenant? current;

  Future<void> _switch(BuildContext context, WidgetRef ref, Tenant t) async {
    if (t.id == current?.id) return;
    final router = GoRouter.of(context);
    final notifier = ref.read(currentTenantProvider.notifier);
    await notifier.setTenant(t);
    await ref.read(currentTenantUserProvider.future);
    final role = ref.read(currentRoleProvider);
    final metadata = ref.read(supabaseAuthProvider).currentUser?.userMetadata;
    router.go(homeRouteFor(role, t.id, metadata));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<Tenant>(
      tooltip: 'Instanz wechseln',
      onSelected: (t) => _switch(context, ref, t),
      itemBuilder: (context) => [
        for (final t in tenants)
          PopupMenuItem<Tenant>(
            value: t,
            child: Row(
              children: [
                Expanded(child: Text(t.longName)),
                if (t.id == current?.id)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Aktuell',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              current?.longName ?? 'Dashboard',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.keyboard_arrow_down),
        ],
      ),
    );
  }
}
