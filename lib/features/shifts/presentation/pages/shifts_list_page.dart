import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/shift_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../../../../l10n/l10n.dart';

/// Shifts List Page
///
/// Shows all shift plans with CRUD capabilities.
class ShiftsListPage extends ConsumerStatefulWidget {
  const ShiftsListPage({super.key});

  @override
  ConsumerState<ShiftsListPage> createState() => _ShiftsListPageState();
}

class _ShiftsListPageState extends ConsumerState<ShiftsListPage> {
  @override
  Widget build(BuildContext context) {
    final shiftsAsync = ref.watch(shiftsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.shiftsPlans),
      ),
      body: Column(
        children: [
          // Info card explaining the feature
          _buildInfoCard(context),

          // Shifts list
          Expanded(
            child: shiftsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text(context.l10n.shiftsFlutterErrorWith(error))),
              data: (shifts) {
                if (shifts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.schedule_outlined,
                            size: 64, color: AppColors.medium),
                        const SizedBox(height: 16),
                        Text(context.l10n.shiftsNone),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showCreateDialog(context),
                          icon: const Icon(Icons.add),
                          label: Text(context.l10n.shiftsCreate),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: shifts.length,
                  itemBuilder: (context, index) {
                    final shift = shifts[index];
                    return _ShiftPlanTile(
                      // FN-005: Add key for proper widget identity
                      key: ValueKey(shift.id),
                      shift: shift,
                      onTap: () => _openShiftDetail(shift),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Card(
        color: AppColors.info.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.info),
              const SizedBox(width: AppDimensions.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.shiftsFlutterInfoTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: AppDimensions.paddingXS),
                    Text(
                      context.l10n.shiftsFlutterInfoText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.medium,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openShiftDetail(ShiftPlan shift) {
    if (shift.id != null) {
      context.push('/settings/shifts/${shift.id}');
    }
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    try {
      final result = await showDialog<Map<String, String>?>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.shiftsCreate),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.typeSettingsName,
                  hintText: context.l10n.shiftsFlutterNameHint,
                ),
                autofocus: true,
              ),
              const SizedBox(height: AppDimensions.paddingM),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: context.l10n.tasksDescriptionOptional,
                  hintText: context.l10n.shiftsFlutterDescriptionHint,
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () {
                // FN-002: Validate before submit
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.shiftsEnterName)),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'name': name,
                  'description': descriptionController.text,
                });
              },
              child: Text(context.l10n.filesCreate),
            ),
          ],
        ),
      );

      // RT-014: Safe access to dialog result
      final name = result?['name']?.trim() ?? '';
      if (name.isNotEmpty) {
        await _createShift(name, result?['description']?.trim() ?? '');
      }
    } finally {
      // FN-001: Dispose controllers
      nameController.dispose();
      descriptionController.dispose();
    }
  }

  Future<void> _createShift(String name, String description) async {
    final notifier = ref.read(shiftNotifierProvider.notifier);

    final plan = ShiftPlan(
      name: name,
      description: description,
    );

    final result = await notifier.createShift(plan);

    if (mounted) {
      if (result != null) {
        ToastHelper.showSuccess(context, context.l10n.shiftsFlutterCreated(name));
        // Navigate to detail page
        if (result.id != null) {
          context.push('/settings/shifts/${result.id}');
        }
      } else {
        final error = ref.read(shiftNotifierProvider);
        if (error.hasError) {
          ToastHelper.showError(context, context.l10n.shiftsFlutterCreateFailed('${error.error}'));
        }
      }
    }
  }
}

class _ShiftPlanTile extends StatelessWidget {
  final ShiftPlan shift;
  final VoidCallback? onTap;

  const _ShiftPlanTile({
    super.key,
    required this.shift,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.schedule,
          color: AppColors.primary,
        ),
      ),
      title: Text(shift.name),
      subtitle: Text(
        _getSubtitle(context.l10n),
        style: TextStyle(color: AppColors.medium, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.medium),
      onTap: onTap,
    );
  }

  String _getSubtitle(AppLocalizations l10n) {
    final parts = <String>[];

    if (shift.description.isNotEmpty) {
      parts.add(shift.description);
    }

    final cycleDays = shift.cycleLengthDays;
    if (cycleDays > 1) {
      parts.add(l10n.shiftsFlutterCycleDays(cycleDays));
    }

    if (shift.definition.isNotEmpty) {
      final segments = shift.definition.length;
      parts.add(l10n.shiftsFlutterSegments(segments));
    }

    return parts.isEmpty ? l10n.shiftsFlutterNoDefinition : parts.join(' • ');
  }
}
