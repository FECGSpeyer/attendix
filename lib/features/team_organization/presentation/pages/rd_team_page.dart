import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../utils/route_return_reload.dart';
import '../widgets/rd_meetings_tab.dart';
import '../widgets/rd_team_tasks_tab.dart';
import '../widgets/rd_open_topics.dart';

/// Beta "Team": Besprechungen and Aufgaben. Who is neither leadership nor
/// in a circle only has tasks, so the page is then just "Meine Aufgaben".
class RdTeamPage extends ConsumerStatefulWidget {
  const RdTeamPage({super.key, this.initialTab});

  /// `tasks` opens Aufgaben, anything else Besprechungen (the old links to
  /// `topics` and `protocols` land there).
  final String? initialTab;

  @override
  ConsumerState<RdTeamPage> createState() => _RdTeamPageState();
}

class _RdTeamPageState extends ConsumerState<RdTeamPage> with SingleTickerProviderStateMixin, RouteReturnReload {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 2, vsync: this, initialIndex: widget.initialTab == 'tasks' ? 1 : 0);
    _controller.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload(firstLoad: true));
  }

  @override
  void dispose() {
    _controller.removeListener(_onTabChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_controller.indexIsChanging) _reload();
  }

  @override
  void onRouteReturn() => _reload();

  void _reload({bool firstLoad = false}) {
    if (!mounted) return;
    final meetings = ref.read(rdTeamMeetingsVisibleProvider) && _controller.index == 0;
    reloadTeamOrgTab(ref, meetings ? 'topics' : 'tasks', firstLoad: firstLoad);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the context providers alive while the page is shown.
    ref.watch(protocolTypesProvider);
    ref.watch(teamPersonProvider);
    final p = context.rd;
    final l10n = context.l10n;
    final inCircle = ref.watch(rdTeamMeetingsVisibleProvider);
    final labels = [l10n.rdTeamTabMeetings, l10n.teamOrgTabTasks];
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
                  RdBackLink(label: l10n.redesignTabMe, onTap: () => rdBack(context, RedesignRoutes.me)),
                  const SizedBox(height: 8),
                  Text(inCircle ? l10n.rdTeamTitle : l10n.tasksMyTasks, style: RdType.largeTitle(p)),
                  const SizedBox(height: 12),
                  if (inCircle) ...[
                    AnimatedBuilder(
                      animation: _controller.animation!,
                      builder: (context, _) => RdSegmented<int>(
                        values: const [0, 1],
                        selected: _controller.index,
                        position: _controller.animation!.value,
                        labelOf: (i) => labels[i],
                        onChanged: _controller.animateTo,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: inCircle
                  ? TabBarView(controller: _controller, children: const [RdMeetingsTab(), RdTeamTasksTab()])
                  : const RdTeamTasksTab(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Topics of the Team area: suggestions and the Themenspeicher (leadership),
/// "Thema vorschlagen" and the own suggestions (members).
class RdTeamTopicsPage extends ConsumerStatefulWidget {
  const RdTeamTopicsPage({super.key});

  @override
  ConsumerState<RdTeamTopicsPage> createState() => _RdTeamTopicsPageState();
}

class _RdTeamTopicsPageState extends ConsumerState<RdTeamTopicsPage> with RouteReturnReload {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) reloadTeamOrgTab(ref, 'topics', firstLoad: true);
    });
  }

  @override
  void onRouteReturn() => reloadTeamOrgTab(ref, 'topics');

  @override
  Widget build(BuildContext context) {
    ref.watch(protocolTypesProvider);
    ref.watch(teamPersonProvider);
    final p = context.rd;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RdBackLink(label: l10n.rdTeamTitle, onTap: () => rdBack(context, '/settings/team-organization')),
                  const SizedBox(height: 8),
                  Text(
                    ref.watch(isTeamLeaderProvider) ? l10n.rdTeamOpenTopics : l10n.teamOrgSuggestTopic,
                    style: RdType.largeTitle(p),
                  ),
                ],
              ),
            ),
            const Expanded(child: RdOpenTopics()),
          ],
        ),
      ),
    );
  }
}
