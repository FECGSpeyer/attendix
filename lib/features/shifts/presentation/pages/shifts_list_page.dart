import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/shift_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../../../settings/presentation/widgets/settings_list.dart' as sl;
import '../../../settings/presentation/widgets/settings_form_items.dart';
import '../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import '../../../../shared/widgets/dialogs/ion_sheet.dart' show showIonSheet, IonSheetScaffold;
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';

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
      leading: settingsBackButton(context, onPressed: () => context.pop()),
      floatingActionButton: TabBarFab.wrap(FloatingActionButton(
        onPressed: () => showCreateShiftPlanSheet(context, ref),
        child: Icon(AppIcons.add),
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
            // EIA-14: the settings inset list (header above the group).
            data: (shifts) => Padding(
              padding: EdgeInsets.symmetric(horizontal: sl.ionListMargin(context)),
              child: sl.SettingsListSection(
              title: context.l10n.shiftsPlans,
              icons: false,
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
            )),
          ),
        ],
      ),
    );
  }

  /// Ionic intro `ion-card`: centered time icon (4rem) and centered text with
  /// the warning line.
  Widget _buildInfoCard(BuildContext context) {
    // EIA-26: the shared Ionic `ion-card` box, 4rem `.headerIcon`.
    final ios = sl.ionIsIos(context);
    return sl.IonCardBox(
      margin: EdgeInsets.fromLTRB(sl.ionListMargin(context), 12, sl.ionListMargin(context), 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(AppIcons.schedule, size: 64, color: ios ? sl.IonIos.text(context) : AppColors.medium),
            const SizedBox(height: 16),
            Text(
              context.l10n.shiftsIntro,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
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
}

/// Ionic: ion-modal sheet (breakpoint 0.7) "Schichtplan erstellen" with
/// stacked name/description inputs and a block "Erstellen" button; creates
/// the plan and opens its detail page. Also used by the Beta list
/// "Schichtpläne" (rd_shift_plans_page.dart).
Future<void> showCreateShiftPlanSheet(BuildContext context, WidgetRef ref) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();

  try {
    Map<String, String>? result;
    if (context.rdSkin == null) {
      // EIA-16: Ionic sheet modal `[breakpoints]="[0, 0.7]"`, toolbar
      // title, inset list with stacked inputs and `ion-button expand="block"`.
      result = await showIonSheet<Map<String, String>?>(
        context,
        breakpoints: const [0, 0.7],
        initialBreakpoint: 0.7,
        builder: (sheetContext, controller) => IonSheetScaffold(
          title: sheetContext.l10n.shiftsCreate,
          body: ListView(
            controller: controller,
            padding: EdgeInsets.symmetric(horizontal: sl.ionListMargin(sheetContext), vertical: 16),
            children: [
              sl.SettingsListSection(icons: false, children: [
                IonStackedInput(
                  controller: nameController,
                  label: sheetContext.l10n.typeSettingsName,
                  autofocus: true,
                ),
                IonStackedInput(
                  controller: descriptionController,
                  label: sheetContext.l10n.tasksDescription,
                ),
              ]),
              IonButton(
                label: sheetContext.l10n.filesCreate,
                expand: true,
                onPressed: () => Navigator.pop(sheetContext, {
                  'name': nameController.text,
                  'description': descriptionController.text,
                }),
              ),
            ],
          ),
        ),
      );
    } else {
    result = await showModalBottomSheet<Map<String, String>?>(
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
                toolbarHeight: ionModalToolbarHeight(context),
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
                        child: IonButtonLabel(sheetContext.l10n.filesCreate),
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

    if (result == null || !context.mounted) return;
    // Ionic: dismiss first, then validate with a danger toast.
    final name = result['name']?.trim() ?? '';
    if (name.isEmpty) {
      ToastHelper.showError(context, context.l10n.shiftsEnterName);
      return;
    }
    await _createShift(context, ref, name, result['description']?.trim() ?? '');
  } finally {
    // FN-001: Dispose controllers
    nameController.dispose();
    descriptionController.dispose();
  }
}

Future<void> _createShift(BuildContext context, WidgetRef ref, String name, String description) async {
  final notifier = ref.read(shiftNotifierProvider.notifier);

  final plan = ShiftPlan(
    name: name,
    description: description,
  );

  final result = await notifier.createShift(plan);

  if (context.mounted) {
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
