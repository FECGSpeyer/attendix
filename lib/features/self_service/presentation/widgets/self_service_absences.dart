import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../people/presentation/widgets/planned_absences.dart';

/// Self-service block for planned absences and self pause
/// (Ionic signout page: absence tile, "Geplante Abwesenheiten", pause button).
///
/// - Planned absences: visible when `tenant_role_permissions.player_planned_absence`
///   is set for the user's role.
/// - Self pause: visible when `player_self_pause` is set for Role.player.
class SelfServiceAbsenceSection extends ConsumerStatefulWidget {
  const SelfServiceAbsenceSection({super.key});

  @override
  ConsumerState<SelfServiceAbsenceSection> createState() =>
      _SelfServiceAbsenceSectionState();
}

class _SelfServiceAbsenceSectionState
    extends ConsumerState<SelfServiceAbsenceSection> {
  bool _unpauseChecked = false;

  void _refreshAttendances() {
    ref.invalidate(allPersonAttendancesAcrossTenantsProvider);
    ref.invalidate(currentSelfServicePlayerProvider);
  }

  /// Ionic: when self pause is allowed, expired pauses are lifted on load.
  void _maybeCheckUnpause(bool canSelfPause) {
    if (!canSelfPause || _unpauseChecked) return;
    _unpauseChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = ref.read(playerRepositoryWithTenantProvider);
      await repo.checkAndUnpausePlayers();
      if (mounted) ref.invalidate(currentSelfServicePlayerProvider);
    });
  }

  Future<void> _reportAbsence(Person player, bool canSelfPause) async {
    final ok = await addPlannedAbsenceFlow(
      context,
      ref,
      personId: player.id!,
      showLongAbsenceHint: canSelfPause,
    );
    if (ok) _refreshAttendances();
  }

  Future<void> _pause(Person player) async {
    final result = await showModalBottomSheet<({String reason, DateTime? until})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _SelfPauseSheet(),
    );
    if (result == null || !mounted) return;

    final untilIso = result.until == null
        ? null
        : DateFormat('yyyy-MM-dd').format(result.until!);
    final pauseText = result.until == null
        ? result.reason
        : '${result.reason} (bis ${DateFormat('dd.MM.yyyy').format(result.until!)})';

    try {
      final repo = ref.read(playerRepositoryWithTenantProvider);
      await repo.pausePlayer(player, untilIso, pauseText);
      _refreshAttendances();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Fehler: $e');
    }
  }

  Future<void> _unpause(Person player) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Pausierung beenden',
      message: 'Möchtest du deine Pausierung wirklich beenden und wieder aktiv werden?',
      confirmText: 'Reaktivieren',
    );
    if (!confirmed || !mounted) return;
    try {
      final repo = ref.read(playerRepositoryWithTenantProvider);
      await repo.unpausePlayer(player, historyText: 'Selbst reaktiviert');
      _refreshAttendances();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Fehler: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(currentSelfServicePlayerProvider).valueOrNull;
    if (player?.id == null) return const SizedBox.shrink();

    final canSelfPause = ref.watch(canSelfPauseProvider);
    final canPlannedAbsence = ref.watch(canSelfReportAbsenceProvider);
    _maybeCheckUnpause(canSelfPause);

    if (!canSelfPause && !canPlannedAbsence) return const SizedBox.shrink();

    final absences = canPlannedAbsence
        ? ref.watch(playerAbsencesByPersonIdProvider(player!.id!)).valueOrNull ??
            const []
        : const [];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppDimensions.paddingS,
            runSpacing: AppDimensions.paddingS,
            children: [
              if (canPlannedAbsence)
                ActionChip(
                  avatar: const Icon(Icons.calendar_month, size: 18),
                  label: const Text('Abwesenheit melden'),
                  onPressed: () => _reportAbsence(player!, canSelfPause),
                ),
              if (canSelfPause && !player!.paused)
                ActionChip(
                  avatar: const Icon(Icons.pause_circle_outline, size: 18),
                  label: const Text('Pausieren'),
                  onPressed: () => _pause(player),
                ),
              if (canSelfPause && player!.paused)
                ActionChip(
                  avatar: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('Pausierung beenden'),
                  onPressed: () => _unpause(player),
                ),
            ],
          ),
          if (canPlannedAbsence && absences.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: AppDimensions.paddingS),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ListTile(
                    title: Text(
                      'Geplante Abwesenheiten',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (final absence in absences)
                    PlannedAbsenceTile(
                      absence: absence,
                      onDelete: () async {
                        final ok = await deletePlannedAbsenceFlow(
                          context,
                          ref,
                          absence,
                          selfService: true,
                        );
                        if (ok) _refreshAttendances();
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Pausieren" sheet: reason (required) + optional end date.
class _SelfPauseSheet extends StatefulWidget {
  const _SelfPauseSheet();

  @override
  State<_SelfPauseSheet> createState() => _SelfPauseSheetState();
}

class _SelfPauseSheetState extends State<_SelfPauseSheet> {
  final _reasonController = TextEditingController();
  DateTime? _until;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _until ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      locale: const Locale('de', 'DE'),
    );
    if (picked != null) setState(() => _until = picked);
  }

  void _confirm() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ToastHelper.showWarning(context, 'Bitte gib einen Grund an!');
      return;
    }
    Navigator.of(context).pop((reason: reason, until: _until));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: const Text('Pausieren'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: TextField(
                controller: _reasonController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Grund',
                  hintText: 'Warum möchtest du pausieren?',
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Pausiert bis (optional)'),
              subtitle: Text(_until != null
                  ? DateFormat('dd.MM.yyyy').format(_until!)
                  : 'Kein Enddatum gewählt'),
              trailing: _until != null
                  ? IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.medium),
                      onPressed: () => setState(() => _until = null),
                    )
                  : null,
              onTap: _pickDate,
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
                onPressed: _confirm,
                child: const Text('Pausieren bestätigen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
