import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/church/church.dart';
import '../../../../shared/widgets/display/avatar.dart';
import 'master_data_sheet.dart';
import 'profile_helpers.dart';

/// Profile card at the top of the "Mehr" tab (Ionic settings hero-card).
///
/// Shows Passbild, name, role and chips for birthday, phone and the extra
/// fields that are visible to players. Tapping opens "Meine Stammdaten".
/// Renders nothing when the user has no player profile in this tenant.
class ProfileHeroCard extends ConsumerWidget {
  const ProfileHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(ownProfileProvider).valueOrNull;
    if (profile == null) return const SizedBox.shrink();

    final person = profile.person;
    final role = ref.watch(currentRoleProvider);
    final visibleFields = ref.watch(visibleProfileExtraFieldsProvider);
    final hasChurchField = visibleFields.any((f) => f.type == 'bfecg_church');
    final churches = hasChurchField
        ? (ref.watch(churchesProvider).valueOrNull ?? const <Church>[])
        : const <Church>[];
    final theme = Theme.of(context);

    final chips = <Widget>[
      if ((person.birthday ?? '').isNotEmpty)
        _StatChip(
          icon: Icons.calendar_today_outlined,
          label: formatProfileDate(person.birthday),
        ),
      if ((person.phone ?? '').isNotEmpty)
        _StatChip(icon: Icons.phone_outlined, label: person.phone!),
      for (final field in visibleFields)
        _StatChip(
          icon: Icons.info_outline,
          label:
              '${field.name}: ${extraFieldDisplayValue(field, profile.additionalFields, churches)}',
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showMasterDataSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Avatar(
                      imageUrl:
                          hasCustomProfileImage(person.img) ? person.img : null,
                      firstName: person.firstName,
                      lastName: person.lastName,
                      size: 56,
                    ),
                    const SizedBox(width: AppDimensions.paddingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${person.firstName} ${person.lastName}'.trim(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (profileRoleName(role).isNotEmpty)
                            Text(
                              profileRoleName(role),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.medium,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.medium),
                  ],
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.paddingM),
                  Wrap(
                    spacing: AppDimensions.paddingS,
                    runSpacing: AppDimensions.paddingS,
                    children: chips,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
