import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../../../../l10n/l10n.dart';
import '../../team_org_utils.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/tasks_tab.dart' show TeamOrgBadge, priorityColor, outcomeColor;
import '../widgets/quick_create_attendance.dart';
import '../../../../core/services/error_reporter.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

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
      ToastHelper.showWarning(context, context.l10n.agendaEnterTitle);
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
      if (mounted) ToastHelper.showSuccess(context, context.l10n.dutySaved);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.agendaSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.agendaDeleteConfirm,
      message: context.l10n.agendaDeleteMessage,
      confirmText: context.l10n.commonDelete,
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(agendaItemNotifierProvider.notifier).delete(_itemId);
      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.agendaDeleted);
      context.go('/settings/team-organization?tab=topics');
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.agendaDeleteFailed);
    }
  }

  Future<void> _planInto(AgendaItem item) async {
    final protocolRepo = ref.read(protocolRepositoryWithTenantProvider);
    final types = await ref.read(protocolTypesProvider.future);
    List<ProtocolAttendance> upcoming = [];
    try {
      upcoming = (await ref.read(upcomingProtocolAttendancesProvider.future)).take(_planChoices).toList();
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'agenda_item_detail_page');
    }
    if (!mounted) return;
    final fid = agendaFieldId(item.id!);
    ProtocolType? typeOf(ProtocolAttendance a) {
      for (final t in types) {
        if (t.id == a.typeId) return t;
      }
      return null;
    }

    var choice = await showAppActionSheet<Object>(
      context,
      title: upcoming.isNotEmpty
          ? context.l10n.agendaWhichEvent
          : context.l10n.agendaNoProtocolEvent,
      actions: [
        for (final att in upcoming)
          AppActionSheetAction(
            value: att,
            enabled: !att.fields.any((f) => fieldId(f) == fid),
            label:
                '${formatShortWeekdayDate(att.date)} · ${attendanceTitle(att.typeInfo, typeOf(att))}${att.fields.any((f) => fieldId(f) == fid) ? context.l10n.agendaAlreadyPlanned : ''}',
          ),
        AppActionSheetAction(
          value: 'new',
          icon: Icons.add_circle_outline,
          label: context.l10n.agendaNewEvent,
        ),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == 'new') {
      // Ionic `planIntoNewAttendance`: create a Termin ad hoc and plan the topic into it.
      final id = await promptCreateProtocolAttendance(context, ref);
      if (id == null || !mounted) return;
      ProtocolAttendance? created;
      try {
        created = await protocolRepo.getAttendance(id);
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'agenda_item_detail_page');
      }
      if (created == null || !mounted) return;
      choice = created;
    }
    if (choice is ProtocolAttendance) {
      final type = typeOf(choice);
      try {
        await addTopicsToAttendance(protocolRepo, choice, type,
            [(item: item, duration: defaultTopicDuration(item, type))]);
        ref.invalidate(upcomingProtocolAttendancesProvider);
        ref.invalidate(agendaItemHistoryProvider(_itemId));
        // P10_SONGS_ORG: plan caches follow every topic write (SOL_FIX33),
        // so a planning editor opened afterwards shows the new TOP.
        ref.invalidate(planAttendancesProvider);
        ref.invalidate(orgPlansProvider);
        final d = DateTime.tryParse(choice.date)?.toLocal();
        if (mounted) {
          ToastHelper.showSuccess(
            context,
            context.l10n.agendaPlannedFor(d != null ? DateFormat(dateFmt(DateFmtKind.dayMonth)).format(d) : ''),
          );
        }
      } catch (_) {
        if (mounted) ToastHelper.showError(context, context.l10n.agendaPlanFailed);
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.agendaNewTopic : l10n.agendaTopic),
        actions: [
          if (!_isNew && item != null && isLeader)
            IconButton(
              tooltip: l10n.agendaDeleteTopic,
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: _delete,
            ),
        ],
      ),
      floatingActionButton: TabBarFab.wrap(isLeader && (item != null || _isNew)
          ? FloatingActionButton(
              tooltip: l10n.commonSave,
              onPressed: _saving ? null : _save,
              child: const Icon(Icons.save_outlined),
            )
          : null),
      // P10_SONGS_ORG: keep the form while the item reloads after a save.
      body: itemAsync.isLoading && !itemAsync.hasValue
          ? const Center(child: AppSpinner())
          : (!_isNew && item == null)
              ? Center(child: Text(l10n.agendaFlutterNotFound))
              : ListView(
                  padding: EdgeInsets.only(
                      bottom: isLeader
                          ? scrollEndPadding(context, base: 16, fabRoom: 80)
                          : scrollEndPadding(context, base: 32)),
                  children: [
                    if (isLeader) ..._leaderForm() else ..._readOnly(item!),
                    if (item != null && item.proposer.fullName.isNotEmpty)
                      IonInsetList(children: [
                        ListTile(
                          leading: const Icon(Icons.lightbulb_outline, color: AppColors.medium),
                          title: Text(l10n.agendaProposedBy(item.proposer.fullName),
                              style: const TextStyle(fontSize: 15)),
                          subtitle: item.decisionNote?.isNotEmpty == true
                              ? Text(item.decisionNote!, style: const TextStyle(color: AppColors.medium))
                              : null,
                        ),
                      ]),
                    if (!_isNew && isLeader && item?.status == 'open')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: FilledButton.icon(
                          onPressed: () => _planInto(item!),
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: IonButtonLabel(l10n.agendaPlanIn),
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
    final l10n = context.l10n;
    // Ionic: inset list (stacked title + description), then an inset list
    // with popover selects and the inline duration input.
    return [
      IonInsetList(
        children: [
          IonStackedInput(controller: _title, label: l10n.plansTitle, hint: l10n.agendaTitlePlaceholder),
          IonStackedInput(
            controller: _description,
            label: l10n.agendaDescription,
            hint: l10n.agendaDescriptionPlaceholder,
            minLines: 3,
            maxLines: 10,
          ),
        ],
      ),
      IonInsetList(
        children: [
          IonSelect<String>(
            label: l10n.agendaStatus,
            value: _status,
            items: const ['open', 'completed', 'dropped']
                .map((s) => DropdownMenuItem(value: s, child: Text(topicStatusLabels[s]!)))
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? 'open'),
          ),
          IonSelect<String>(
            label: l10n.agendaPriority,
            value: _priority,
            items: const ['high', 'medium', 'low']
                .map((p) => DropdownMenuItem(value: p, child: Text(priorityLabels[p]!)))
                .toList(),
            onChanged: (v) => setState(() => _priority = v ?? 'medium'),
          ),
          IonSelect<int?>(
            label: l10n.agendaResponsible,
            value: responsibleValid ? _responsibleId : null,
            items: [
              DropdownMenuItem<int?>(value: null, child: Text(l10n.agendaNobody)),
              for (final p in persons) DropdownMenuItem<int?>(value: p.id, child: Text(p.fullName)),
            ],
            onChanged: (v) => setState(() => _responsibleId = v),
          ),
          IonInlineInput(
            controller: _duration,
            label: l10n.agendaDurationPerSession,
            hint: l10n.agendaDefault,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    ];
  }

  List<Widget> _readOnly(AgendaItem item) => [
        IonInsetList(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ionic `.topic-title`: 20px / 600
                  Text(item.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, children: [
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
                ],
              ),
            ),
            if (item.responsiblePerson.fullName.isNotEmpty)
              ListTile(
                title: Text(context.l10n.agendaResponsible),
                trailing: IonNote(item.responsiblePerson.fullName),
              ),
            if (item.description?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(item.description!, style: const TextStyle(color: AppColors.medium)),
              ),
          ],
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

    final l10n = context.l10n;
    ({String label, Color color}) status(AgendaItemHistoryEntry e) {
      if (e.outcome != null) return (label: outcomeLabels[e.outcome] ?? e.outcome!, color: outcomeColor(e.outcome));
      final d = DateTime.tryParse(e.date ?? '')?.toLocal();
      if (d != null && !d.isBefore(startOfToday)) return (label: l10n.agendaPlanned, color: AppColors.primary);
      return (label: l10n.agendaNoOutcome, color: AppColors.medium);
    }

    return IonInsetList(
      header: l10n.agendaHistory,
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
                '${attendanceTitle(e.typeInfo, type)} · ${d != null ? DateFormat(dateFmt()).format(d) : ''}',
                style: const TextStyle(fontSize: 15),
              ),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                TeamOrgBadge(label: s.label, color: s.color),
                const SizedBox(width: 4),
                const IonDetailIcon(),
              ]),
              onTap: e.attendanceId == null ? null : () => context.push('/settings/protocol/${e.attendanceId}'),
            );
          }),
        if (history.isEmpty)
          ListTile(
            title: Text(l10n.agendaNotDiscussed, style: const TextStyle(color: AppColors.medium)),
          ),
      ],
    );
  }
}

class _TasksSection extends ConsumerWidget {
  const _TasksSection({required this.item, required this.isLeader});
  final AgendaItem item;
  final bool isLeader;

  String _subtitle(AppLocalizations l10n, TeamTask t) {
    final who = t.responsiblePerson.fullName.isNotEmpty ? t.responsiblePerson.fullName : l10n.attendanceNobodyAssigned;
    final fmt = DateFormat(dateFmt(DateFmtKind.dayMonth));
    if (t.status == 'completed') {
      final d = DateTime.tryParse(t.completedAt ?? '')?.toLocal();
      return d != null ? l10n.agendaDoneOn(who, fmt.format(d)) : l10n.agendaDone(who);
    }
    final due = DateTime.tryParse(t.dueDate ?? '');
    return due != null ? l10n.agendaDueOn(who, fmt.format(due)) : who;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksForAgendaItemProvider(item.id!)).valueOrNull ?? const <TeamTask>[];
    final done = tasks.where((t) => t.status == 'completed').length;
    final l10n = context.l10n;
    return IonInsetList(
      header: l10n.agendaTasks,
      headerTrailing: tasks.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 4),
              child: IonNote(l10n.agendaTasksDone(done, tasks.length), style: const TextStyle(fontSize: 13)),
            )
          : null,
      children: [
        for (final t in tasks)
          ListTile(
            leading: Icon(
              t.status == 'completed' ? Icons.check_circle : Icons.radio_button_unchecked,
              color: t.status == 'completed' ? AppColors.success : AppColors.medium,
            ),
            title: Text(
              t.title,
              style: t.status == 'completed'
                  ? const TextStyle(fontSize: 15, decoration: TextDecoration.lineThrough, color: AppColors.medium)
                  : const TextStyle(fontSize: 15),
            ),
            subtitle: Text(_subtitle(l10n, t), style: const TextStyle(color: AppColors.medium)),
            trailing: const IonDetailIcon(),
            onTap: () => context.push('/settings/tasks/${t.id}'),
          ),
        if (tasks.isEmpty) ListTile(title: Text(l10n.agendaNoTasks, style: const TextStyle(color: AppColors.medium))),
        if (isLeader)
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            title: Text(l10n.agendaAddTask, style: const TextStyle(color: AppColors.primary)),
            onTap: () => showTaskFormSheet(
              context,
              agendaItemId: item.id,
              contextLabel: item.title,
              presetPersonId: item.responsiblePersonId,
            ),
          ),
      ],
    );
  }
}
