import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/shift_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../core/utils/demo_guard.dart';

/// Sheet for copying a shift plan to another tenant
class CopyShiftToTenantSheet extends ConsumerStatefulWidget {
  final ShiftPlan shift;

  const CopyShiftToTenantSheet({super.key, required this.shift});

  @override
  ConsumerState<CopyShiftToTenantSheet> createState() =>
      _CopyShiftToTenantSheetState();
}

class _CopyShiftToTenantSheetState
    extends ConsumerState<CopyShiftToTenantSheet> {
  int? _targetTenantId;
  bool _copyAssignments = false;
  bool _isCopying = false;
  String _progressMessage = '';
  int _playersWithShift = 0;

  @override
  void initState() {
    super.initState();
    _loadPlayersWithShift();
  }

  Future<void> _loadPlayersWithShift() async {
    final count = await ref
        .read(shiftUsageCountProvider(widget.shift.id ?? '').future);
    if (mounted) {
      setState(() => _playersWithShift = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(userTenantsProvider);
    final currentTenantId = ref.watch(currentTenantIdProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            AppBar(
              title: const Text('Schichtplan kopieren'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              automaticallyImplyLeading: false,
            ),

            // Content
            Expanded(
              child: tenantsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Fehler: $e')),
                data: (tenants) {
                  final otherTenants = tenants
                      .where((t) => t.id != currentTenantId)
                      .toList();

                  if (otherTenants.isEmpty) {
                    return const Center(
                      child: Text('Keine anderen Instanzen verfügbar'),
                    );
                  }

                  _targetTenantId ??= otherTenants.first.id;

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Target tenant dropdown
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ziel-Instanz',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.medium,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: _targetTenantId,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.business),
                                ),
                                items: otherTenants
                                    .map((t) => DropdownMenuItem(
                                          value: t.id,
                                          child: Text(t.longName),
                                        ))
                                    .toList(),
                                onChanged: _isCopying
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(
                                              () => _targetTenantId = value);
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Copy assignments option (if players assigned)
                      if (_playersWithShift > 0) ...[
                        Card(
                          child: SwitchListTile(
                            title: const Text('Zuweisungen kopieren'),
                            subtitle: Text(
                              '$_playersWithShift ${_playersWithShift == 1 ? 'Person nutzt' : 'Personen nutzen'} diesen Schichtplan. '
                              'Versuche passende Personen in der Ziel-Instanz zuzuweisen.',
                            ),
                            value: _copyAssignments,
                            onChanged: _isCopying
                                ? null
                                : (value) {
                                    setState(() => _copyAssignments = value);
                                  },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Info card
                      Card(
                        color: AppColors.info.withAlpha(20),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: AppColors.info),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Hinweis',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.info,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Der Schichtplan "${widget.shift.name}" wird in die ausgewählte Instanz kopiert. '
                                'Die Definition und feste Schichten werden übernommen.'
                                '${_copyAssignments ? ' Zuweisungen werden anhand der App-ID (appId) der Personen gemappt.' : ''}',
                                style: const TextStyle(color: AppColors.medium),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Shift preview
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Wird kopiert:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.medium,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                icon: Icons.schedule,
                                label: 'Schichtplan',
                                value: widget.shift.name,
                              ),
                              if (widget.shift.description.isNotEmpty)
                                _InfoRow(
                                  icon: Icons.description,
                                  label: 'Beschreibung',
                                  value: widget.shift.description,
                                ),
                              _InfoRow(
                                icon: Icons.timeline,
                                label: 'Definition',
                                value:
                                    '${widget.shift.definition.length} Segment${widget.shift.definition.length != 1 ? 'e' : ''}',
                              ),
                              if (widget.shift.shifts.isNotEmpty)
                                _InfoRow(
                                  icon: Icons.calendar_today,
                                  label: 'Feste Schichten',
                                  value:
                                      '${widget.shift.shifts.length} Schicht${widget.shift.shifts.length != 1 ? 'en' : ''}',
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Progress indicator
                      if (_isCopying) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            _progressMessage,
                            style: const TextStyle(color: AppColors.medium),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Copy button
                      ElevatedButton.icon(
                        onPressed: _isCopying ? null : _copyShift,
                        icon: _isCopying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.copy),
                        label:
                            Text(_isCopying ? 'Wird kopiert...' : 'Kopieren'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _copyShift() async {
    if (_targetTenantId == null) return;
    if (DemoGuard.blocked()) return; // DEMO_GUARD

    setState(() {
      _isCopying = true;
      _progressMessage = 'Schichtplan wird kopiert...';
    });

    try {
      final supabase = ref.read(supabaseClientProvider);

      // Create a clean copy without IDs
      final copiedShift = {
        'name': '${widget.shift.name} (Kopie)',
        'description': widget.shift.description,
        'tenant_id': _targetTenantId,
        'definition': widget.shift.definition
            .map((def) => {
                  'start_time': def.startTime,
                  'duration': def.duration,
                  'free': def.free,
                  'index': def.index,
                  'repeat_count': def.repeatCount,
                })
            .toList(),
        'shifts': widget.shift.shifts
            .map((s) => {
                  'name': s.name,
                  'date': s.date,
                })
            .toList(),
      };

      setState(() => _progressMessage = 'Erstelle Schichtplan...');

      // Insert the shift
      final insertResponse = await supabase
          .from('shifts')
          .insert(copiedShift)
          .select()
          .single();

      final newShiftId = insertResponse['id'] as String;

      int assignedCount = 0;

      // Copy assignments if requested
      if (_copyAssignments && _playersWithShift > 0) {
        setState(
            () => _progressMessage = 'Suche passende Personen in Ziel-Instanz...');

        final currentTenantId = ref.read(currentTenantIdProvider);

        // Get players with this shift in source tenant
        final playersResponse = await supabase
            .from('player')
            .select('id, appId, shift_id, shift_name, shift_start')
            .eq('tenantId', currentTenantId!)
            .eq('shift_id', widget.shift.id!);

        final playersWithShift = playersResponse as List;

        if (playersWithShift.isNotEmpty) {
          // Get appIds of players with this shift
          final appIds = playersWithShift
              .map((p) => p['appId'] as String?)
              .where((id) => id != null && id.isNotEmpty)
              .toList();

          if (appIds.isNotEmpty) {
            setState(() => _progressMessage =
                'Weise ${appIds.length} Personen zu...');

            // Find matching players in target tenant by appId
            final targetPlayersResponse = await supabase
                .from('player')
                .select('id, appId')
                .eq('tenantId', _targetTenantId!)
                .inFilter('appId', appIds);

            final targetPlayers = targetPlayersResponse as List;

            // Create mapping: appId -> target player id
            final appIdToTargetId = <String, int>{};
            for (final player in targetPlayers) {
              final appId = player['appId'] as String?;
              if (appId != null) {
                appIdToTargetId[appId] = player['id'] as int;
              }
            }

            // Update target players with shift assignment
            for (final sourcePlayer in playersWithShift) {
              final appId = sourcePlayer['appId'] as String?;
              if (appId != null && appIdToTargetId.containsKey(appId)) {
                final targetPlayerId = appIdToTargetId[appId]!;

                await supabase.from('player').update({
                  'shift_id': newShiftId,
                  'shift_name': sourcePlayer['shift_name'],
                  'shift_start': sourcePlayer['shift_start'],
                }).eq('id', targetPlayerId).eq('tenantId', _targetTenantId!);

                assignedCount++;
              }
            }
          }
        }
      }

      if (mounted) {
        final tenants = await ref.read(userTenantsProvider.future);
        final targetTenant = tenants.firstWhere(
          (t) => t.id == _targetTenantId,
          orElse: () => const Tenant(shortName: '', longName: 'Ziel-Instanz'),
        );

        String message;
        if (_copyAssignments && assignedCount > 0) {
          message =
              'Schichtplan nach "${targetTenant.longName}" kopiert und $assignedCount ${assignedCount == 1 ? 'Person' : 'Personen'} zugewiesen.';
        } else if (_copyAssignments && assignedCount == 0 && _playersWithShift > 0) {
          message =
              'Schichtplan nach "${targetTenant.longName}" kopiert. Keine passenden Personen in Ziel-Instanz gefunden.';
        } else {
          message = 'Schichtplan nach "${targetTenant.longName}" kopiert.';
        }

        // Fix RT-005: Check mounted again after await before using context
        if (mounted) {
          ToastHelper.showSuccess(context, message);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler beim Kopieren: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCopying = false);
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.medium),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: AppColors.medium),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
