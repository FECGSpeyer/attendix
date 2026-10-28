import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../l10n/l10n.dart';
import '../../team_org_utils.dart';

/// Opens "Neue Aufgabe" / "Aufgabe bearbeiten" as a sheet (leadership only).
/// Resolves with the created/updated task, or null when closed without saving.
Future<TeamTask?> showTaskFormSheet(
  BuildContext context, {
  TeamTask? task,
  int? attendanceId,
  String? protocolId,
  String? agendaItemId,
  String? presetTitle,
  int? presetPersonId,
  String? contextLabel,
}) {
  return showModalBottomSheet<TeamTask>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TaskFormSheet(
      task: task,
      attendanceId: attendanceId,
      protocolId: protocolId,
      agendaItemId: agendaItemId,
      presetTitle: presetTitle,
      presetPersonId: presetPersonId,
      contextLabel: contextLabel,
    ),
  );
}

class TaskFormSheet extends ConsumerStatefulWidget {
  const TaskFormSheet({
    super.key,
    this.task,
    this.attendanceId,
    this.protocolId,
    this.agendaItemId,
    this.presetTitle,
    this.presetPersonId,
    this.contextLabel,
  });

  final TeamTask? task;
  final int? attendanceId;
  final String? protocolId;
  final String? agendaItemId;
  final String? presetTitle;
  final int? presetPersonId;
  final String? contextLabel;

  @override
  ConsumerState<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<TaskFormSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  int? _personId;
  String? _dueDate;
  String _priority = 'medium';
  bool _notify = true;
  bool _saving = false;

  bool get _isEdit => widget.task?.id != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? widget.presetTitle ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _personId = t != null ? t.responsiblePersonId : widget.presetPersonId;
    _dueDate = t?.dueDate;
    _priority = t?.priority ?? 'medium';
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _showNotifyToggle => needsAssignmentNotice(widget.task?.responsiblePersonId, _personId);

  List<Person> _persons() {
    final players = ref.watch(playersProvider).valueOrNull ?? const <Person>[];
    final list = players.where((p) => (p.left == null || p.left!.isEmpty) && !p.pending).toList()
      ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return list;
  }

  String _personName(List<Person> persons) {
    for (final p in persons) {
      if (p.id == _personId) return p.fullName;
    }
    if (widget.task?.responsiblePersonId == _personId) return widget.task!.responsiblePerson.fullName;
    return '';
  }

  Future<void> _pickPerson(List<Person> persons) async {
    final result = await showModalBottomSheet<({int? id})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _PersonPicker(persons: persons, selectedId: _personId),
    );
    if (result != null) setState(() => _personId = result.id);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_dueDate ?? '') ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
      locale: Locale(currentLanguage()),
    );
    if (picked != null) setState(() => _dueDate = localToday(picked));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.tasksEnterTitle);
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final description = _description.text.trim();
    final shouldNotify = _notify && _showNotifyToggle;
    final notifier = ref.read(teamTaskNotifierProvider.notifier);
    try {
      TeamTask saved;
      if (_isEdit) {
        saved = await notifier.update(widget.task!.id!, {
          'title': title,
          'description': description.isEmpty ? null : description,
          'responsible_person_id': _personId,
          'due_date': _dueDate,
          'priority': _priority,
        }, notify: shouldNotify);
      } else {
        saved = await notifier.create(
          TeamTask(
            title: title,
            description: description.isEmpty ? null : description,
            responsiblePersonId: _personId,
            dueDate: _dueDate,
            priority: _priority,
            status: 'open',
            attendanceId: widget.attendanceId,
            protocolId: widget.protocolId,
            agendaItemId: widget.agendaItemId,
          ),
          notify: shouldNotify,
        );
      }
      if (!mounted) return;
      ToastHelper.showSuccess(context, _isEdit ? context.l10n.tasksSaved : context.l10n.tasksCreated);
      Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.tasksSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final persons = _persons();
    final personName = _personName(persons);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.commonClose,
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(_isEdit ? l10n.tasksFlutterEditTask : l10n.tasksFlutterNewTask),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              children: [
                if (widget.contextLabel != null && widget.contextLabel!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 18),
                        const SizedBox(width: 6),
                        Expanded(child: Text(widget.contextLabel!, style: theme.textTheme.bodySmall)),
                      ],
                    ),
                  ),
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l10n.tasksTitle, hintText: l10n.tasksWhatToDo),
                ),
                const SizedBox(height: AppDimensions.paddingS),
                TextField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l10n.tasksDescriptionOptional),
                ),
                const SizedBox(height: AppDimensions.paddingM),
                Text(l10n.tasksWhoWhen, style: theme.textTheme.titleSmall),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.tasksResponsible),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_personId != null && personName.isNotEmpty ? personName : l10n.tasksNobody),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _pickPerson(persons),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.tasksDueOn),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: _pickDate,
                        child: Text(_dueDate != null ? formatLongDate(_dueDate) : l10n.tasksFlutterNoDate),
                      ),
                      if (_dueDate != null)
                        IconButton(
                          tooltip: l10n.commonDelete,
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _dueDate = null),
                        ),
                    ],
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: InputDecoration(labelText: l10n.tasksPriority),
                  items: const ['low', 'medium', 'high']
                      .map((p) => DropdownMenuItem(value: p, child: Text(priorityLabels[p]!)))
                      .toList(),
                  onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                ),
                if (_showNotifyToggle)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _notify,
                    onChanged: (v) => setState(() => _notify = v),
                    title: Text(l10n.tasksNotify(_firstName(persons) ?? l10n.tasksPerson)),
                    subtitle: Text(l10n.tasksNotifyHint),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving || _title.text.trim().isEmpty ? null : _save,
                  child: Text(_isEdit ? l10n.commonSave : l10n.teamOrgCreateTask),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _firstName(List<Person> persons) {
    for (final p in persons) {
      if (p.id == _personId && p.firstName.isNotEmpty) return p.firstName;
    }
    return null;
  }
}

class _PersonPicker extends StatefulWidget {
  const _PersonPicker({required this.persons, required this.selectedId});
  final List<Person> persons;
  final int? selectedId;

  @override
  State<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<_PersonPicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = _search.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.persons
        : widget.persons.where((p) => p.fullName.toLowerCase().contains(q)).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          AppBar(
            automaticallyImplyLeading: false,
            title: Text(l10n.tasksResponsible),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.personDone)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            child: TextField(
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.tasksSearchPerson),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (q.isEmpty)
                  ListTile(
                    title: Text(l10n.tasksNobody),
                    trailing: widget.selectedId == null ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.of(context).pop((id: null)),
                  ),
                for (final p in filtered)
                  ListTile(
                    leading: CircleAvatar(child: Text(p.initials)),
                    title: Text(p.fullName),
                    trailing: p.id == widget.selectedId ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.of(context).pop((id: p.id)),
                  ),
                if (filtered.isEmpty)
                  ListTile(title: Text(l10n.tasksNoPersonFound)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
