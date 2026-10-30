import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../widgets/settings_list.dart';
import '../widgets/settings_sheet.dart';

/// Provider for left (archived) players using repository
final leftPlayersProvider = FutureProvider<List<Person>>((ref) async {
  final repository = ref.watch(playerRepositoryWithTenantProvider);
  if (!repository.hasTenantId) return [];
  return repository.getArchivedPlayers();
});

/// IOS_SETTINGS2: Ionic settings `trigger="archive-button"` sheet
/// (`[breakpoints]="[0, 0.5, 1]"`, initial 0.5, toolbar with the title).
Future<void> showArchiveSheet(BuildContext context) => showSettingsSheet<void>(
      context,
      initialBreakpoint: 0.5,
      builder: (_) => const LeftPlayersPage(sheet: true),
    );

/// Left Players Page - shows archived/former members
class LeftPlayersPage extends ConsumerWidget {
  const LeftPlayersPage({super.key, this.sheet = false});

  /// Presented as the Ionic sheet (no back button) instead of a route.
  final bool sheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(leftPlayersProvider);

    return Scaffold(
      // Ionic archive modal: plain `ion-content` (not "light").
      backgroundColor: sheet ? IonIos.itemBackground(context) : null,
      appBar: sheet
          ? settingsSheetBar(context, title: context.l10n.settingsArchive)
          : AppBar(
              title: Text(context.l10n.settingsArchive),
              leading: IconButton(
                icon: const BackButtonIcon(),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
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
                onPressed: () => ref.invalidate(leftPlayersProvider),
                child: IonButtonLabel(context.l10n.messagesRetry),
              ),
            ],
          ),
        ),
        data: (players) {
          // Ionic: one item with the centred grey "Keine archivierten
          // Personen" text when the archive is empty.
          if (players.isEmpty) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: Text(
                    context.l10n.settingsNoArchived,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.medium),
                  ),
                ),
              ],
            );
          }

          return RefreshIndicator.adaptive(
            // FN-010: await provider.future to show spinner until data loads
            onRefresh: () async {
              ref.invalidate(leftPlayersProvider);
              await ref.read(leftPlayersProvider.future);
            },
            // Ionic: plain `ion-list` (full width rows, no cards).
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: players.length,
              separatorBuilder: (context, _) => Divider(
                height: 0.5,
                thickness: 0.5,
                indent: IonIos.itemPaddingStart,
                color: ionIsIos(context) ? IonIos.line(context) : null,
              ),
              itemBuilder: (context, index) {
                final player = players[index];
                return _LeftPlayerItem(
                  player: player,
                  onReactivate: () => _reactivatePlayer(context, ref, player),
                  // P10_PEOPLE: the person page can reactivate (Ionic
                  // hasLeft modal) → reload the list afterwards.
                  onViewDetails: () async {
                    // Capture the container: the page may be disposed when
                    // the push returns (e.g. tab switch replaced the stack).
                    final container = ProviderScope.containerOf(context);
                    await context.push('/people/${player.id}');
                    container.invalidate(leftPlayersProvider);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _reactivatePlayer(BuildContext context, WidgetRef ref, Person player) async {
    final repository = ref.read(playerRepositoryWithTenantProvider);
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(ctx.l10n.peopleReactivateConfirm),
        content: Text(ctx.l10n.settingsFlutterReactivateMessage(player.fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.signoutReactivate),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await repository.reactivatePlayer(player);

        ref.invalidate(leftPlayersProvider);
        ref.invalidate(realtimePlayersProvider);
        ref.invalidate(playersProvider);

        if (context.mounted) {
          ToastHelper.showSuccess(context, context.l10n.settingsFlutterReactivated(player.fullName));
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(e)));
        }
      }
    }
  }
}

class _LeftPlayerItem extends StatelessWidget {
  const _LeftPlayerItem({
    required this.player,
    required this.onReactivate,
    required this.onViewDetails,
  });

  final Person player;
  final VoidCallback onReactivate;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    // IOS_SETTINGS2: Ionic `ion-item button`: h2 "Vorname Nachname (Gruppe)",
    // h3 "Ausgetreten am …". Flutter keeps the restore button at the end
    // because its person page has no "reaktivieren" for archived persons.
    final group = player.groupName;
    return ListTile(
      onTap: onViewDetails,
      title: Text(group == null ? player.fullName : '${player.fullName} ($group)'),
      subtitle: player.left == null
          ? null
          : Text(context.l10n.settingsLeftOn(_formatDate(player.left!))),
      trailing: IconButton(
        icon: const Icon(Icons.restore, color: AppColors.success),
        tooltip: context.l10n.signoutReactivate,
        onPressed: onReactivate,
      ),
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return DateFormat(dateFmt()).format(date);
  }
}
