import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import '../widgets/settings_list.dart';
import '../widgets/settings_sheet.dart'; // IOS_SETTINGS2

/// IOS_SETTINGS2: Ionic settings "pending-button" card opens the
/// "Ausstehende Personen" sheet (`[breakpoints]="[0, 1]"`, initial 1).
Future<void> showPendingPersonsSheet(BuildContext context) =>
    showSettingsSheet<void>(
      context,
      builder: (_) => const PendingPlayersPage(sheet: true),
    );

/// Pending persons (self-registrations awaiting approval).
///
/// IOS_SETTINGS2: layout of the Ionic sheet — `ion-content color="light"`,
/// toolbar with the title only and one inset list (h2 name, h3 e-mail).
/// Tapping a person opens the person page, which (like Ionic's
/// `openApprovePersonModal` → PersonPage `approveMode`) offers the
/// duplicate check and the approve / decline actions.
class PendingPlayersPage extends ConsumerWidget {
  const PendingPlayersPage({super.key, this.sheet = false});

  /// Presented as the Ionic sheet (no back button) instead of a route.
  final bool sheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(realtimePendingPlayersProvider);
    final title = context.l10n.settingsPendingPersons;

    return Scaffold(
      appBar: sheet
          ? settingsSheetBar(context, title: title)
          : AppBar(
              title: Text(title),
              leading: IconButton(
                icon: const BackButtonIcon(),
                onPressed: () => context.pop(),
              ),
            ),
      body: playersAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text(context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(e))),
              const SizedBox(height: AppDimensions.paddingM),
              ElevatedButton(
                onPressed: () => ref.invalidate(realtimePendingPlayersProvider),
                child: IonButtonLabel(context.l10n.messagesRetry),
              ),
            ],
          ),
        ),
        data: (players) {
          return RefreshIndicator.adaptive(
            onRefresh: () async {
              ref.invalidate(realtimePendingPlayersProvider);
              await ref.read(realtimePendingPlayersProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                  ionListMargin(context), AppDimensions.paddingM, ionListMargin(context), 32),
              children: [
                if (players.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingL),
                    child: Text(
                      context.l10n.settingsFlutterPendingEmpty,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.medium),
                    ),
                  )
                else
                  SettingsListSection(
                    icons: false,
                    children: [
                      for (final player in players)
                        _PendingPersonItem(player: player),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// `ion-item detail="false" button`: h2 name, h3 e-mail.
class _PendingPersonItem extends StatelessWidget {
  const _PendingPersonItem({required this.player});

  final Person player;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    final email = player.email ?? '';
    return ListTile(
      title: Text(player.fullName),
      subtitle: email.isEmpty
          ? null
          : Text(
              email,
              style: ios ? TextStyle(fontSize: 14, color: IonIos.text(context)) : null,
            ),
      onTap: player.id == null ? null : () => context.push('/people/${player.id}'),
    );
  }
}
