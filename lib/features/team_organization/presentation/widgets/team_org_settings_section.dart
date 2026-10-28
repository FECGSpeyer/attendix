import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/app_colors.dart';

/// Menu group "Planung" in the settings (replaces the old "Besprechungen").
/// Leadership gets "Teamorganisation"; members get direct entries for their
/// tasks and, when they belong to the circle, topics and protocols.
class TeamOrgSettingsSection extends ConsumerWidget {
  const TeamOrgSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(teamOrgEnabledProvider)) return const SizedBox.shrink();
    final isLeader = ref.watch(isTeamLeaderProvider);
    final inCircle = ref.watch(inTeamCircleProvider);
    final hasTasks = !isLeader && (ref.watch(myTasksProvider).valueOrNull?.isNotEmpty ?? false);
    if (!isLeader && !inCircle && !hasTasks) return const SizedBox.shrink();

    Widget tile(IconData icon, String title, String subtitle, String tab) => ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/team-organization?tab=$tab'),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingS, vertical: 4),
            child: Text(
              'Planung',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.medium,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                if (isLeader)
                  tile(Icons.groups_outlined, 'Teamorganisation', 'Aufgaben, Themen und Protokolle', 'tasks')
                else ...[
                  tile(Icons.check_box_outlined, 'Meine Aufgaben', 'Aufgaben, die dir zugewiesen sind', 'tasks'),
                  if (inCircle) ...[
                    tile(Icons.lightbulb_outline, 'Thema vorschlagen', 'Themen für die nächste Sitzung', 'topics'),
                    tile(Icons.description_outlined, 'Protokolle', 'Freigegebene Protokolle lesen', 'protocols'),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
