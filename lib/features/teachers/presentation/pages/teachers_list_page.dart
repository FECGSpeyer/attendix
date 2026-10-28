import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/teacher_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/repositories/teacher_repository.dart';

/// Teacher List Page — with instrument names, student counts, role checks
class TeachersListPage extends ConsumerWidget {
  const TeachersListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachersAsync = ref.watch(enrichedTeachersProvider);
    final currentRole = ref.watch(currentRoleProvider);
    final isConductor = currentRole.isConductor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lehrer / Dirigenten'),
      ),
      body: teachersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text(
                'Lehrer konnten nicht geladen werden',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppDimensions.paddingXS),
              Text(
                '$error',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.medium),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingM),
              ElevatedButton(
                onPressed: () => ref.invalidate(enrichedTeachersProvider),
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
        data: (teachers) {
          if (teachers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school_outlined, size: 64, color: AppColors.medium),
                  const SizedBox(height: AppDimensions.paddingM),
                  const Text('Keine Lehrer vorhanden'),
                  if (isConductor) ...[
                    const SizedBox(height: AppDimensions.paddingM),
                    ElevatedButton.icon(
                      onPressed: () => _showCreateDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Lehrer hinzufügen'),
                    ),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(teachersProvider);
              ref.invalidate(studentCountsProvider);
              ref.invalidate(enrichedTeachersProvider);
              await ref.read(enrichedTeachersProvider.future);
            },
            child: ListView.builder(
              itemCount: teachers.length,
              itemBuilder: (context, index) {
                final teacher = teachers[index];
                return _TeacherTile(
                  teacher: teacher,
                  onTap: isConductor
                      ? () => _showEditDialog(context, ref, teacher)
                      : null,
                  onDelete: isConductor
                      ? () => _deleteTeacher(context, ref, teacher)
                      : null,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: isConductor
          ? FloatingActionButton(
              onPressed: () => _showCreateDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final groups = ref.read(groupsProvider).valueOrNull ?? [];
    final result = await showDialog<Teacher>(
      context: context,
      builder: (context) => _TeacherEditDialog(availableInstruments: groups),
    );

    if (result != null) {
      try {
        await ref.read(teacherNotifierProvider.notifier).createTeacher(result);

        if (context.mounted) {
          ToastHelper.showSuccess(context, 'Lehrer "${result.name}" erstellt');
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, 'Fehler: $e');
        }
      }
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Teacher teacher,
  ) async {
    final groups = ref.read(groupsProvider).valueOrNull ?? [];
    final result = await showDialog<Teacher>(
      context: context,
      builder: (context) => _TeacherEditDialog(
        teacher: teacher,
        availableInstruments: groups,
      ),
    );

    if (result != null && teacher.id != null) {
      try {
        await ref.read(teacherNotifierProvider.notifier).updateTeacher(
              teacher.id!,
              {
                'name': result.name,
                'number': result.number,
                'notes': result.notes,
                'private': result.isPrivate,
                'instruments': result.instruments,
              },
            );

        if (context.mounted) {
          ToastHelper.showSuccess(context, 'Änderungen gespeichert');
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, 'Fehler: $e');
        }
      }
    }
  }

  Future<void> _deleteTeacher(
    BuildContext context,
    WidgetRef ref,
    Teacher teacher,
  ) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Lehrer löschen',
      message: 'Möchtest du "${teacher.name}" wirklich löschen?',
      confirmText: 'Löschen',
      cancelText: 'Abbrechen',
    );

    if (!confirmed) return;

    if (teacher.id == null) return;

    try {
      await ref.read(teacherNotifierProvider.notifier).deleteTeacher(teacher.id!);

      if (context.mounted) {
        ToastHelper.showSuccess(context, 'Lehrer gelöscht');
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.showError(context, 'Fehler: $e');
      }
    }
  }
}

class _TeacherTile extends StatelessWidget {
  final Teacher teacher;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _TeacherTile({
    required this.teacher,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(teacher.id),
      direction: onDelete != null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      confirmDismiss: (_) async {
        onDelete?.call();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.danger,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
          child: const Icon(Icons.person, color: AppColors.primary),
        ),
        title: Text(teacher.name),
        subtitle: _buildSubtitle(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (teacher.playerCount != null && teacher.playerCount! > 0)
              _StudentCountBadge(count: teacher.playerCount!),
            if (teacher.isPrivate)
              const Icon(Icons.lock_outline, size: 16, color: AppColors.medium),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.medium),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget? _buildSubtitle() {
    final parts = <String>[];

    // Instrument names first
    if (teacher.insNames != null && teacher.insNames!.isNotEmpty) {
      parts.add(teacher.insNames!);
    }

    // Phone number
    if (teacher.number.isNotEmpty) {
      parts.add('Tel: ${teacher.number}');
    }

    if (parts.isEmpty && teacher.notes.isNotEmpty) {
      return Text(
        teacher.notes,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (parts.isEmpty) return null;

    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Student count badge
class _StudentCountBadge extends StatelessWidget {
  const _StudentCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherEditDialog extends StatefulWidget {
  final Teacher? teacher;
  final List<Group> availableInstruments;

  const _TeacherEditDialog({
    this.teacher,
    required this.availableInstruments,
  });

  @override
  State<_TeacherEditDialog> createState() => _TeacherEditDialogState();
}

class _TeacherEditDialogState extends State<_TeacherEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  late final TextEditingController _notesController;
  late bool _private;
  late Set<int> _selectedInstruments;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.teacher?.name ?? '');
    _numberController =
        TextEditingController(text: widget.teacher?.number ?? '');
    _notesController = TextEditingController(text: widget.teacher?.notes ?? '');
    _private = widget.teacher?.isPrivate ?? false;
    _selectedInstruments = Set<int>.from(widget.teacher?.instruments ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.teacher == null;
    final instruments = widget.availableInstruments
        .where((g) => g.maingroup != true)
        .toList();

    return AlertDialog(
      title: Text(isNew ? 'Neuer Lehrer' : 'Lehrer bearbeiten'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    hintText: 'z.B. Max Mustermann',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Bitte einen Namen eingeben';
                    }
                    // Ionic teachers.page: name must have at least 3 chars
                    if (value.trim().length < 3) {
                      return 'Name muss mindestens 3 Zeichen haben';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.paddingM),
                TextFormField(
                  controller: _numberController,
                  decoration: const InputDecoration(
                    labelText: 'Telefon',
                    hintText: 'z.B. +49 123 456789',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final cleaned = value.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
                      if (!RegExp(r'^\+?[0-9]{4,15}$').hasMatch(cleaned)) {
                        return 'Bitte eine gültige Telefonnummer eingeben';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.paddingM),

                // Instruments multi-select
                if (instruments.isNotEmpty) ...[
                  Text(
                    'Instrumente *',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.medium,
                        ),
                  ),
                  const SizedBox(height: AppDimensions.paddingXS),
                  Wrap(
                    spacing: AppDimensions.paddingXS,
                    runSpacing: AppDimensions.paddingXS,
                    children: instruments.map((instrument) {
                      final isSelected =
                          _selectedInstruments.contains(instrument.id);
                      return FilterChip(
                        label: Text(instrument.displayName),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected && instrument.id != null) {
                              _selectedInstruments.add(instrument.id!);
                            } else if (instrument.id != null) {
                              _selectedInstruments.remove(instrument.id!);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                ],

                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notizen',
                    hintText: 'Zusätzliche Informationen...',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                ),
                const SizedBox(height: AppDimensions.paddingM),
                SwitchListTile(
                  title: const Text('Privat'),
                  subtitle: const Text('Nur für Admins sichtbar'),
                  value: _private,
                  onChanged: (value) => setState(() => _private = value),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isNew ? 'Erstellen' : 'Speichern'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // Ionic teachers.page: at least one instrument is required
    if (_selectedInstruments.isEmpty) {
      ToastHelper.showError(
        context,
        'Bitte fülle alle Felder aus, um fortzufahren.',
      );
      return;
    }

    final result = Teacher(
      id: widget.teacher?.id,
      name: _nameController.text.trim(),
      number: _numberController.text.trim(),
      notes: _notesController.text.trim(),
      isPrivate: _private,
      instruments: _selectedInstruments.toList(),
      tenantId: widget.teacher?.tenantId,
    );

    Navigator.pop(context, result);
  }
}
