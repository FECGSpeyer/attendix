import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/dashboard/dashboard_models.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';

/// Card labels (Ionic `CARD_LABELS`).
Map<String, String> dashboardCardLabels(AppLocalizations l10n) => {
      DashboardCardIds.birthdays: l10n.homeDashboardBirthdays,
      DashboardCardIds.nextEvent: l10n.homeDashboardEvents,
      DashboardCardIds.memberChanges: l10n.homeDashboardMemberChanges,
      DashboardCardIds.absences: l10n.homeDashboardAbsences,
      DashboardCardIds.criticalPersons: l10n.homeDashboardProblemCases,
      DashboardCardIds.currentSongs: l10n.homeDashboardCurrentSongs,
      DashboardCardIds.currentPlan: l10n.homeDashboardCurrentPlan,
      DashboardCardIds.myTasks: l10n.tasksMyTasks,
    };

/// Dashboard settings (Ionic `settings/dashboard`): tab toggle, card
/// visibility and order. Stored per tenant in Supabase user_metadata.
class DashboardSettingsPage extends ConsumerStatefulWidget {
  const DashboardSettingsPage({super.key});

  @override
  ConsumerState<DashboardSettingsPage> createState() => _DashboardSettingsPageState();
}

class _DashboardSettingsPageState extends ConsumerState<DashboardSettingsPage> {
  bool _isReordering = false;

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.dashSettingsFlutterSaveFailed(friendlyErrorMessage(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(dashboardSettingsNotifierProvider);
    final notifier = ref.read(dashboardSettingsNotifierProvider.notifier);
    final teamOrg = ref.watch(dashboardTeamOrgEnabledProvider);
    final shown = configurableDashboardCards(settings.cards, teamOrgEnabled: teamOrg);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tabsDashboard),
        actions: [
          IconButton(
            tooltip: _isReordering
                ? context.l10n.personDone
                : context.l10n.dashSettingsFlutterReorder,
            icon: Icon(_isReordering ? Icons.check : Icons.reorder),
            onPressed: () => setState(() => _isReordering = !_isReordering),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _Header(context.l10n.dashSettingsTab),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: SwitchListTile(
              title: Text(context.l10n.dashSettingsShowTab),
              value: settings.showTab,
              onChanged: (v) => _guard(() => notifier.setShowTab(v)),
            ),
          ),
          const SizedBox(height: 16),
          _Header(context.l10n.dashSettingsCards),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: (from, to) =>
                      _guard(() => notifier.reorder(from, to, teamOrgEnabled: teamOrg)),
                  children: [
                    for (var i = 0; i < shown.length; i++)
                      ListTile(
                        key: ValueKey(shown[i].id),
                        leading: _isReordering
                            ? ReorderableDragStartListener(
                                index: i,
                                child: const Icon(Icons.drag_handle),
                              )
                            : null,
                        title: Text(dashboardCardLabels(context.l10n)[shown[i].id] ?? shown[i].id),
                        trailing: Switch(
                          value: shown[i].visible,
                          onChanged: _isReordering
                              ? null
                              : (v) => _guard(() => notifier.setCardVisible(shown[i].id, v)),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.refresh, color: AppColors.medium),
                  title: Text(context.l10n.dashSettingsReset, style: const TextStyle(color: AppColors.medium)),
                  onTap: () => _guard(notifier.resetCards),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              context.l10n.dashSettingsReorderHint,
              style: const TextStyle(fontSize: 13.5, color: AppColors.medium),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.medium,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
}
