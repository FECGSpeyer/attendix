import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/teacher_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/repositories/teacher_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Teacher list (Ionic teachers.page): "Lehrer", rows with name, instrument
/// names and a "n Spieler" badge; FAB opens the "Lehrer hinzufügen" sheet,
/// tapping a row opens "Lehrer bearbeiten".
class TeachersListPage extends ConsumerWidget {
  const TeachersListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachersAsync = ref.watch(enrichedTeachersProvider);
    final currentRole = ref.watch(currentRoleProvider);
    // Ionic teachers.page isAdmin = Admin or Responsible
    final isAdmin = currentRole.isAdmin || currentRole.isResponsible;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.teachersTitle)),
      body: teachersAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text(
                context.l10n.teachersFlutterLoadFailed,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppDimensions.paddingM),
              ElevatedButton(
                onPressed: () => ref.invalidate(enrichedTeachersProvider),
                child: Text(context.l10n.messagesRetry),
              ),
            ],
          ),
        ),
        data: (teachers) {
          return RefreshIndicator.adaptive(
            onRefresh: () async {
              ref.invalidate(teachersProvider);
              ref.invalidate(studentCountsProvider);
              ref.invalidate(enrichedTeachersProvider);
              await ref.read(enrichedTeachersProvider.future);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: teachers.length,
              itemBuilder: (context, index) {
                final teacher = teachers[index];
                return _TeacherTile(
                  teacher: teacher,
                  onTap: () => _openTeacherPage(context, ref, teacher),
                  onDelete: isAdmin
                      ? () => _deleteTeacher(context, ref, teacher)
                      : null,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showAddSheet(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// Ionic "Lehrer hinzufügen" sheet (breakpoint 0.7).
  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) async {
    final groups = ref.read(groupsProvider).valueOrNull ?? [];
    final result = await showModalBottomSheet<Teacher>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _TeacherForm(availableInstruments: groups),
      ),
    );
    if (result == null) return;
    try {
      await ref.read(teacherNotifierProvider.notifier).createTeacher(result);
    } catch (e) {
      if (context.mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  /// Ionic TeacherPage modal ("Lehrer bearbeiten").
  Future<void> _openTeacherPage(
    BuildContext context,
    WidgetRef ref,
    Teacher teacher,
  ) async {
    final groups = ref.read(groupsProvider).valueOrNull ?? [];
    final result = await Navigator.of(context).push<Teacher>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _TeacherEditPage(
          teacher: teacher,
          availableInstruments: groups,
        ),
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
          ToastHelper.showSuccess(context, context.l10n.teachersUpdated);
        }
      } catch (e) {
        if (context.mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
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
      title: context.l10n.teachersFlutterDelete,
      message: context.l10n.teachersFlutterDeleteConfirm(teacher.name),
      confirmText: context.l10n.commonDelete,
      cancelText: context.l10n.commonCancel,
    );
    if (!confirmed || teacher.id == null) return;

    try {
      await ref.read(teacherNotifierProvider.notifier).deleteTeacher(teacher.id!);
      if (context.mounted) ToastHelper.showSuccess(context, context.l10n.teachersFlutterDeleted);
    } catch (e) {
      if (context.mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }
}

class _TeacherTile extends StatelessWidget {
  final Teacher teacher;
  final VoidCallback? onTap;

  /// Flutter extra (Ionic has no delete): swipe left to delete.
  final VoidCallback? onDelete;

  const _TeacherTile({
    required this.teacher,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final count = teacher.playerCount ?? 0;
    return Dismissible(
      key: ValueKey(teacher.id),
      direction:
          onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
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
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom:
                  BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(teacher.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    if (teacher.insNames?.isNotEmpty ?? false)
                      Text(teacher.insNames!,
                          style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: count > 0 ? AppColors.primary : AppColors.danger,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  context.l10n.teachersPlayerCount(count),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Form fields shared by "Lehrer hinzufügen" and "Lehrer bearbeiten"
/// (Ionic order: Name, Instrumente, Privatlehrer, Kontakt, Notizen).
class _TeacherForm extends StatefulWidget {
  const _TeacherForm({
    this.teacher,
    required this.availableInstruments,
    this.players = const [],
  });

  final Teacher? teacher;
  final List<Group> availableInstruments;

  /// Names of the players of this teacher (edit only)
  final List<String> players;

  @override
  State<_TeacherForm> createState() => _TeacherFormState();
}

class _TeacherFormState extends State<_TeacherForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  late final TextEditingController _notesController;
  late bool _private;
  late Set<int> _selectedInstruments;

  bool get _isNew => widget.teacher == null;

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

  Future<void> _pickInstruments() async {
    final selected = Set<int>.from(_selectedInstruments);
    final result = await showAppDialog<Set<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppAlertDialog(
          title: Text(context.l10n.teachersInstruments),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final g in widget.availableInstruments)
                  if (g.id != null)
                    CheckboxListTile(
                      title: Text(g.name),
                      value: selected.contains(g.id),
                      onChanged: (v) => setDialogState(() {
                        if (v == true) {
                          selected.add(g.id!);
                        } else {
                          selected.remove(g.id!);
                        }
                      }),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: Text(context.l10n.commonOk),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _selectedInstruments = result);
  }

  void _submit() {
    // Ionic teachers.page addTeacher: name (≥ 3 chars) and instruments required
    if (_nameController.text.trim().length < 3 || _selectedInstruments.isEmpty) {
      ToastHelper.showError(context, context.l10n.teachersFillAll);
      return;
    }
    Navigator.pop(
      context,
      Teacher(
        id: widget.teacher?.id,
        name: _nameController.text.trim(),
        number: _numberController.text.trim(),
        notes: _notesController.text.trim(),
        isPrivate: _private,
        instruments: _selectedInstruments.toList(),
        tenantId: widget.teacher?.tenantId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.availableInstruments
        .where((g) => _selectedInstruments.contains(g.id))
        .map((g) => g.name)
        .join(', ');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isNew) ...[
            Text(context.l10n.teachersAdd,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppDimensions.paddingM),
          ],
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: context.l10n.typeSettingsName),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.teachersInstruments),
            subtitle: names.isEmpty ? null : Text(names),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: _pickInstruments,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.teachersPrivate),
            value: _private,
            onChanged: (v) => setState(() => _private = v),
          ),
          TextField(
            controller: _numberController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: context.l10n.teachersContact),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          TextField(
            controller: _notesController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: context.l10n.peopleNotes),
            minLines: 1,
            maxLines: 5,
          ),
          if (widget.players.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.paddingM),
            ExpansionTile(
              title: Text(context.l10n.teachersPlayers),
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              children: [
                for (final p in widget.players)
                  ListTile(contentPadding: EdgeInsets.zero, title: Text(p)),
              ],
            ),
          ],
          const SizedBox(height: AppDimensions.paddingL),
          FilledButton(
            onPressed: _submit,
            child: Text(_isNew ? context.l10n.attendanceAdd : context.l10n.teachersUpdate),
          ),
        ],
      ),
    );
  }
}

/// Ionic TeacherPage: full-screen "Lehrer bearbeiten" with a close button.
class _TeacherEditPage extends ConsumerWidget {
  const _TeacherEditPage({
    required this.teacher,
    required this.availableInstruments,
  });

  final Teacher teacher;
  final List<Group> availableInstruments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = (ref.watch(playersProvider).valueOrNull ?? const [])
        .where((p) => teacher.id != null && p.teacher == teacher.id)
        .map((p) => '${p.firstName} ${p.lastName}')
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.teachersEdit),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.commonClose,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _TeacherForm(
        teacher: teacher,
        availableInstruments: availableInstruments,
        players: players,
      ),
    );
  }
}
