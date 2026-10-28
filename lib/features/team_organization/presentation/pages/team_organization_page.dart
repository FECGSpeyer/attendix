import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/team_org_providers.dart';
import '../../../../l10n/l10n.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../widgets/protocols_tab.dart';
import '../widgets/tasks_tab.dart';
import '../widgets/topics_tab.dart';

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
    with SingleTickerProviderStateMixin {
  static const _tabs = ['tasks', 'topics', 'protocols'];
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    final index = _tabs.indexOf(widget.initialTab ?? 'tasks');
    _controller = TabController(length: 3, vsync: this, initialIndex: index < 0 ? 0 : index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the context providers alive while the page is shown.
    ref.watch(protocolTypesProvider);
    ref.watch(teamPersonProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.teamOrgTitle),
        // Ionic: ion-segment in a second toolbar (iOS segmented control).
        bottom: IonSegmentBar(
          controller: _controller,
          labels: [
            context.l10n.teamOrgTabTasks,
            context.l10n.teamOrgTabTopics,
            context.l10n.teamOrgTabProtocols,
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [
          TasksTab(),
          TopicsTab(),
          ProtocolsTab(),
        ],
      ),
    );
  }
}
