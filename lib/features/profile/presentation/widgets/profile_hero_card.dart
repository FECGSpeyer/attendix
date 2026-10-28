import 'package:flutter/cupertino.dart';
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

    // UX_SETTINGS (WAVE 8): settings.page.scss .hero-card — margin
    // 12 16 8 (page padding supplies top/sides), radius 16, padding 16,
    // 52pt avatar, 1.15rem bold name, 0.85rem medium role, medium chevron.
    final ios = theme.platform == TargetPlatform.iOS;
    return Padding(
      padding: EdgeInsets.only(bottom: ios ? 8 : AppDimensions.paddingM),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: ios
            // IOS_R4: .hero-card background --ion-item-background (#000)
            ? (theme.brightness == Brightness.dark ? AppColors.iosInsetItemDark : Colors.white)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      size: 52,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${person.firstName} ${person.lastName}'.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18.4,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (profileRoleName(role).isNotEmpty)
                            Text(
                              profileRoleName(role),
                              style: const TextStyle(
                                fontSize: 13.6,
                                color: AppColors.medium,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      ios ? CupertinoIcons.chevron_forward : Icons.chevron_right,
                      size: ios ? 17.6 : null,
                      color: AppColors.medium,
                    ),
                  ],
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
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
      // .stat-chip: radius 8, padding 4/8, 0.8rem, primary 10 % background,
      // 0.9rem icon in primary-shade, gap 5.
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.4, color: AppColors.primaryDark),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.8,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
