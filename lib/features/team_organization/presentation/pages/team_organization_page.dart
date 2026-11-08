import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';

import '../../../../core/providers/team_org_providers.dart';
import '../../../../l10n/l10n.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../widgets/protocols_tab.dart';
import '../widgets/tasks_tab.dart';
import '../widgets/topics_tab.dart';
import '../utils/route_return_reload.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart' show ionPlainContentBackground;

/// Teamorganisation: one page for leadership and members. RLS decides what
/// each person sees; the tabs only change their actions.
class TeamOrganizationPage extends ConsumerStatefulWidget {
  const TeamOrganizationPage({super.key, this.initialTab});

  /// tasks | topics | protocols (query parameter `tab`).
  final String? initialTab;

  @override
  ConsumerState<TeamOrganizationPage> createState() => _TeamOrganizationPageState();
}

class _TeamOrganizationPageState extends ConsumerState<TeamOrganizationPage>
    with SingleTickerProviderStateMixin, RouteReturnReload {
  static const _tabs = ['tasks', 'topics', 'protocols'];
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    final index = _tabs.indexOf(widget.initialTab ?? 'tasks');
    _controller = TabController(length: 3, vsync: this, initialIndex: index < 0 ? 0 : index);
    // Ionic: each tab loads on init (also when the segment changes, @switch
    // creates it anew), the cached lists stay visible meanwhile.
    _controller.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadActive(firstLoad: true));
  }

  @override
  void dispose() {
    _controller.removeListener(_onTabChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_controller.indexIsChanging) _reloadActive();
  }

  /// Ionic ionViewWillEnter: coming back to the page (from a task, topic,
  /// protocol or any other page) reloads the active tab.
  @override
  void onRouteReturn() => _reloadActive();

  /// [firstLoad] only on the first open; tab change and return always load
  /// anew (a running load may predate a change).
  void _reloadActive({bool firstLoad = false}) {
    if (!mounted) return;
    reloadTeamOrgTab(ref, _tabs[_controller.index], firstLoad: firstLoad);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the context providers alive while the page is shown.
    ref.watch(protocolTypesProvider);
    ref.watch(teamPersonProvider);
    if (ref.watch(redesignEnabledProvider)) return _buildBeta(context);

    return Scaffold(
      // PARITY_R5: team-organization.page.html `<ion-content>` without
      // colour → white page (the inset lists sit on it).
      backgroundColor: ionPlainContentBackground(context),
      appBar: AppBar(
        title: Text(context.l10n.teamOrgTitle),
        // Ionic: ion-segment in a second toolbar (iOS segmented control).
        bottom: IonSegmentBar(
          controller: _controller,
          labels: [context.l10n.teamOrgTabTasks, context.l10n.teamOrgTabTopics, context.l10n.teamOrgTabProtocols],
        ),
      ),
      body: TabBarView(controller: _controller, children: const [TasksTab(), TopicsTab(), ProtocolsTab()]),
    );
  }

  /// Beta: same tabs, Beta frame (back link, large title, segment).
  Widget _buildBeta(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final labels = [l10n.teamOrgTabTasks, l10n.teamOrgTabTopics, l10n.teamOrgTabProtocols];
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RdBackLink(
                    label: l10n.redesignTabMe,
                    onTap: () => rdBack(context, RedesignRoutes.me),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.teamOrgTitle, style: RdType.largeTitle(p)),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _controller.animation!,
                    builder:
                        (context, _) => RdSegmented<int>(
                          values: const [0, 1, 2],
                          selected: _controller.index,
                          position: _controller.animation!.value,
                          labelOf: (i) => labels[i],
                          onChanged: _controller.animateTo,
                        ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(controller: _controller, children: const [TasksTab(), TopicsTab(), ProtocolsTab()]),
            ),
          ],
        ),
      ),
    );
  }
}
