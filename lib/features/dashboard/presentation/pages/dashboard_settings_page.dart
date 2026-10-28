import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/dashboard/dashboard_models.dart';

/// Card labels (Ionic `CARD_LABELS`).
const Map<String, String> dashboardCardLabels = {
  DashboardCardIds.birthdays: 'Geburtstage',
  DashboardCardIds.nextEvent: 'Termine',
  DashboardCardIds.memberChanges: 'Mitglieder-Veränderungen',
  DashboardCardIds.absences: 'Abwesenheiten & Pausierungen',
  DashboardCardIds.criticalPersons: 'Problemfälle',
  DashboardCardIds.currentSongs: 'Aktuelle Werke',
  DashboardCardIds.currentPlan: 'Aktueller Ablaufplan',
  DashboardCardIds.myTasks: 'Meine Aufgaben',
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
      if (mounted) ToastHelper.showError(context, 'Fehler beim Speichern: $e');
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
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: _isReordering ? 'Fertig' : 'Reihenfolge ändern',
            icon: Icon(_isReordering ? Icons.check : Icons.reorder),
            onPressed: () => setState(() => _isReordering = !_isReordering),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _Header('Tab'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: SwitchListTile(
              title: const Text('Dashboard-Tab anzeigen'),
              value: settings.showTab,
              onChanged: (v) => _guard(() => notifier.setShowTab(v)),
            ),
          ),
          const SizedBox(height: 16),
          const _Header('Karten'),
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
                        title: Text(dashboardCardLabels[shown[i].id] ?? shown[i].id),
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
                  title: const Text('Zurücksetzen', style: TextStyle(color: AppColors.medium)),
                  onTap: () => _guard(notifier.resetCards),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'Tippe auf das Symbol oben rechts, um die Reihenfolge per Drag & Drop anzupassen.',
              style: TextStyle(fontSize: 13.5, color: AppColors.medium),
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
