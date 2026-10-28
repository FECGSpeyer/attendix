import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../../../../l10n/l10n.dart';
import '../../team_org_utils.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

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
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    // Ionic: ion-modal breakpoints [0, 1] (full height), content color light.
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
    final picked = await showAppDatePicker(
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

    final hasPerson = _personId != null && personName.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Column(
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              primary: false,
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.commonClose,
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(_isEdit ? l10n.tasksFlutterEditTask : l10n.tasksFlutterNewTask),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  // Ionic `.task-form-context`
                  if (widget.contextLabel != null && widget.contextLabel!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.link, size: 18, color: AppColors.primaryDark),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(widget.contextLabel!,
                                style: const TextStyle(
                                    fontSize: 13.6, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                          ),
                        ],
                      ),
                    ),
                  // Ionic: title + description without labels (placeholders only).
                  IonInsetList(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _title,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: ionStackedInputDecoration(label: '', hint: l10n.tasksWhatToDo).copyWith(
                            labelText: null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            suffixIcon: _title.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: l10n.commonDelete,
                                    icon: const Icon(Icons.cancel, size: 18, color: AppColors.medium),
                                    onPressed: () => setState(() => _title.clear()),
                                  ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _description,
                          minLines: 3,
                          maxLines: 8,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: ionStackedInputDecoration(label: '', hint: l10n.tasksDescriptionOptional)
                              .copyWith(labelText: null, contentPadding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  ),
                  IonInsetList(
                    header: l10n.tasksWhoWhen,
                    children: [
                      ListTile(
                        title: Text(l10n.tasksResponsible),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasPerson) ...[
                              _Initials(text: _initialsOf(persons)),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              hasPerson ? personName : l10n.tasksNobody,
                              style: TextStyle(color: hasPerson ? theme.colorScheme.onSurface : AppColors.medium),
                            ),
                            const SizedBox(width: 4),
                            const IonDetailIcon(),
                          ],
                        ),
                        onTap: () => _pickPerson(persons),
                      ),
                      ListTile(
                        title: Text(l10n.tasksDueOn),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Ionic: small outline button with the date.
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: const Size(0, 32),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: _pickDate,
                              child: Text(_dueDate != null ? formatLongDate(_dueDate) : l10n.tasksFlutterNoDate),
                            ),
                            if (_dueDate != null)
                              IconButton(
                                tooltip: l10n.commonDelete,
                                icon: const Icon(Icons.clear, color: AppColors.medium),
                                onPressed: () => setState(() => _dueDate = null),
                              ),
                          ],
                        ),
                      ),
                      IonSelect<String>(
                        label: l10n.tasksPriority,
                        value: _priority,
                        items: const ['low', 'medium', 'high']
                            .map((p) => DropdownMenuItem(value: p, child: Text(priorityLabels[p]!)))
                            .toList(),
                        onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                      ),
                      if (_showNotifyToggle)
                        SwitchListTile.adaptive(
                          value: _notify,
                          onChanged: (v) => setState(() => _notify = v),
                          title: Text(l10n.tasksNotify(_firstName(persons) ?? l10n.tasksPerson)),
                          subtitle: Text(l10n.tasksNotifyHint, style: const TextStyle(color: AppColors.medium)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Ionic `.task-form-footer`: round primary-shade button, 50px.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    onPressed: _saving || _title.text.trim().isEmpty ? null : _save,
                    child: Text(_isEdit ? l10n.commonSave : l10n.teamOrgCreateTask),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initialsOf(List<Person> persons) {
    for (final p in persons) {
      if (p.id == _personId) return p.initials;
    }
    return widget.task?.responsiblePerson.initials ?? '';
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
            primary: false,
            title: Text(l10n.tasksResponsible),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.personDone)),
            ],
          ),
          IonSearchbar(
            placeholder: l10n.tasksSearchPerson,
            onChanged: (v) => setState(() => _search = v),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: (q.isEmpty ? 1 : 0) + (filtered.isEmpty ? 1 : filtered.length),
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
              itemBuilder: (context, i) {
                if (q.isEmpty) {
                  if (i == 0) {
                    return ListTile(
                      title: Text(l10n.tasksNobody, style: const TextStyle(color: AppColors.medium)),
                      trailing: widget.selectedId == null ? const Icon(Icons.check, color: AppColors.primary) : null,
                      onTap: () => Navigator.of(context).pop((id: null)),
                    );
                  }
                  i -= 1;
                }
                if (filtered.isEmpty) {
                  return ListTile(title: Text(l10n.tasksNoPersonFound, style: const TextStyle(color: AppColors.medium)));
                }
                final p = filtered[i];
                return ListTile(
                  leading: _Initials(text: p.initials),
                  title: Text(p.fullName),
                  trailing: p.id == widget.selectedId ? const Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () => Navigator.of(context).pop((id: p.id)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Ionic `.task-initials`: 30px circle in primary shade with white initials.
class _Initials extends StatelessWidget {
  const _Initials({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.primaryDark, shape: BoxShape.circle),
        child: Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
      );
}
