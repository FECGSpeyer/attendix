import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../l10n/l10n.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../widgets/protocols_tab.dart';
import '../widgets/tasks_tab.dart';
import '../widgets/topics_tab.dart';
import '../utils/route_return_reload.dart';
import 'rd_team_page.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart' show ionPlainContentBackground;

/// Teamorganisation: one page for leadership and members. RLS decides what
/// each person sees; the tabs only change their actions.
class TeamOrganizationPage extends ConsumerWidget {
  const TeamOrganizationPage({super.key, this.initialTab});

  /// tasks | topics | protocols (query parameter `tab`).
  final String? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(redesignEnabledProvider) ? RdTeamPage(initialTab: initialTab) : _ClassicTeamPage(initialTab: initialTab);
}

class _ClassicTeamPage extends ConsumerStatefulWidget {
  const _ClassicTeamPage({this.initialTab});

  final String? initialTab;

  @override
  ConsumerState<_ClassicTeamPage> createState() => _ClassicTeamPageState();
}

class _ClassicTeamPageState extends ConsumerState<_ClassicTeamPage>
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
      // DAS-32: Ionic switches the tabs only via the ion-segment, not by a
      // horizontal swipe.
      body: TabBarView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        children: const [TasksTab(), TopicsTab(), ProtocolsTab()],
      ),
    );
  }
}
