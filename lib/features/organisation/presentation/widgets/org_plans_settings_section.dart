import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/theme/app_colors.dart';

/// "Planung" and "Organisation" sections of the settings page
/// (Ionic settings: Ablaufpläne, Ad-Hoc Ablaufplanung, Planvorlagen & Felder,
/// Organisation). Only for admins / responsibles.
class OrgPlansSettingsSection extends ConsumerWidget {
  const OrgPlansSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(effectiveRoleProvider);
    if (!(role.isAdmin || role.isResponsible)) return const SizedBox.shrink();
    final org = ref.watch(currentOrganisationProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(context, 'Planung', [
          _tile(Icons.list_alt, 'Ablaufpläne', () => context.push('/planning')),
          _tile(Icons.calendar_today_outlined, 'Ad-Hoc Ablaufplanung', () => context.push('/settings/planung')),
          if (org != null)
            _tile(Icons.description_outlined, 'Planvorlagen & Felder',
                () => context.push('/settings/org-settings/planning-templates')),
        ]),
        const SizedBox(height: AppDimensions.paddingM),
        _section(context, 'Organisation', [
          _tile(
            Icons.business_outlined,
            org?.name ?? 'Organisation',
            () => context.push('/settings/org-settings'),
            trailing: org == null ? const Text('Nicht verknüpft', style: TextStyle(color: AppColors.medium)) : null,
          ),
        ]),
        const SizedBox(height: AppDimensions.paddingM),
      ],
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingS,
              vertical: AppDimensions.paddingXS,
            ),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.medium,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Card(margin: EdgeInsets.zero, child: Column(children: children)),
        ],
      );

  Widget _tile(IconData icon, String title, VoidCallback onTap, {Widget? trailing}) => ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.medium),
        onTap: onTap,
      );
}
