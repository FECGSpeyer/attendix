import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonTranslucentAppBar, IonContentTopInset;
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../widgets/ion_condense.dart';
import 'attendance_type_edit_page.dart' show showAttendanceTypeCreateModal;
import '../widgets/settings_list.dart';

/// Attendance Types List Page
///
/// Shows all attendance types with reordering and CRUD capabilities.
class AttendanceTypesPage extends ConsumerStatefulWidget {
  const AttendanceTypesPage({super.key});

  @override
  ConsumerState<AttendanceTypesPage> createState() => _AttendanceTypesPageState();
}

class _AttendanceTypesPageState extends ConsumerState<AttendanceTypesPage> {
  bool _isReordering = false;
  List<AttendanceType> _localTypes = [];

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(attendanceTypesProvider);
    final title = context.l10n.typeSettingsTypes;
    final ios = ionIsIos(context);

    // UX_SETTINGS (WAVE 8): types.page.html — arrow-back, condense title,
    // repeat/checkmark header button, hint card, inset list of type names,
    // add FAB.
    return IonCondense(builder: (context, collapsed) => Scaffold(
      // IOS_R6: Ionic `ion-content fullscreen` under the translucent header
      extendBodyBehindAppBar: ionIsIos(context),
      // IOS_R6: `ion-header translucent` (blur once condensed)
      appBar: IonTranslucentAppBar(condensed: collapsed, child: AppBar(
        leading: IconButton(
          icon: Icon(AppIcons.arrowBack, semanticLabel: context.l10n.commonBack),
          onPressed: () => context.pop(),
        ),
        title: IonCondenseTitle(title, collapsed: collapsed),
        actions: [
          if (_isReordering)
            IconButton(
              // UX_SETTINGS: Ionic checkmark to save the order
              icon: Icon(AppIcons.check),
              tooltip: context.l10n.commonSave,
              onPressed: _saveOrder,
            )
          else
            IconButton(
              icon: Icon(AppIcons.repeat),
              tooltip: context.l10n.typeSettingsFlutterReorder,
              onPressed: () {
                setState(() {
                  _isReordering = true;
                  _localTypes = [...(typesAsync.valueOrNull ?? [])];
                });
              },
            ),
        ],
      )),
      body: typesAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (error, stack) => Center(child: Text(context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(error)))),
        data: (types) {
          final displayTypes = _isReordering ? _localTypes : types;
          return ListView(
            padding: EdgeInsets.fromLTRB(ionListMargin(context), ios ? 0 : 16, ionListMargin(context), 96),
            children: [
              const IonContentTopInset(),
              IonLargeTitle(title, padding: const EdgeInsets.only(bottom: 4)),
              SizedBox(height: ios ? 24 : 0),
              SettingsHintCard(icon: AppIcons.list, text: context.l10n.typeSettingsTypesIntro),
              SettingsListSection(
                title: context.l10n.typeSettingsAttendanceTypes,
                icons: false,
                children: [
                  if (_isReordering)
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: displayTypes.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = _localTypes.removeAt(oldIndex);
                          _localTypes.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) => SettingsListTile(
                        key: ValueKey(displayTypes[index].id),
                        title: displayTypes[index].name,
                        detail: false,
                        // ion-reorder slot="end"
                        trailing: ReorderableDragStartListener(
                          index: index,
                          child: Icon(
                            AppIcons.dragHandle,
                            color: ios ? IonIos.note(context) : AppColors.medium,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final type in displayTypes)
                      SettingsListTile(
                        title: type.name,
                        onTap: () => _openTypeDetail(type),
                      ),
                ],
              ),
            ],
          );
        },
      ),
      floatingActionButton: !_isReordering
          ? FloatingActionButton(
              // Ionic openTypeModal(): the type page as modal in the "new"
              // mode (all settings); the notifier reloads the list.
              onPressed: () => showAttendanceTypeCreateModal(context),
              child: Icon(AppIcons.add),
            )
          : FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isReordering = false;
                  _localTypes = [];
                });
              },
              backgroundColor: AppColors.medium,
              child: Icon(AppIcons.close),
            ),
    ));
  }

  Future<void> _saveOrder() async {
    try {
      final orderedIds = _localTypes
          .where((type) => type.id != null)
          .map((type) => type.id!)
          .toList();

      final success = await ref.read(attendanceTypeNotifierProvider.notifier).reorderTypes(orderedIds);

      if (success) {
        // BL-008: Only reset state AFTER successful save
        setState(() {
          _isReordering = false;
          _localTypes = [];
        });

        if (mounted) {
          ToastHelper.showSuccess(context, context.l10n.typeSettingsOrderSaved);
        }
      } else {
        if (mounted) {
          ToastHelper.showError(context, context.l10n.typeSettingsFlutterSaveOrderFailed);
        }
      }
    } catch (e) {
      // BL-008: Keep local changes on error - DO NOT reset _isReordering or _localTypes
      if (mounted) {
        ToastHelper.showError(context, context.l10n.typeSettingsFlutterSaveOrderFailed);
      }
    }
  }

  void _openTypeDetail(AttendanceType type) {
    context.push('/settings/types/${type.id}');
  }

}
