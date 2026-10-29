import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/dashboard/dashboard_models.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../messages/presentation/widgets/notification_bell.dart';
import '../../../team_organization/presentation/widgets/my_tasks_card.dart';
import '../widgets/event_cards.dart';
import '../widgets/people_cards.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/app_toolbar.dart'; // IOS_SHELL
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2
import '../../../../shared/widgets/layout/ionic_ios.dart';
import '../../../../shared/widgets/adaptive/ion_button_label.dart'; // IOS_R6
import '../../../../shared/widgets/tenant/tenant_switcher_title.dart'; // P10_SELF_PLAN
import '../../../../shared/widgets/adaptive/adaptive_platform.dart'; // P10_SELF_PLAN

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
    final ios = useIosLook(context);
    final widgets = cards.map((c) => cardFor(c.id)).whereType<Widget>().toList();
    // IOS_R6: Ionic `ion-header collapse="condense"` only with one tenant
    // (the tenant switcher has no large title).
    final largeTitle = tenants.length <= 1;
    final top = [
      const IonContentTopInset(),
      IonLargeTitle(context.l10n.tabsDashboard, enabled: largeTitle),
    ];

    return CondenseHeader(
      enabled: largeTitle,
      builder: (context, condensed) => Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : const Color(0xFFF4F5F8),
      // IOS_R6: Ionic `ion-content fullscreen` under the translucent header
      extendBodyBehindAppBar: isIosLook(context),
      // IOS_R6: `ion-header translucent` (blur once condensed)
      appBar: IonTranslucentAppBar(
        condensed: condensed,
        child: AppBar(
        // P10_SELF_PLAN: shared Ionic tenant switcher (ion-buttons slot="start").
        title: tenants.length > 1
            ? TenantSwitcherTitle(
                fallbackTitle: context.l10n.tabsDashboard,
                onSelected: (t) => _switchDashboardTenant(context, ref, t),
              )
            : CondenseTitle(
                condensed: condensed, child: Text(context.l10n.tabsDashboard)),
        centerTitle: tenants.length > 1 ? false : null,
        // IOS_SHELL: iOS → one glass capsule (ion-buttons slot="end")
        actions: [
          ToolbarButtonGroup(children: [
            // P10_SELF_PLAN: Ionic `@if (!isIos)` – on iOS the settings
            // button is the ion-fab below.
            if (!ios)
              IconButton(
                tooltip: context.l10n.homeDashboardConfigure,
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/settings/dashboard'),
              ),
            const NotificationBell(), // INTEGRATION (Ionic app-notification-bell)
          ]),
        ],
      ),
      ),
      // P10_SELF_PLAN: Ionic `@if (isIos)` ion-fab (settings-outline).
      floatingActionButton: ios
          ? TabBarFab(
              child: FloatingActionButton(
                heroTag: 'homeDashboardSettingsFab',
                tooltip: context.l10n.homeDashboardConfigure,
                onPressed: () => context.push('/settings/dashboard'),
                child: const Icon(Icons.settings_outlined),
              ),
            )
          : null,
      body: IonRefresher( // IOS_R6
        onRefresh: () async => refreshDashboardCards(ref),
        child: widgets.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ...top, // IOS_R6
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                    child: Column(
                      children: [
                        const Icon(Icons.grid_view, size: 48, color: AppColors.medium),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.homeDashboardAllHidden,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.medium),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => context.push('/settings/dashboard'),
                          child: IonButtonLabel(context.l10n.homeDashboardConfigure),
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
                      padding: EdgeInsets.only(bottom: scrollEndPadding(context, base: 24)),
                      children: [...top, ...widgets], // IOS_R6
                    );
                  }
                  // Column-wise distribution like CSS `column-count`.
                  final perColumn = (widgets.length / columns).ceil();
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(8, 0, 8, scrollEndPadding(context, base: 24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...top, // IOS_R6
                        Row(
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
                      ],
                    ),
                  );
                },
              ),
      ),
      ),
    );
  }
}

/// Tenant switch of the dashboard (Ionic `onTenantChange`: set the tenant
/// and open the role's start page, `Utils.getUrl`).
Future<void> _switchDashboardTenant(BuildContext context, WidgetRef ref, Tenant t) async {
  if (t.id == null || t.id == ref.read(currentTenantProvider)?.id) return;
  final router = GoRouter.of(context);
  final notifier = ref.read(currentTenantProvider.notifier);
  await notifier.setTenant(t);
  await ref.read(currentTenantUserProvider.future);
  final role = ref.read(currentRoleProvider);
  final metadata = ref.read(supabaseAuthProvider).currentUser?.userMetadata;
  router.go(homeRouteFor(role, t.id, metadata));
}
