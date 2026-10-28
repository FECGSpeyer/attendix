import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/shift_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/shift_utils.dart'; // DB_REVIEW_REST
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

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
              title: Text(context.l10n.shiftsCopyToTenant),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              automaticallyImplyLeading: false,
            ),

            // Content
            Expanded(
              child: tenantsAsync.when(
                loading: () => const Center(child: AppSpinner()),
                error: (e, _) => Center(child: Text(context.l10n.shiftsFlutterErrorWith(friendlyErrorMessage(e)))),
                data: (tenants) {
                  final otherTenants = tenants
                      .where((t) => t.id != currentTenantId)
                      .toList();

                  if (otherTenants.isEmpty) {
                    return Center(
                      child: Text(context.l10n.shiftsNoOtherTenants),
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
                              Text(
                                context.l10n.shiftsFlutterTargetTenant,
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
                          child: SwitchListTile.adaptive(
                            title: Text(context.l10n.shiftsFlutterCopyAssignments),
                            subtitle: Text(
                              context.l10n.shiftsFlutterCopyAssignmentsHint(_playersWithShift),
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
                                    context.l10n.shiftsFlutterNote,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.info,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${context.l10n.shiftsFlutterCopyInfo(widget.shift.name)}'
                                '${_copyAssignments ? ' ${context.l10n.shiftsFlutterCopyInfoAssignments}' : ''}',
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
                              Text(
                                context.l10n.shiftsFlutterWillCopy,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.medium,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                icon: Icons.schedule,
                                label: context.l10n.shiftsFlutterPlan,
                                value: widget.shift.name,
                              ),
                              if (widget.shift.description.isNotEmpty)
                                _InfoRow(
                                  icon: Icons.description,
                                  label: context.l10n.tasksDescription,
                                  value: widget.shift.description,
                                ),
                              _InfoRow(
                                icon: Icons.timeline,
                                label: context.l10n.shiftsDefinition,
                                value:
                                    context.l10n.shiftsFlutterSegments(widget.shift.definition.length),
                              ),
                              if (widget.shift.shifts.isNotEmpty)
                                _InfoRow(
                                  icon: Icons.calendar_today,
                                  label: context.l10n.shiftsFlutterFixedShifts,
                                  value:
                                      context.l10n.shiftsFlutterShiftsCount(widget.shift.shifts.length),
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
                                    AppSpinner(strokeWidth: 2),
                              )
                            : const Icon(Icons.copy),
                        label:
                            Text(_isCopying ? context.l10n.shiftsFlutterCopyingShort : context.l10n.songsCopy),
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
    final l10n = context.l10n;

    setState(() {
      _isCopying = true;
      _progressMessage = l10n.shiftsCopying;
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

      setState(() => _progressMessage = l10n.shiftsFlutterCreatingPlan);

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
            () => _progressMessage = l10n.shiftsFlutterSearchingPeople);

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
                l10n.shiftsFlutterAssigningPeople(appIds.length));

            // Find matching players in target tenant by appId
            // DB_REVIEW_REST (M5): only active people (Ionic `.is('left', null)`).
            final targetPlayersResponse = await supabase
                .from('player')
                .select('id, appId')
                .eq('tenantId', _targetTenantId!)
                .inFilter('appId', appIds)
                .isFilter('left', null);

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
            final shiftDataByPersonId =
                <int, ({String? shiftName, String? shiftStart})>{};
            for (final sourcePlayer in playersWithShift) {
              final appId = sourcePlayer['appId'] as String?;
              if (appId != null && appIdToTargetId.containsKey(appId)) {
                final targetPlayerId = appIdToTargetId[appId]!;
                final shiftName = _emptyToNull(sourcePlayer['shift_name']);
                final shiftStart = _emptyToNull(sourcePlayer['shift_start']);

                await supabase.from('player').update({
                  'shift_id': newShiftId,
                  'shift_name': shiftName,
                  'shift_start': shiftStart,
                }).eq('id', targetPlayerId).eq('tenantId', _targetTenantId!);

                shiftDataByPersonId[targetPlayerId] =
                    (shiftName: shiftName, shiftStart: shiftStart);
                assignedCount++;
              }
            }

            // DB_REVIEW_REST (M5): Ionic updateShiftAttendancesInTenant –
            // excuse upcoming Termine that collide with the copied shift.
            if (shiftDataByPersonId.isNotEmpty) {
              await _updateShiftAttendancesInTenant(
                supabase,
                ShiftPlan.fromJson(insertResponse),
                shiftDataByPersonId,
              );
            }
          }
        }
      }

      if (mounted) {
        final tenants = await ref.read(userTenantsProvider.future);
        final targetTenant = tenants.firstWhere(
          (t) => t.id == _targetTenantId,
          orElse: () => Tenant(shortName: '', longName: l10n.shiftsFlutterTargetTenant),
        );

        String message;
        if (_copyAssignments && assignedCount > 0) {
          message =
              l10n.shiftsCopiedAssigned(targetTenant.longName, assignedCount);
        } else if (_copyAssignments && assignedCount == 0 && _playersWithShift > 0) {
          message =
              l10n.shiftsCopiedNoMatch(targetTenant.longName);
        } else {
          message = l10n.shiftsCopied(targetTenant.longName);
        }

        // Fix RT-005: Check mounted again after await before using context
        if (mounted) {
          ToastHelper.showSuccess(context, message);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, l10n.shiftsFlutterCopyFailedWith(friendlyErrorMessage(e)));
      }
    } finally {
      if (mounted) {
        setState(() => _isCopying = false);
      }
    }
  }

  static String? _emptyToNull(dynamic value) {
    final s = value?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  /// DB_REVIEW_REST (M5): Ionic ShiftService.updateShiftAttendancesInTenant.
  /// All reads are scoped to the target tenant; person_attendances has no
  /// tenant column, so it is filtered through the attendance join.
  Future<void> _updateShiftAttendancesInTenant(
    SupabaseClient supabase,
    ShiftPlan shift,
    Map<int, ({String? shiftName, String? shiftStart})> shiftDataByPersonId,
  ) async {
    final targetTenantId = _targetTenantId!;
    final types = await supabase
        .from('attendance_types')
        .select('id, all_day, start_time, end_time, default_status')
        .eq('tenant_id', targetTenantId);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final upcoming = await supabase
        .from('attendance')
        .select('id, date, type_id, start_time, end_time')
        .eq('tenantId', targetTenantId)
        .gte('date', today);
    if ((upcoming as List).isEmpty) return;

    final personAttendances = await supabase
        .from('person_attendances')
        .select(
            'id, person_id, attendance_id, status, attendance:attendance_id!inner(tenantId)')
        .inFilter('person_id', shiftDataByPersonId.keys.toList())
        .inFilter('attendance_id', upcoming.map((a) => a['id']).toList())
        .eq('attendance.tenantId', targetTenantId);

    final updates = ShiftUtils.copiedShiftAttendanceUpdates(
      shift: shift,
      attendances: upcoming.cast<Map<String, dynamic>>(),
      types: (types as List).cast<Map<String, dynamic>>(),
      personAttendances: (personAttendances as List).cast<Map<String, dynamic>>(),
      shiftDataByPersonId: shiftDataByPersonId,
    );
    for (final u in updates) {
      await supabase
          .from('person_attendances')
          .update({'status': u.status.value, 'notes': u.notes})
          .eq('id', u.id);
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
