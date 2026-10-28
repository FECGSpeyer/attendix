import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../team_org_utils.dart';
import 'agenda_picker_sheet.dart';
import 'quick_create_attendance.dart';
import 'tasks_tab.dart' show TeamOrgBadge, TeamOrgListSkeleton, priorityColor;

/// Tab "Themen": leadership reviews suggestions, plans the next Termin and
/// keeps the Themenspeicher; members suggest topics and see their suggestions.
class TopicsTab extends ConsumerWidget {
  const TopicsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLeader = ref.watch(isTeamLeaderProvider);
    if (isLeader) return const _LeaderTopics();
    if (ref.watch(inTeamCircleProvider)) return const _MemberTopics();
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 56, color: AppColors.medium),
            SizedBox(height: AppDimensions.paddingM),
            Text(
              'Themen und Tagesordnungen plant die Leitung. Du gehörst zu keiner Gruppe mit Protokoll & Tagesordnung.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Leadership ───────────────────────────────────────────────

class _LeaderTopics extends ConsumerStatefulWidget {
  const _LeaderTopics();

  @override
  ConsumerState<_LeaderTopics> createState() => _LeaderTopicsState();
}

class _LeaderTopicsState extends ConsumerState<_LeaderTopics> {
  int? _chosenAttendanceId;
  bool _showDone = false;
  final Set<String> _deciding = {};

  ProtocolType? _typeOf(ProtocolAttendance att, List<ProtocolType> types) {
    for (final t in types) {
      if (t.id == att.typeId) return t;
    }
    return null;
  }

  String _attendanceTitle(ProtocolAttendance att, List<ProtocolType> types) =>
      '${attendanceTitle(att.typeInfo, _typeOf(att, types))} · ${formatShortWeekdayDate(att.date)}';

  Future<void> _changeAttendance(
      List<ProtocolAttendance> upcoming, ProtocolAttendance? current, List<ProtocolType> types) async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Für welchen Termin planen?')),
            for (final att in upcoming.take(8))
              ListTile(
                title: Text(_attendanceTitle(att, types)),
                trailing: att.id == current?.id ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(ctx).pop(att.id),
              ),
            if (current != null)
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Datum dieses Termins ändern'),
                onTap: () => Navigator.of(ctx).pop('date'),
              ),
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
    if (choice is int) {
      setState(() => _chosenAttendanceId = choice);
    } else if (choice == 'date' && current != null) {
      // Date changes happen on the attendance page.
      await context.push('/attendance/${current.id}');
      ref.invalidate(upcomingProtocolAttendancesProvider);
    } else if (choice == 'new') {
      await _createAttendance();
    }
  }

  /// "Termin anlegen" (Ionic `createAttendance`): quick-create and select it.
  Future<void> _createAttendance() async {
    final id = await promptCreateProtocolAttendance(context, ref);
    if (id == null || !mounted) return;
    setState(() => _chosenAttendanceId = id);
    ref.invalidate(upcomingProtocolAttendancesProvider);
  }

  Future<void> _topAction(PlanField top, ProtocolAttendance att, ProtocolType? type) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(fieldName(top), style: Theme.of(ctx).textTheme.titleSmall)),
            ListTile(title: const Text('Thema öffnen'), onTap: () => Navigator.of(ctx).pop('open')),
            ListTile(
              title: const Text('Aus diesem Termin entfernen', style: TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.of(ctx).pop('remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    final agendaId = fieldAgendaItemId(top);
    if (action == 'open' && agendaId != null) {
      context.push('/settings/agenda-items/$agendaId');
    } else if (action == 'remove' && agendaId != null) {
      try {
        await addTopicsToAttendance(ref.read(protocolRepositoryWithTenantProvider), att, type, const [],
            removeIds: [agendaId]);
        ref.invalidate(upcomingProtocolAttendancesProvider);
        if (mounted) ToastHelper.showInfo(context, 'Aus dem Termin entfernt, bleibt im Themenspeicher');
      } catch (_) {
        if (mounted) ToastHelper.showError(context, 'Thema konnte nicht entfernt werden');
      }
    }
  }

  Future<void> _accept(AgendaItem item) async {
    var priority = item.priority;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Vorschlag übernehmen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mit welcher Priorität kommt das Thema in den Themenspeicher?'),
              for (final p in const ['high', 'medium', 'low'])
                RadioListTile<String>(
                  value: p,
                  groupValue: priority,
                  title: Text(priorityLabels[p]!),
                  onChanged: (v) => setLocal(() => priority = v ?? 'medium'),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Übernehmen')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _decide(item, {'proposal_status': 'accepted', 'priority': priority, 'decision_note': null}, 'Übernommen');
  }

  Future<void> _reject(AgendaItem item) async {
    final controller = TextEditingController();
    final name = item.proposer.fullName.isNotEmpty ? item.proposer.fullName : 'Die Person';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vorschlag ablehnen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$name wird informiert. Eine kurze Begründung hilft.'),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Begründung (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Ablehnen')),
        ],
      ),
    );
    final note = controller.text.trim();
    controller.dispose();
    if (ok != true) return;
    await _decide(item, {'proposal_status': 'rejected', 'decision_note': note.isEmpty ? null : note}, 'Abgelehnt');
  }

  Future<void> _decide(AgendaItem item, Map<String, dynamic> changes, String doneText) async {
    final id = item.id;
    if (id == null || _deciding.contains(id)) return;
    setState(() => _deciding.add(id));
    try {
      await ref.read(agendaItemNotifierProvider.notifier).decide(id, changes);
      if (mounted) ToastHelper.showSuccess(context, doneText);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Entscheidung konnte nicht gespeichert werden');
    } finally {
      if (mounted) setState(() => _deciding.remove(id));
    }
  }

  Future<void> _openReview() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final items = ref.watch(agendaItemsProvider).valueOrNull ?? const <AgendaItem>[];
        final pending = splitTopics(items).pending;
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: Column(
            children: [
              AppBar(
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Schließen',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                title: const Text('Vorschläge'),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  children: [
                    const Text(
                      'Übernommene Vorschläge landen im Themenspeicher. Wer vorgeschlagen hat, wird über deine Entscheidung informiert.',
                    ),
                    const SizedBox(height: AppDimensions.paddingM),
                    if (pending.isEmpty) const Text('Alle Vorschläge sind entschieden.'),
                    for (final item in pending)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.paddingM),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    child: Text(item.proposer.initials.isNotEmpty ? item.proposer.initials : '?'),
                                  ),
                                  const SizedBox(width: AppDimensions.paddingS),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.proposer.fullName.isNotEmpty ? item.proposer.fullName : 'Mitglied'),
                                        Text(relativeDay(item.createdAt), style: Theme.of(ctx).textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDimensions.paddingS),
                              Text(item.title, style: Theme.of(ctx).textTheme.titleMedium),
                              if (item.description?.isNotEmpty == true) Text(item.description!),
                              const SizedBox(height: AppDimensions.paddingS),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: _deciding.contains(item.id) ? null : () => _reject(item),
                                    child: const Text('Ablehnen'),
                                  ),
                                  const SizedBox(width: AppDimensions.paddingS),
                                  FilledButton(
                                    onPressed: _deciding.contains(item.id) ? null : () => _accept(item),
                                    child: const Text('Übernehmen'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _topicSubtitle(AgendaItem item) {
    final parts = [
      item.responsiblePerson.fullName.isNotEmpty ? item.responsiblePerson.fullName : 'Noch niemand verantwortlich',
    ];
    if (item.proposedBy != null) {
      final by = item.proposer.fullName;
      parts.add(by.isNotEmpty ? 'Vorschlag von $by' : 'Vorschlag');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(agendaItemsProvider);
    final protocols = ref.watch(protocolsProvider).valueOrNull ?? const <Protocol>[];
    final upcoming = ref.watch(upcomingProtocolAttendancesProvider).valueOrNull ?? const <ProtocolAttendance>[];
    final types = ref.watch(protocolTypesProvider).valueOrNull ?? const <ProtocolType>[];

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'team-org-add-topic',
        tooltip: 'Thema anlegen',
        onPressed: () => context.push('/settings/agenda-items/new'),
        child: const Icon(Icons.add),
      ),
      body: itemsAsync.when(
        loading: () => const TeamOrgListSkeleton(), // Ionic ion-skeleton-text (3 rows)
        error: (_, __) => const Center(child: Text('Themen konnten nicht geladen werden')),
        data: (items) {
          final postponed = postponedAgendaItemIds(protocols);
          final buckets = splitTopics(items);
          final openTopics = sortTopicsForPlanning(buckets.open, postponed);
          ProtocolAttendance? next;
          for (final a in upcoming) {
            if (a.id == _chosenAttendanceId) next = a;
          }
          next ??= upcoming.isNotEmpty ? upcoming.first : null;
          final nextType = next != null ? _typeOf(next, types) : null;
          final tops = planTops(next?.fields);
          final numbers = topNumbers(next?.fields);
          final nextAgendaIds = tops.tops.map(fieldAgendaItemId).toSet();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(agendaItemsProvider);
              ref.invalidate(protocolsProvider);
              ref.invalidate(upcomingProtocolAttendancesProvider);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingM, AppDimensions.paddingS, AppDimensions.paddingM, 96),
              children: [
                if (buckets.pending.isNotEmpty)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.lightbulb_outline, color: AppColors.warning),
                      title: Text(buckets.pending.length == 1
                          ? '1 neuer Vorschlag'
                          : '${buckets.pending.length} neue Vorschläge'),
                      subtitle: const Text('Von Mitgliedern eingereicht'),
                      trailing: FilledButton.tonal(onPressed: _openReview, child: const Text('Prüfen')),
                      onTap: _openReview,
                    ),
                  ),
                _sectionHeader(
                  context,
                  next != null && next.id != upcoming.first.id ? 'Gewählter Termin' : 'Nächster Termin',
                  trailing: next != null
                      ? TextButton(
                          onPressed: () => _changeAttendance(upcoming, next, types),
                          child: const Text('Ändern'),
                        )
                      : null,
                ),
                Card(
                  margin: EdgeInsets.zero,
                  child: next == null
                      ? Column(
                          children: [
                            const ListTile(
                              title: Text('Kein Termin mit Protokoll & Tagesordnung geplant.',
                                  style: TextStyle(color: AppColors.medium)),
                            ),
                            ListTile(
                              leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                              title: const Text('Termin anlegen', style: TextStyle(color: AppColors.primary)),
                              onTap: _createAttendance,
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                              title: Text(_attendanceTitle(next, types)),
                              trailing: tops.minutes > 0 ? Text('${tops.minutes} min') : null,
                              onTap: () => context.push('/attendance/${next!.id}'),
                            ),
                            for (final top in tops.tops)
                              ListTile(
                                title: Text('TOP ${numbers[fieldId(top)] ?? 0} · ${fieldName(top)}'),
                                subtitle: fieldConductor(top) != null ? Text(fieldConductor(top)!) : null,
                                trailing: Text('${fieldMinutes(top)} min'),
                                onTap: () => _topAction(top, next!, nextType),
                              ),
                            if (tops.tops.isEmpty)
                              const ListTile(
                                title: Text('Noch keine Themen auf der Tagesordnung.',
                                    style: TextStyle(color: AppColors.medium)),
                              ),
                            ListTile(
                              leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                              title: const Text('Themen aufnehmen', style: TextStyle(color: AppColors.primary)),
                              onTap: () async {
                                await showAgendaPickerSheet(context, attendance: next!, type: nextType);
                              },
                            ),
                          ],
                        ),
                ),
                _sectionHeader(context, 'Themenspeicher', trailing: Text('${openTopics.length} offen')),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final item in openTopics)
                        ListTile(
                          title: Text(item.title),
                          subtitle: Text.rich(TextSpan(children: [
                            if (postponed.contains(item.id))
                              const TextSpan(text: 'vertagt · ', style: TextStyle(color: AppColors.warningDark)),
                            if (nextAgendaIds.contains(item.id))
                              const TextSpan(text: 'eingeplant · ', style: TextStyle(color: AppColors.primary)),
                            TextSpan(text: _topicSubtitle(item)),
                          ])),
                          trailing: TeamOrgBadge(
                            label: priorityLabels[item.priority] ?? item.priority,
                            color: priorityColor(item.priority),
                          ),
                          onTap: () => context.push('/settings/agenda-items/${item.id}'),
                        ),
                      if (openTopics.isEmpty)
                        const ListTile(
                          title: Text('Keine offenen Themen. Lege mit + ein neues an.',
                              style: TextStyle(color: AppColors.medium)),
                        ),
                    ],
                  ),
                ),
                if (buckets.done.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(top: AppDimensions.paddingM),
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _showDone,
                          onChanged: (v) => setState(() => _showDone = v),
                          title: Text('Erledigte anzeigen (${buckets.done.length})'),
                        ),
                        if (_showDone)
                          for (final item in buckets.done)
                            ListTile(
                              title: Text(item.title, style: const TextStyle(color: AppColors.medium)),
                              subtitle: Text([
                                item.status == 'dropped' ? 'Verworfen' : 'Erledigt',
                                if (item.responsiblePerson.fullName.isNotEmpty) item.responsiblePerson.fullName,
                              ].join(' · ')),
                              onTap: () => context.push('/settings/agenda-items/${item.id}'),
                            ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Widget _sectionHeader(BuildContext context, String title, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.only(top: AppDimensions.paddingM, bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
          if (trailing != null) trailing,
        ],
      ),
    );

// ── Members ──────────────────────────────────────────────────

class _MemberTopics extends ConsumerWidget {
  const _MemberTopics();

  Future<void> _suggest(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _SuggestSheet(),
    );
    if (result == true && context.mounted) ToastHelper.showSuccess(context, 'Vorschlag gesendet');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(agendaItemsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(agendaItemsProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thema vorschlagen', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text(
                      'Du hast ein Anliegen für die nächste Sitzung? Die Leitung entscheidet, ob es auf die Tagesordnung kommt.'),
                  const SizedBox(height: AppDimensions.paddingM),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _suggest(context, ref),
                      icon: const Icon(Icons.lightbulb_outline),
                      label: const Text('Thema vorschlagen'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _sectionHeader(context, 'Meine Vorschläge'),
          itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Themen konnten nicht geladen werden'),
            data: (items) {
              final sorted = [...items]..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
              if (sorted.isEmpty) {
                return const Card(
                  child: ListTile(
                    title: Text('Du hast noch nichts vorgeschlagen.', style: TextStyle(color: AppColors.medium)),
                  ),
                );
              }
              return Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final item in sorted)
                      ListTile(
                        title: Text(item.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.proposalStatus == 'accepted'
                                ? 'Von der Leitung übernommen'
                                : 'Eingereicht am ${_date(item.createdAt)}'),
                            if (item.proposalStatus == 'rejected' && item.decisionNote?.isNotEmpty == true)
                              Text('„${item.decisionNote}“', style: const TextStyle(fontStyle: FontStyle.italic)),
                          ],
                        ),
                        trailing: TeamOrgBadge(
                          label: suggestionStatusLabel(item),
                          color: switch (item.proposalStatus) {
                            'accepted' => AppColors.success,
                            'rejected' => AppColors.danger,
                            _ => AppColors.medium,
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    return d == null ? '' : DateFormat('dd.MM.yyyy').format(d);
  }
}

class _SuggestSheet extends ConsumerStatefulWidget {
  const _SuggestSheet();

  @override
  ConsumerState<_SuggestSheet> createState() => _SuggestSheetState();
}

class _SuggestSheetState extends ConsumerState<_SuggestSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ToastHelper.showWarning(context, 'Bitte einen Titel eingeben');
      return;
    }
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final desc = _description.text.trim();
      await ref.read(agendaItemNotifierProvider.notifier).propose(title, desc.isEmpty ? null : desc);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Vorschlag konnte nicht gesendet werden');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            automaticallyImplyLeading: false,
            leading: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
            leadingWidth: 100,
            title: const Text('Thema vorschlagen'),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              children: [
                const Text(
                    'Du hast ein Anliegen für die nächste Sitzung? Die Leitung entscheidet, ob es auf die Tagesordnung kommt.'),
                const SizedBox(height: AppDimensions.paddingM),
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Titel', hintText: 'z. B. Neue Notenpulte'),
                ),
                const SizedBox(height: AppDimensions.paddingS),
                TextField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Beschreibung', hintText: 'Worum geht es? (optional)'),
                ),
                const SizedBox(height: AppDimensions.paddingM),
                SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _title.text.trim().isEmpty || _sending ? null : _send,
                      child: const Text('Vorschlag senden'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
