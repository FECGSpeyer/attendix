import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../team_org_utils.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/tasks_tab.dart' show TeamOrgBadge, priorityColor, outcomeColor;

/// How many upcoming Termine "Einplanen" offers.
const int _planChoices = 6;

/// Thema: leadership edits topic, plans it into a Termin and adds tasks;
/// members read it (only their own suggestions are visible to them).
class AgendaItemDetailPage extends ConsumerStatefulWidget {
  const AgendaItemDetailPage({super.key, required this.itemId});

  /// Topic id, or `new`.
  final String itemId;

  @override
  ConsumerState<AgendaItemDetailPage> createState() => _AgendaItemDetailPageState();
}

class _AgendaItemDetailPageState extends ConsumerState<AgendaItemDetailPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _duration = TextEditingController();
  String _status = 'open';
  String _priority = 'medium';
  int? _responsibleId;
  String? _loadedId;
  late String _itemId = widget.itemId;
  bool _saving = false;

  bool get _isNew => _itemId == 'new';

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _fill(AgendaItem item) {
    if (_loadedId == item.id) return;
    _loadedId = item.id;
    _title.text = item.title;
    _description.text = item.description ?? '';
    _duration.text = item.defaultDuration?.toString() ?? '';
    _status = item.status;
    _priority = item.priority;
    _responsibleId = item.responsiblePersonId;
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ToastHelper.showWarning(context, 'Bitte einen Titel eingeben');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final duration = int.tryParse(_duration.text.trim()) ?? 0;
    final desc = _description.text.trim();
    final notifier = ref.read(agendaItemNotifierProvider.notifier);
    try {
      if (_isNew) {
        final created = await notifier.create(AgendaItem(
          title: title,
          description: desc.isEmpty ? null : desc,
          status: _status,
          priority: _priority,
          responsiblePersonId: _responsibleId,
          defaultDuration: duration > 0 ? duration : null,
        ));
        if (!mounted) return;
        setState(() => _itemId = created.id!);
        // Keep the URL in sync so back/reload work with the real id.
        context.replace('/settings/agenda-items/${created.id}');
      } else {
        await notifier.update(_itemId, {
          'title': title,
          'description': desc.isEmpty ? null : desc,
          'status': _status,
          'priority': _priority,
          'responsible_person_id': _responsibleId,
          'default_duration': duration > 0 ? duration : null,
        });
      }
      if (mounted) ToastHelper.showSuccess(context, 'Gespeichert');
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Thema konnte nicht gespeichert werden');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await DialogHelper.showConfirmation(
      context,
      title: 'Thema wirklich löschen?',
      message:
          'Es verschwindet aus dem Themenspeicher. Bereits geplante Ablaufpläne und Protokolle bleiben unverändert. Soll es nur aus einem Termin raus, entferne es dort über „Themen aufnehmen“ oder in der Teamorganisation.',
      confirmText: 'Löschen',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(agendaItemNotifierProvider.notifier).delete(_itemId);
      if (!mounted) return;
      ToastHelper.showSuccess(context, 'Gelöscht');
      context.go('/settings/team-organization?tab=topics');
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Löschen fehlgeschlagen');
    }
  }

  Future<void> _planInto(AgendaItem item) async {
    final types = await ref.read(protocolTypesProvider.future);
    List<ProtocolAttendance> upcoming = [];
    try {
      upcoming = (await ref.read(upcomingProtocolAttendancesProvider.future)).take(_planChoices).toList();
    } catch (_) {}
    if (!mounted) return;
    final fid = agendaFieldId(item.id!);
    ProtocolType? typeOf(ProtocolAttendance a) {
      for (final t in types) {
        if (t.id == a.typeId) return t;
      }
      return null;
    }

    final choice = await showModalBottomSheet<Object>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(upcoming.isNotEmpty
                  ? 'In welchen Termin einplanen?'
                  : 'Noch kein Termin mit Tagesordnung geplant'),
            ),
            for (final att in upcoming)
              Builder(builder: (_) {
                final already = att.fields.any((f) => fieldId(f) == fid);
                return ListTile(
                  enabled: !already,
                  title: Text(
                      '${formatShortWeekdayDate(att.date)} · ${attendanceTitle(att.typeInfo, typeOf(att))}${already ? ' (bereits eingeplant)' : ''}'),
                  onTap: () => Navigator.of(ctx).pop(att),
                );
              }),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Neuen Termin anlegen'),
              onTap: () => Navigator.of(ctx).pop('new'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'new') {
      await context.push('/attendance/new');
      ref.invalidate(upcomingProtocolAttendancesProvider);
      return;
    }
    if (choice is ProtocolAttendance) {
      final type = typeOf(choice);
      try {
        await addTopicsToAttendance(ref.read(protocolRepositoryWithTenantProvider), choice, type,
            [(item: item, duration: defaultTopicDuration(item, type))]);
        ref.invalidate(upcomingProtocolAttendancesProvider);
        ref.invalidate(agendaItemHistoryProvider(_itemId));
        final d = DateTime.tryParse(choice.date)?.toLocal();
        if (mounted) {
          ToastHelper.showSuccess(context, 'Eingeplant für ${d != null ? DateFormat('dd.MM.').format(d) : ''}');
        }
      } catch (_) {
        if (mounted) ToastHelper.showError(context, 'Thema konnte nicht eingeplant werden');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLeader = ref.watch(isTeamLeaderProvider);
    final AsyncValue<AgendaItem?> itemAsync =
        _isNew ? const AsyncValue.data(null) : ref.watch(agendaItemByIdProvider(_itemId));
    final item = itemAsync.valueOrNull;
    if (item != null && isLeader) _fill(item);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Neues Thema' : 'Thema'),
        actions: [
          if (!_isNew && item != null && isLeader)
            IconButton(
              tooltip: 'Thema löschen',
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: _delete,
            ),
        ],
      ),
      floatingActionButton: isLeader && (item != null || _isNew)
          ? FloatingActionButton(
              tooltip: 'Speichern',
              onPressed: _saving ? null : _save,
              child: const Icon(Icons.save_outlined),
            )
          : null,
      body: itemAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : (!_isNew && item == null)
              ? const Center(child: Text('Thema nicht gefunden'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, 96),
                  children: [
                    if (isLeader) ..._leaderForm() else ..._readOnly(item!),
                    if (item != null && item.proposer.fullName.isNotEmpty)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.lightbulb_outline, color: AppColors.medium),
                          title: Text('Vorschlag von ${item.proposer.fullName}'),
                          subtitle: item.decisionNote?.isNotEmpty == true ? Text(item.decisionNote!) : null,
                        ),
                      ),
                    if (!_isNew && isLeader && item?.status == 'open')
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
                        child: FilledButton.icon(
                          onPressed: () => _planInto(item!),
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: const Text('Einplanen'),
                        ),
                      ),
                    if (!_isNew && item != null) ...[
                      _HistorySection(itemId: _itemId),
                      _TasksSection(item: item, isLeader: isLeader),
                    ],
                  ],
                ),
    );
  }

  List<Widget> _leaderForm() {
    final persons = (ref.watch(playersProvider).valueOrNull ?? const <Person>[])
        .where((p) => (p.left == null || p.left!.isEmpty) && !p.pending)
        .toList()
      ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    final responsibleValid = _responsibleId == null || persons.any((p) => p.id == _responsibleId);
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Column(
            children: [
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Titel', hintText: 'Worum geht es?'),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              TextField(
                controller: _description,
                minLines: 3,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                  hintText: 'Hintergrund, Ziel, offene Fragen …',
                ),
              ),
            ],
          ),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const ['open', 'completed', 'dropped']
                    .map((s) => DropdownMenuItem(value: s, child: Text(topicStatusLabels[s]!)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? 'open'),
              ),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Priorität'),
                items: const ['high', 'medium', 'low']
                    .map((p) => DropdownMenuItem(value: p, child: Text(priorityLabels[p]!)))
                    .toList(),
                onChanged: (v) => setState(() => _priority = v ?? 'medium'),
              ),
              DropdownButtonFormField<int?>(
                value: responsibleValid ? _responsibleId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Verantwortlich'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Niemand')),
                  for (final p in persons) DropdownMenuItem<int?>(value: p.id, child: Text(p.fullName)),
                ],
                onChanged: (v) => setState(() => _responsibleId = v),
              ),
              TextField(
                controller: _duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Dauer pro Sitzung (Min.)', hintText: 'Standard'),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _readOnly(AgendaItem item) => [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppDimensions.paddingS),
                Wrap(spacing: 8, children: [
                  TeamOrgBadge(
                    label: topicStatusLabels[item.status] ?? item.status,
                    color: switch (item.status) {
                      'completed' => AppColors.success,
                      'dropped' => AppColors.medium,
                      _ => AppColors.primary,
                    },
                  ),
                  TeamOrgBadge(label: priorityLabels[item.priority] ?? item.priority, color: priorityColor(item.priority)),
                ]),
                if (item.responsiblePerson.fullName.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.paddingS),
                  Text('Verantwortlich: ${item.responsiblePerson.fullName}'),
                ],
                if (item.description?.isNotEmpty == true) ...[
                  const SizedBox(height: AppDimensions.paddingS),
                  Text(item.description!),
                ],
              ],
            ),
          ),
        ),
      ];
}

class _HistorySection extends ConsumerWidget {
  const _HistorySection({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(agendaItemHistoryProvider(itemId)).valueOrNull ?? const <AgendaItemHistoryEntry>[];
    final types = ref.watch(protocolTypesProvider).valueOrNull ?? const <ProtocolType>[];
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    ({String label, Color color}) status(AgendaItemHistoryEntry e) {
      if (e.outcome != null) return (label: outcomeLabels[e.outcome] ?? e.outcome!, color: outcomeColor(e.outcome));
      final d = DateTime.tryParse(e.date ?? '')?.toLocal();
      if (d != null && !d.isBefore(startOfToday)) return (label: 'Geplant', color: AppColors.primary);
      return (label: 'Ohne Ergebnis', color: AppColors.medium);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.paddingM, bottom: 4),
          child: Text('Verlauf', style: Theme.of(context).textTheme.titleSmall),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final e in history)
                Builder(builder: (_) {
                  ProtocolType? type;
                  for (final t in types) {
                    if (t.id == e.typeId) type = t;
                  }
                  final d = DateTime.tryParse(e.date ?? '')?.toLocal();
                  final s = status(e);
                  return ListTile(
                    title: Text(
                        '${attendanceTitle(e.typeInfo, type)} · ${d != null ? DateFormat('dd.MM.yyyy').format(d) : ''}'),
                    trailing: TeamOrgBadge(label: s.label, color: s.color),
                    onTap: e.attendanceId == null ? null : () => context.push('/settings/protocol/${e.attendanceId}'),
                  );
                }),
              if (history.isEmpty)
                const ListTile(
                  title: Text('Noch in keinem Termin besprochen.', style: TextStyle(color: AppColors.medium)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TasksSection extends ConsumerWidget {
  const _TasksSection({required this.item, required this.isLeader});
  final AgendaItem item;
  final bool isLeader;

  String _subtitle(TeamTask t) {
    final who = t.responsiblePerson.fullName.isNotEmpty ? t.responsiblePerson.fullName : 'Niemand zugewiesen';
    final fmt = DateFormat('dd.MM.');
    if (t.status == 'completed') {
      final d = DateTime.tryParse(t.completedAt ?? '')?.toLocal();
      return d != null ? '$who · erledigt ${fmt.format(d)}' : '$who · erledigt';
    }
    final due = DateTime.tryParse(t.dueDate ?? '');
    return due != null ? '$who · fällig ${fmt.format(due)}' : who;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksForAgendaItemProvider(item.id!)).valueOrNull ?? const <TeamTask>[];
    final done = tasks.where((t) => t.status == 'completed').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.paddingM, bottom: 4),
          child: Row(
            children: [
              Expanded(child: Text('Aufgaben', style: Theme.of(context).textTheme.titleSmall)),
              if (tasks.isNotEmpty) Text('$done von ${tasks.length} erledigt'),
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final t in tasks)
                ListTile(
                  leading: Icon(
                    t.status == 'completed' ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: t.status == 'completed' ? AppColors.success : AppColors.medium,
                  ),
                  title: Text(
                    t.title,
                    style: t.status == 'completed' ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                  ),
                  subtitle: Text(_subtitle(t)),
                  onTap: () => context.push('/settings/tasks/${t.id}'),
                ),
              if (tasks.isEmpty) const ListTile(title: Text('Keine Aufgaben', style: TextStyle(color: AppColors.medium))),
              if (isLeader)
                ListTile(
                  leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  title: const Text('Aufgabe hinzufügen', style: TextStyle(color: AppColors.primary)),
                  onTap: () => showTaskFormSheet(
                    context,
                    agendaItemId: item.id,
                    contextLabel: item.title,
                    presetPersonId: item.responsiblePersonId,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
