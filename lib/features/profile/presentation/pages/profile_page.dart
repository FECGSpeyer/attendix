import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../widgets/account_dialogs.dart';
import '../widgets/master_data_sheet.dart';
import '../widgets/profile_helpers.dart';
import '../widgets/profile_hero_card.dart';

/// Profile page: own master data, account security and app preferences.
///
/// Master data editing follows the Ionic settings "Meine Stammdaten" modal.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(currentTenantProvider);
    final role = ref.watch(currentRoleProvider);
    final profileAsync = ref.watch(ownProfileProvider);
    final email =
        ref.watch(supabaseClientProvider).auth.currentUser?.email ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ownProfileProvider);
          ref.invalidate(personExtraFieldsProvider);
          await ref.read(ownProfileProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          children: [
            const ProfileHeroCard(),
            if (profileAsync.isLoading)
              const Padding(
                padding: EdgeInsets.all(AppDimensions.paddingL),
                child: Center(child: CircularProgressIndicator()),
              ),
            _Section(
              title: 'Konto',
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined,
                      color: AppColors.primary),
                  title: const Text('E-Mail'),
                  subtitle: Text(email),
                ),
                if (tenant != null)
                  ListTile(
                    leading: const Icon(Icons.groups_outlined,
                        color: AppColors.primary),
                    title: Text(tenant.longName.isNotEmpty
                        ? tenant.longName
                        : tenant.shortName),
                    subtitle: Text(profileRoleName(role)),
                  ),
                if (profileAsync.valueOrNull != null)
                  ListTile(
                    leading: const Icon(Icons.badge_outlined,
                        color: AppColors.primary),
                    title: const Text('Meine Stammdaten'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showMasterDataSheet(context),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),
            _Section(
              title: 'Sicherheit',
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.key_outlined, color: AppColors.primary),
                  title: const Text('Passwort ändern'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showChangePasswordDialog(context),
                ),
                ListTile(
                  leading: const Icon(Icons.alternate_email,
                      color: AppColors.primary),
                  title: const Text('E-Mail ändern'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showChangeEmailDialog(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),
            _Section(
              title: 'App-Einstellungen',
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined,
                      color: AppColors.primary),
                  title: const Text('Benachrichtigungen'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/notifications'),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final prefs = ref.watch(userPreferencesProvider);
                    return SwitchListTile(
                      secondary: const Icon(Icons.swap_horiz),
                      title: const Text('Gruppenauswahl beim Start'),
                      subtitle: const Text(
                        'Immer beim Öffnen der App nach der Gruppe fragen',
                      ),
                      value: prefs.wantInstanceSelection,
                      onChanged: (value) async {
                        try {
                          await ref
                              .read(userPreferencesNotifierProvider.notifier)
                              .updatePreferences(wantInstanceSelection: value);
                          if (context.mounted) {
                            ToastHelper.showSuccess(
                              context,
                              value
                                  ? 'Gruppenauswahl aktiviert'
                                  : 'Gruppenauswahl deaktiviert',
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ToastHelper.showError(
                              context,
                              'Einstellung konnte nicht gespeichert werden',
                            );
                          }
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}
