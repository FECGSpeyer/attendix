import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import '../widgets/ion_condense.dart'; // UX_SETTINGS (WAVE 8)
import '../widgets/settings_list.dart'; // UX_SETTINGS (WAVE 8)

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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: IonCondenseTitle(title, collapsed: collapsed),
        actions: [
          if (_isReordering)
            IconButton(
              // UX_SETTINGS: Ionic checkmark to save the order
              icon: const Icon(Icons.check),
              tooltip: context.l10n.commonSave,
              onPressed: _saveOrder,
            )
          else
            IconButton(
              icon: const Icon(Icons.repeat),
              tooltip: context.l10n.typeSettingsFlutterReorder,
              onPressed: () {
                setState(() {
                  _isReordering = true;
                  _localTypes = [...(typesAsync.valueOrNull ?? [])];
                });
              },
            ),
        ],
      ),
      body: typesAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (error, stack) => Center(child: Text(context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(error)))),
        data: (types) {
          final displayTypes = _isReordering ? _localTypes : types;
          return ListView(
            padding: EdgeInsets.fromLTRB(16, ios ? 0 : 16, 16, 96),
            children: [
              IonLargeTitle(title, padding: const EdgeInsets.only(bottom: 4)),
              SizedBox(height: ios ? 24 : 0),
              SettingsHintCard(icon: Icons.list, text: context.l10n.typeSettingsTypesIntro),
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
                            Icons.drag_handle,
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
              onPressed: () => _showCreateDialog(context),
              child: const Icon(Icons.add),
            )
          : FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isReordering = false;
                  _localTypes = [];
                });
              },
              backgroundColor: AppColors.medium,
              child: const Icon(Icons.close),
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

  Future<void> _showCreateDialog(BuildContext context) async {
    final nameController = TextEditingController();

    final result = await showAppDialog<String>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.typeSettingsFlutterNewType),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: context.l10n.typeSettingsName,
            hintText: context.l10n.typeSettingsFlutterNamePh,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: Text(context.l10n.filesCreate),
          ),
        ],
      ),
    );

    if (result == null) return;
    // LOGIC_SETTINGS: Ionic validate() — name required
    if (result.trim().isEmpty) {
      if (context.mounted) {
        ToastHelper.showError(context, context.l10n.typeSettingsEnterName);
      }
      return;
    }
    await _createType(result.trim());
  }

  Future<void> _createType(String name) async {
    // LOGIC_SETTINGS: Ionic TypePage isNew defaults (index 999, empty
    // default_plan, relevant_groups [], reminders []); statuses are written
    // as numbers by the repository.
    final newType = buildNewAttendanceType(name);

    try {
      final created = await ref
          .read(attendanceTypeNotifierProvider.notifier)
          .createType(newType);

      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.typeSettingsCreated);
      // Ionic configures the full type in the create modal; here the edit
      // page of the new type opens so all settings (incl. duty view) follow.
      if (created.id != null) {
        context.push('/settings/types/${created.id}');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.typeSettingsCreateFailed);
      }
    }
  }
}

/// LOGIC_SETTINGS: defaults of a new type as in Ionic type.page.ts (isNew).
AttendanceType buildNewAttendanceType(String name) {
  return AttendanceType(
    name: name.trim(),
    planningTitle: '',
    defaultStatus: AttendanceStatus.present,
    availableStatuses: const [
      AttendanceStatus.neutral,
      AttendanceStatus.present,
      AttendanceStatus.absent,
      AttendanceStatus.excused,
      AttendanceStatus.late,
    ],
    manageSongs: false,
    startTime: '19:00',
    endTime: '20:30',
    relevantGroups: const [],
    index: 999,
    visible: true,
    color: 'primary',
    highlight: false,
    hideName: false,
    includeInAverage: true,
    reminders: const [],
    defaultPlan: const {'time': '', 'end': '', 'fields': <dynamic>[]},
  );
}
