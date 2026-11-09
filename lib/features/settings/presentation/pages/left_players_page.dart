import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../people/people_list_utils.dart' show sortPeopleByGroup;
import '../../../people/presentation/pages/person_detail_page.dart'
    show PersonModalResult, showPersonModal;
import '../widgets/settings_list.dart';
import '../widgets/settings_sheet.dart';

/// Provider for left (archived) players using repository
final leftPlayersProvider = FutureProvider<List<Person>>((ref) async {
  final repository = ref.watch(playerRepositoryWithTenantProvider);
  if (!repository.hasTenantId) return [];
  final players = await repository.getArchivedPlayers();
  // Ionic settings.page: leftPlayers = Utils.getModifiedPlayersForList
  // (group name for "Name (Gruppe)", sorted by group like the people list).
  final groups = await ref.watch(groupsProvider.future);
  final names = {for (final g in groups) g.id: g.name};
  return sortPeopleByGroup([
    for (final p in players)
      p.copyWith(groupName: p.instrument == null ? null : names[p.instrument]),
  ], groups);
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
              Icon(AppIcons.errorOutline, size: 64, color: AppColors.danger),
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
                  onReactivate: () => reactivateWithConfirmation(context, ref, player),
                  // Ionic openPlayerModal: PersonPage as a card modal
                  // (readOnly, hasLeft) above the sheet; reload the list
                  // only when the person was reactivated (`activated`).
                  onViewDetails: () async {
                    final id = player.id;
                    if (id == null) return;
                    // Capture the container: the sheet may be disposed when
                    // the modal returns.
                    final container = ProviderScope.containerOf(context);
                    final result = await showPersonModal(context, id);
                    if (result == PersonModalResult.activated) {
                      container.invalidate(leftPlayersProvider);
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Restores [player] after the confirmation (also the Beta page
  /// `RdArchivePage`).
  static Future<void> reactivateWithConfirmation(BuildContext context, WidgetRef ref, Person player) async {
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
        icon: Icon(AppIcons.restore, color: AppColors.success),
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
