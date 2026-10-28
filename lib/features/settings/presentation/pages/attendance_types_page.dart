import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.typeSettingsTypes),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(error)))),
        data: (types) {
          final displayTypes = _isReordering ? _localTypes : types;

          if (displayTypes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.category_outlined, size: 64, color: AppColors.medium),
                  const SizedBox(height: 16),
                  Text(context.l10n.typeSettingsFlutterNoTypes),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context),
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.typeSettingsFlutterCreateType),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(AppDimensions.paddingM),
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppDimensions.paddingS),
                    Expanded(
                      child: Text(
                        context.l10n.typeSettingsTypesIntro,
                        style: const TextStyle(fontSize: 13, color: AppColors.dark),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isReordering
              ? ReorderableListView.builder(
                  itemCount: displayTypes.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _localTypes.removeAt(oldIndex);
                      _localTypes.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    return _AttendanceTypeTile(
                      key: ValueKey(displayTypes[index].id),
                      type: displayTypes[index],
                      onTap: null,
                      trailing: const Icon(Icons.drag_handle),
                    );
                  },
                )
              : ListView.builder(
                  itemCount: displayTypes.length,
                  itemBuilder: (context, index) {
                    return _AttendanceTypeTile(
                      type: displayTypes[index],
                      onTap: () => _openTypeDetail(displayTypes[index]),
                      trailing: const Icon(Icons.chevron_right),
                    );
                  },
                ),
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
    );
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

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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

class _AttendanceTypeTile extends StatelessWidget {
  final AttendanceType type;
  final VoidCallback? onTap;
  final Widget trailing;

  const _AttendanceTypeTile({
    super.key,
    required this.type,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.getColorForPicker(type.color);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.event,
          color: color,
        ),
      ),
      title: Text(type.name),
      subtitle: Text(
        _getSubtitle(context.l10n),
        style: TextStyle(color: AppColors.medium, fontSize: 12),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  String _getSubtitle(AppLocalizations l10n) {
    final parts = <String>[];

    if (type.startTime != null && type.endTime != null) {
      parts.add('${type.startTime} - ${type.endTime}');
    }

    if (type.manageSongs) {
      parts.add(l10n.typeSettingsFlutterWithProgramme);
    }

    if (!type.visible) {
      parts.add(l10n.typeSettingsFlutterHidden);
    }

    return parts.isEmpty ? l10n.agendaDefault : parts.join(' • ');
  }
}
