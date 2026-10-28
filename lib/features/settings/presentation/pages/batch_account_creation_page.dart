import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../core/providers/user_registration_providers.dart'; // AUTH
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';

/// Page for batch creating accounts for players without accounts
class BatchAccountCreationPage extends ConsumerStatefulWidget {
  const BatchAccountCreationPage({super.key});

  @override
  ConsumerState<BatchAccountCreationPage> createState() =>
      _BatchAccountCreationPageState();
}

class _BatchAccountCreationPageState
    extends ConsumerState<BatchAccountCreationPage> {
  bool _isRunning = false;
  int _processed = 0;
  int _total = 0;
  int _succeeded = 0;
  int _failed = 0;
  final List<String> _errors = [];

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsFlutterBatchTitle),
      ),
      body: playersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(e)))),
        data: (players) {
          // Ionic getPlayersWithoutAccount: not pending, not left, e-mail, no appId
          final eligible = players
              .where((p) =>
                  (p.appId == null || p.appId!.isEmpty) &&
                  !p.pending &&
                  p.left == null &&
                  p.email != null &&
                  p.email!.trim().isNotEmpty)
              .toList();

          final noEmail = players
              .where((p) =>
                  (p.appId == null || p.appId!.isEmpty) &&
                  (p.email == null || p.email!.isEmpty))
              .toList();

          final withAccount = players
              .where((p) => p.appId != null && p.appId!.isNotEmpty)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            children: [
              // Summary card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.messagesOverview,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 12),
                      _SummaryRow(
                        icon: Icons.check_circle,
                        color: AppColors.success,
                        label: context.l10n.settingsFlutterBatchWithAccount,
                        count: withAccount.length,
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        icon: Icons.person_add,
                        color: AppColors.primary,
                        label: context.l10n.settingsFlutterBatchEligible,
                        count: eligible.length,
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        icon: Icons.warning,
                        color: AppColors.warning,
                        label: context.l10n.settingsFlutterBatchNoEmail,
                        count: noEmail.length,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Progress indicator when running
              if (_isRunning) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingM),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _total > 0 ? _processed / _total : 0,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.settingsFlutterBatchProcessed(_processed, _total),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (_succeeded > 0 || _failed > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, color: AppColors.success, size: 16),
                              const SizedBox(width: 4),
                              Text(context.l10n.settingsFlutterBatchSucceeded(_succeeded)),
                              const SizedBox(width: 16),
                              Icon(Icons.close, color: AppColors.danger, size: 16),
                              const SizedBox(width: 4),
                              Text(context.l10n.settingsFlutterBatchFailed(_failed)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Results after completion
              if (!_isRunning && _errors.isNotEmpty) ...[
                Card(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.commonError,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...(_errors.map((e) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 4),
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Eligible players list
              if (eligible.isNotEmpty) ...[
                Text(
                  context.l10n.settingsFlutterBatchEligibleList(eligible.length),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: eligible.asMap().entries.map((entry) {
                      final index = entry.key;
                      final player = entry.value;
                      return Column(
                        children: [
                          if (index > 0) const Divider(height: 1),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.1),
                              child: Text(
                                _getInitials(player),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              '${player.firstName} ${player.lastName}',
                            ),
                            subtitle: Text(
                              player.email ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Start button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRunning
                        ? null
                        : () => _confirmAndCreateAccounts(eligible),
                    icon: const Icon(Icons.person_add),
                    label: Text(
                        context.l10n.settingsFlutterBatchCreateButton(eligible.length)),
                  ),
                ),
              ],

              if (eligible.isEmpty && !_isRunning) ...[
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 64, color: AppColors.success),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.settingsFlutterBatchAllHaveAccount,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.medium),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _getInitials(Person player) {
    final first = player.firstName.isNotEmpty ? player.firstName[0] : '';
    final last = player.lastName.isNotEmpty ? player.lastName[0] : '';
    return '$first$last'.toUpperCase();
  }

  /// Ionic settings showAlertForAccountsCreation(): confirm listing all names.
  Future<void> _confirmAndCreateAccounts(List<Person> players) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.settingsCreateAccounts,
      message: context.l10n.settingsCreateAccountsMessage(
          players.map((p) => '${p.firstName} ${p.lastName}').join(', ')),
      confirmText: context.l10n.settingsContinue,
      cancelText: context.l10n.commonCancel,
    );

    if (!confirmed || !mounted) return;
    await _createAccounts(players);
  }

  /// AUTH: server-side account creation (attendix-user Edge Function).
  Future<void> _createAccounts(List<Person> players) async {
    setState(() {
      _isRunning = true;
      _processed = 0;
      _total = players.length;
      _succeeded = 0;
      _failed = 0;
      _errors.clear();
    });

    final result = await ref
        .read(accountCreationNotifierProvider.notifier)
        .createAccounts(players, onProgress: (done, _) {
      if (mounted) setState(() => _processed = done);
    });

    if (mounted) {
      setState(() {
        _isRunning = false;
        _succeeded = result.created;
        _failed = result.errors.length;
        _errors.addAll(result.errors);
      });
      if (!result.hasErrors) {
        ToastHelper.showSuccess(
            context, context.l10n.settingsAccountsCreated);
      } else {
        ToastHelper.showError(context,
            context.l10n.settingsCreateAccountsFailed(result.errors.first));
      }
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;

  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(
          '$count',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
