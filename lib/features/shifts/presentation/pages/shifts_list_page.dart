import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/shift_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2

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

    // Ionic: light toolbar with arrow-back, collapse="condense" large title,
    // intro ion-card, inset list "Pläne", FAB opening the create sheet.
    return IonCondenseScaffold(
      title: context.l10n.shiftsPlans,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: context.l10n.commonBack,
        onPressed: () => context.pop(),
      ),
      floatingActionButton: TabBarFab.wrap(FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      )),
      bodyBuilder: (context, largeTitle) => ListView(
        padding: EdgeInsets.only(bottom: scrollEndPadding(context, base: 16, fabRoom: 80)),
        children: [
          if (largeTitle != null) largeTitle,
          _buildInfoCard(context),
          shiftsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: AppSpinner()),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.l10n.shiftsFlutterErrorWith(friendlyErrorMessage(error))),
            ),
            data: (shifts) => IonInsetList(
              header: context.l10n.shiftsPlans,
              children: shifts.isEmpty
                  ? [ListTile(title: Text(context.l10n.shiftsNone))]
                  : [
                      for (final shift in shifts)
                        _ShiftPlanTile(
                          // FN-005: Add key for proper widget identity
                          key: ValueKey(shift.id),
                          shift: shift,
                          onTap: () => _openShiftDetail(shift),
                        ),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  /// Ionic intro `ion-card`: centered time icon (4rem) and centered text with
  /// the warning line.
  Widget _buildInfoCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          children: [
            const Icon(Icons.schedule, size: 64, color: AppColors.medium),
            const SizedBox(height: 16),
            Text(
              context.l10n.shiftsIntro,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.medium),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.shiftsImportant,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.warning),
            ),
          ],
        ),
      ),
    );
  }

  void _openShiftDetail(ShiftPlan shift) {
    if (shift.id != null) {
      context.push('/settings/shifts/${shift.id}');
    }
  }

  /// Ionic: ion-modal sheet (breakpoint 0.7) "Schichtplan erstellen" with
  /// stacked name/description inputs and a block "Erstellen" button.
  Future<void> _showCreateDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    try {
      final result = await showModalBottomSheet<Map<String, String>?>(
        context: context,
        useRootNavigator: true, // IOS_SHELL2: above the tab bar
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: FractionallySizedBox(
            heightFactor: 0.7,
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  primary: false,
                  title: Text(sheetContext.l10n.shiftsCreate),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      IonInsetList(
                        children: [
                          IonStackedInput(
                            controller: nameController,
                            label: sheetContext.l10n.typeSettingsName,
                            autofocus: true,
                          ),
                          IonStackedInput(
                            controller: descriptionController,
                            label: sheetContext.l10n.tasksDescription,
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, {
                            'name': nameController.text,
                            'description': descriptionController.text,
                          }),
                          child: Text(sheetContext.l10n.filesCreate),
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

      if (result == null || !context.mounted) return;
      // Ionic: dismiss first, then validate with a danger toast.
      final name = result['name']?.trim() ?? '';
      if (name.isEmpty) {
        ToastHelper.showError(context, context.l10n.shiftsEnterName);
        return;
      }
      await _createShift(name, result['description']?.trim() ?? '');
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
          ToastHelper.showError(context, context.l10n.shiftsFlutterCreateFailed(friendlyErrorMessage(error.error)));
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
    // Ionic: ion-item with routerLink (label + iOS detail chevron).
    return ListTile(
      title: Text(shift.name),
      trailing: const IonDetailIcon(),
      onTap: onTap,
    );
  }
}
