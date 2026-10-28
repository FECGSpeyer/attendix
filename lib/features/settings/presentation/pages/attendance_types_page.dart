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
        title: const Text('Typen'),
        actions: [
          if (_isReordering)
            IconButton(
              // UX_SETTINGS: Ionic checkmark to save the order
              icon: const Icon(Icons.check),
              tooltip: 'Speichern',
              onPressed: _saveOrder,
            )
          else
            IconButton(
              icon: const Icon(Icons.repeat),
              tooltip: 'Reihenfolge ändern',
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
        error: (error, stack) => Center(child: Text('Fehler: $error')),
        data: (types) {
          final displayTypes = _isReordering ? _localTypes : types;

          if (displayTypes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.category_outlined, size: 64, color: AppColors.medium),
                  const SizedBox(height: 16),
                  const Text('Keine Anwesenheitstypen vorhanden'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Typ erstellen'),
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
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                    SizedBox(width: AppDimensions.paddingS),
                    Expanded(
                      child: Text(
                        'Pflege deine eigenen Typen für Anwesenheiten. So kannst du individuelle Bezeichnungen, einen Standard-Status, '
                        'Probenvorlagen und Start- bzw. Endzeiten hinterlegen und auch Anwesenheiten nur für bestimmte Gruppen konfigurieren.',
                        style: TextStyle(fontSize: 13, color: AppColors.dark),
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
          ToastHelper.showSuccess(context, 'Reihenfolge gespeichert');
        }
      } else {
        if (mounted) {
          ToastHelper.showError(context, 'Fehler beim Speichern. Bitte erneut versuchen.');
        }
      }
    } catch (e) {
      // BL-008: Keep local changes on error - DO NOT reset _isReordering or _localTypes
      if (mounted) {
        ToastHelper.showError(context, 'Fehler beim Speichern. Bitte erneut versuchen.');
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
        title: const Text('Neuer Anwesenheitstyp'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'z.B. Probe, Konzert, Generalprobe',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      await _createType(result.trim());
    }
  }

  Future<void> _createType(String name) async {
    try {
      final currentTypes = ref.read(attendanceTypesProvider).valueOrNull ?? [];

      final newType = AttendanceType(
        name: name,
        defaultStatus: AttendanceStatus.present,
        availableStatuses: [
          AttendanceStatus.neutral,
          AttendanceStatus.present,
          AttendanceStatus.absent,
          AttendanceStatus.excused,
          AttendanceStatus.late,
        ],
        manageSongs: false,
        startTime: '19:00',
        endTime: '20:30',
        relevantGroups: [],
        index: currentTypes.length,
        visible: true,
        color: 'primary',
        highlight: false,
        hideName: false,
        includeInAverage: true,
      );

      await ref.read(attendanceTypeNotifierProvider.notifier).createType(newType);

      if (mounted) {
        ToastHelper.showSuccess(context, 'Anwesenheitstyp "$name" erstellt');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler beim Erstellen: $e');
      }
    }
  }
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
        _getSubtitle(),
        style: TextStyle(color: AppColors.medium, fontSize: 12),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  String _getSubtitle() {
    final parts = <String>[];

    if (type.startTime != null && type.endTime != null) {
      parts.add('${type.startTime} - ${type.endTime}');
    }

    if (type.manageSongs) {
      parts.add('Mit Programm');
    }

    if (!type.visible) {
      parts.add('Ausgeblendet');
    }

    return parts.isEmpty ? 'Standard' : parts.join(' • ');
  }
}
