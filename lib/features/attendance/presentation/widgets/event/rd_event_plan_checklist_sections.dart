part of 'rd_event_sections.dart';

// ---------------------------------------------------------------------------
// Ablauf
// ---------------------------------------------------------------------------

/// The Ablauf as a preview (tap: Ablauf ansehen), "Bearbeiten ›" next to
/// the heading and one switch "Für Mitglieder sichtbar"; "Ablauf anlegen"
/// without one. Everyone who edits Termine (Helfer too, like Ionic);
/// Beobachter do not see it. Taking the Ablauf over for the Terminart is
/// in the ••• of the Ablauf editor.
class RdEventPlanSection extends ConsumerStatefulWidget {
  const RdEventPlanSection({
    super.key,
    required this.attendance,
    this.type,
    this.preview,
    this.end = '',
    this.freeMinutes,
  });

  final Attendance attendance;

  /// The Termin's Terminart ("Werke dieser Probe" in the hint).
  final AttendanceType? type;

  /// The Ablauf itself (Reiter Programm).
  final Widget? preview;

  /// "17:35": when the Ablauf ends.
  final String end;

  /// Minutes between the end of the Ablauf and the end of the Termin
  /// ("Ablauf endet 17:35, 20 Min vor Terminende"); null when it fills
  /// the Termin.
  final int? freeMinutes;

  @override
  ConsumerState<RdEventPlanSection> createState() => _RdEventPlanSectionState();
}

class _RdEventPlanSectionState extends ConsumerState<RdEventPlanSection> {
  bool? _share;

  /// [start]: what the editor does first (see [rdPlanStartProvider]).
  void _edit({String? start}) {
    final id = widget.attendance.id;
    if (id == null) return;
    ref.read(rdPlanStartProvider.notifier).state = start == null ? null : (attendanceId: id, action: start);
    context.push<bool>('/planning?attendanceId=$id');
  }

  /// How a new Ablauf starts, besides "Leer beginnen" (the same choices
  /// as in the empty Ablauf editor): with the Werke of the Termin, from a
  /// Vorlage, like the last Termin of the same Terminart. Each row shows
  /// once its data is there.
  List<Widget> _startRows() {
    final l10n = context.l10n;
    final att = widget.attendance;
    final id = att.id;
    if (id == null) return const [];
    final tenantType = ref.watch(currentTenantProvider)?.type;
    final works = rdShowsProgram(ref, widget.type) ? ref.watch(rdEventWorksProvider(id)).valueOrNull : null;
    final songs = {for (final s in ref.watch(songsProvider).valueOrNull ?? const <Song>[]) s.id: s};
    final open = [
      for (final e in works?.entries ?? const <SongHistoryEntry>[])
        if (songs[e.songId] case final song?) song,
    ];
    final types = ref.watch(planAttendanceTypesProvider).valueOrNull ?? const <PlanAttendanceType>[];
    final attendances = ref.watch(planAttendancesProvider).valueOrNull ?? const <PlanAttendance>[];
    final planAtt = attendances.where((a) => a.id == id).firstOrNull ??
        PlanAttendance(id: id, date: att.date, typeId: att.typeId, type: att.type);
    final templates = rdPlanTemplates(
      type: types.where((t) => t.id == att.typeId).firstOrNull,
      auftritt: widget.type?.highlight ?? false,
      tenantType: tenantType,
      orgTemplates: ref.watch(currentOrganisationProvider).valueOrNull?.planningTemplates ?? const [],
      blockTemplates: ref.watch(planBlockTemplatesProvider).valueOrNull ?? const [],
    );
    final previous = rdPreviousPlan(planAtt, attendances);
    final previousDay = previous == null ? null : EventListUtils.parse(previous.att.date);
    return [
      if (open.isNotEmpty)
        RdListRow(
          key: const Key('rd-plan-start-works'),
          leading: const RdRowIcon(Icons.queue_music_outlined),
          title: l10n.redesignPlanStartWorks(rdWorksKind(widget.type)),
          subtitle: rdPlanStartWorksHint(l10n, open),
          onTap: () => _edit(start: 'works'),
        ),
      if (templates.isNotEmpty)
        RdListRow(
          key: const Key('rd-plan-start-template'),
          leading: const RdRowIcon(Icons.view_day_outlined),
          title: l10n.redesignPlanStartTemplate,
          subtitle: l10n.redesignPlanStartTemplateHint(templates.first.name),
          onTap: () async {
            final start = PlanUtils.formatTime(att.startTime ?? widget.type?.startTime);
            final tpl = await showRdPlanTemplateSheet(context, templates, startTime: start);
            if (tpl != null && mounted) _edit(start: 'tpl:$tpl');
          },
        ),
      if (previous != null)
        RdListRow(
          key: const Key('rd-plan-copy-last'),
          leading: const RdRowIcon(Icons.copy_all_outlined),
          title: l10n.rdTextPlanCopyFrom(
            previousDay == null ? previous.att.date : DateFormat(dateFmt()).format(previousDay),
          ),
          subtitle: l10n.rdTextPlanCopyCount(l10n.redesignPlanItemCount(previous.plan.fields.length)),
          onTap: () => _edit(start: 'copy'),
        ),
    ];
  }

  bool _sharing = false;

  Future<void> _toggleShare(bool value) async {
    if (_sharing) return; // one write at a time, see below
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return;
    final container = ProviderScope.containerOf(context, listen: false);
    if (!ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession().isCurrent()) return;
    final id = widget.attendance.id!;
    setState(() {
      _share = value;
      _sharing = true;
    });
    try {
      await repo.updateAttendance(id, {'share_plan': value});
    } catch (e) {
      if (mounted) {
        setState(() => _share = !value);
        ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
      }
    } finally {
      container.invalidate(attendanceDetailProvider(id));
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void didUpdateWidget(RdEventPlanSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The stored value wins again once no write is running.
    if (!_sharing && oldWidget.attendance.sharePlan != widget.attendance.sharePlan) _share = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final att = widget.attendance;
    final hasPlan = attendanceHasPlan(att);
    final share = _share ?? att.sharePlan;
    final role = ref.watch(effectiveRoleProvider);
    // Like Ionic (`@if (!isViewer)`): Helfer edit the Ablauf too,
    // Beobachter do not see it.
    final canEdit = role.canEdit;
    if (role == Role.viewer || (!hasPlan && !canEdit)) return const SizedBox.shrink();
    // The Termin's time stands in the page head: no second time span here,
    // the rows carry their times and the line below names the end.
    final heading = l10n.redesignEventPlanSection;
    final free = widget.freeMinutes;
    // "3 Werke dieser Probe stehen noch nicht im Ablauf": only while the
    // Termin is not over, for those who edit the Ablauf.
    final day = EventListUtils.parse(att.date);
    final now = DateTime.now();
    final coming = day != null && !day.isBefore(DateTime(now.year, now.month, now.day));
    final works = canEdit && hasPlan && coming && att.id != null && rdShowsProgram(ref, widget.type)
        ? ref.watch(rdEventWorksProvider(att.id!)).valueOrNull
        : null;
    final inPlan = {...?rdPlanOf(att)?.fields.map((f) => f.songId).whereType<int>()};
    final missing = works == null ? 0 : {for (final e in works.entries) e.songId}.difference(inPlan).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        if (!hasPlan) ...[
          RdGroupLabel(heading),
          RdGroupedList(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.redesignPlanStartNone, style: RdType.section(p)),
                  const SizedBox(height: 2),
                  Text(l10n.redesignPlanStartAsk, style: RdType.meta(p, size: 14)),
                ],
              ),
            ),
            ..._startRows(),
            RdListRow(
              key: const Key('rd-plan-create'),
              leading: const RdRowIcon(Icons.add),
              title: l10n.redesignPlanStartEmpty,
              onTap: () => _edit(start: 'empty'),
            ),
          ]),
        ] else ...[
          RdSectionLabel(
            heading,
            actionLabel: canEdit ? l10n.redesignEventPlanEditShort : null,
            actionSemantics: l10n.redesignEventPlanEdit,
            actionIcon: Icons.chevron_right,
            onAction: canEdit ? () => _edit() : null,
          ),
          // The preview is the Ablauf: a tap opens it whole (live on the day).
          Semantics(
            button: true,
            label: l10n.redesignEventPlan,
            child: GestureDetector(
              key: const Key('rd-plan-preview'),
              behavior: HitTestBehavior.opaque,
              onTap: () => openAttendancePlanViewer(context, att),
              child: widget.preview ??
                  RdGroupedList(children: [
                    RdListRow(
                      leading: const RdRowIcon(Icons.view_timeline_outlined),
                      title: l10n.redesignEventPlan,
                      onTap: () => openAttendancePlanViewer(context, att),
                    ),
                  ]),
            ),
          ),
          if (free != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.redesignEventPlanEndsEarly(widget.end, free),
                key: const Key('rd-plan-free'),
                style: RdType.meta(p, size: 13),
              ),
            ),
          ],
          if (missing > 0) ...[
            const SizedBox(height: 12),
            Material(
              color: p.lateSoft,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('rd-plan-works-missing'),
                onTap: () => _edit(start: 'works'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.music_note, size: 20, color: p.late),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.redesignEventWorksMissing(rdWorksKind(widget.type), missing),
                          style: TextStyle(fontSize: 14, color: p.text, height: 1.3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.redesignEventWorksMissingInsert,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.late),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (canEdit) ...[
            const SizedBox(height: 12),
            RdGroupedList(children: [
              RdListRow(
                key: const Key('rd-plan-share'),
                title: l10n.redesignEventPlanShare,
                showChevron: false,
                onTap: _sharing ? null : () => _toggleShare(!share),
                trailing: Switch.adaptive(value: share, onChanged: _sharing ? null : _toggleShare),
              ),
            ]),
          ],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Vorbereitung (Checkliste)
// ---------------------------------------------------------------------------

/// "Vorbereitung": what the Leitung has to get done before the Termin
/// (the Termin's checklist). Tick off, "+ Aufgabe", delete. A new Termin
/// already carries the tasks of its Terminart (Verwaltung › Terminarten);
/// without any the section explains itself and, when the Terminart has
/// tasks, offers to take them over.
class RdEventChecklistSection extends ConsumerStatefulWidget {
  const RdEventChecklistSection({super.key, required this.attendance, this.type, this.canEdit = true});

  final Attendance attendance;

  /// Leitung: tick off, add, delete; others with view permission only read.
  final bool canEdit;

  /// The Termin's Terminart: its tasks can be taken over into an empty list.
  final AttendanceType? type;

  @override
  ConsumerState<RdEventChecklistSection> createState() => _RdEventChecklistSectionState();
}

class _RdEventChecklistSectionState extends ConsumerState<RdEventChecklistSection> {
  /// Local list while a write is in flight (or after it failed: the
  /// stored one comes back with the next refresh).
  List<ChecklistItem>? _local;

  List<ChecklistItem> get _items => _local ?? widget.attendance.checklist ?? const [];

  /// Writes still running; they run one after another (each sends the
  /// whole list) so a later tick never loses to an earlier one.
  int _pending = 0;
  Future<void> _queue = Future.value();

  @override
  void didUpdateWidget(RdEventChecklistSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pending == 0 && oldWidget.attendance.checklist != widget.attendance.checklist) _local = null;
  }

  Future<void> _save(List<ChecklistItem> items) {
    setState(() => _local = items);
    _pending++;
    final write = rdChecklistWriter(context, ref, widget.attendance.id!);
    final done = _queue.then((_) => write(items)).then((ok) {
      _pending--;
      // Failed: show the stored list again once nothing else is pending.
      if (!ok && _pending == 0 && mounted) setState(() => _local = null);
    });
    _queue = done;
    return done;
  }

  Future<void> _add() async {
    final item = await rdAskChecklistItem(context, widget.attendance);
    if (item == null || !mounted) return;
    await _save([..._items, item]);
  }

  Future<void> _takeOverTemplate() async {
    final type = widget.type;
    if (type == null) return;
    await _save(rdDefaultChecklist(type, widget.attendance));
  }

  Future<void> _delete(int index) async {
    final l10n = context.l10n;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: l10n.attendanceFlutterDeleteTodoTitle,
      message: l10n.attendanceDeleteTodoConfirm,
      confirmText: l10n.commonDelete,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    await _save([..._items]..removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final items = _items;
    if (items.isEmpty) {
      final templateCount = widget.type?.checklist?.length ?? 0;
      return Column(
        key: const Key('rd-event-prep-empty'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdSectionLabel(
            l10n.redesignEventPrepTitle,
            actionLabel: l10n.redesignEventAddTask,
            actionSemantics: l10n.redesignEventAddTaskLabel,
            onAction: _add,
          ),
          RdCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.redesignEventPrepEmpty, style: RdType.meta(p, size: 14)),
                if (templateCount > 0) ...[
                  const SizedBox(height: 10),
                  RdPillButton(
                    key: const Key('rd-event-prep-template'),
                    icon: Icons.playlist_add_check_rounded,
                    label: l10n.redesignEventPrepTakeOver(templateCount),
                    onPressed: _takeOverTemplate,
                  ),
                ],
              ],
            ),
          ),
          if (_local != null && _local != widget.attendance.checklist)
            LinearProgressIndicator(minHeight: 2, color: p.primary, backgroundColor: p.track),
        ],
      );
    }
    final done = items.where((i) => i.completed).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdSectionLabel(
          l10n.redesignEventPrep('$done', '${items.length}'),
          actionLabel: widget.canEdit ? l10n.redesignEventAddTask : null,
          actionSemantics: l10n.redesignEventAddTaskLabel,
          onAction: widget.canEdit ? _add : null,
        ),
        RdGroupedList(children: [
          for (var i = 0; i < items.length; i++)
            _ChecklistRow(
              key: ValueKey('rd-check-${items[i].id}'),
              item: items[i],
              onToggle: !widget.canEdit
                  ? null
                  : () {
                      HapticHelper.light();
                      final next = [...items];
                      next[i] = items[i].copyWith(completed: !items[i].completed);
                      _save(next);
                    },
              onDelete: widget.canEdit ? () => _delete(i) : null,
            ),
        ]),
        if (_local != null && _local != widget.attendance.checklist)
          LinearProgressIndicator(minHeight: 2, color: p.primary, backgroundColor: p.track),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({super.key, required this.item, required this.onToggle, required this.onDelete});

  final ChecklistItem item;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final due = rdChecklistDue(item);
    final dueText = item.completed ? '' : rdChecklistDueText(l10n, item);
    return Semantics(
      checked: item.completed,
      child: InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: item.completed ? p.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: item.completed ? p.primary : p.text2, width: 2),
                  ),
                  child: item.completed ? Icon(Icons.check, size: 15, color: p.onPrimary) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: item.completed ? p.text2 : p.text,
                      decoration: item.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (dueText.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  RdPill(
                    dueText,
                    tone: switch (due) {
                      RdDue.overdue => RdTone.absent,
                      RdDue.soon => RdTone.late,
                      RdDue.none => null,
                    },
                  ),
                ],
                if (onDelete != null)
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: p.text2),
                    tooltip: l10n.redesignEventDeleteTask,
                    onPressed: onDelete,
                  )
                else
                  const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Writes the checklist of [attendanceId] (whole list, like the Termin page).
Future<void> rdSaveChecklist(BuildContext context, WidgetRef ref, int attendanceId, List<ChecklistItem> items) =>
    rdChecklistWriter(context, ref, attendanceId)(items);

/// Binds repository and provider container now, so the write still
/// finishes (and refreshes the Termin) when the page is left meanwhile.
/// The returned writer answers false when the write failed.
Future<bool> Function(List<ChecklistItem>) rdChecklistWriter(BuildContext context, WidgetRef ref, int attendanceId) {
  final repo = ref.read(attendanceRepositoryWithTenantProvider);
  final container = ProviderScope.containerOf(context, listen: false);
  // #232: a queued write of a signed-out / switched account is dropped.
  final session = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
  return (items) async {
    if (!repo.hasTenantId || !session.isCurrent()) return false;
    var ok = true;
    try {
      await repo.updateAttendance(attendanceId, {'checklist': [for (final i in items) i.toJson()]});
    } catch (e) {
      ok = false;
      if (context.mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterSaveFailedWith(friendlyErrorMessage(e)));
      }
    }
    container.invalidate(attendanceDetailProvider(attendanceId));
    return ok;
  };
}

/// "Aufgabe hinzufügen": text and optional "Stunden vorher" (Termin page dialog).
Future<ChecklistItem?> rdAskChecklistItem(BuildContext context, Attendance attendance) async {
  final l10n = context.l10n;
  final text = TextEditingController();
  final hours = TextEditingController();
  final result = await showAppDialog<({String text, int? hours})>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(l10n.attendanceAddTodo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: text,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l10n.attendanceTodoText),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: hours,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: l10n.attendanceDeadlineHours),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
        TextButton(
          onPressed: () {
            if (text.text.trim().isEmpty) {
              ToastHelper.showWarning(ctx, l10n.attendanceEnterText);
              return;
            }
            Navigator.pop(ctx, (text: text.text.trim(), hours: int.tryParse(hours.text.trim())));
          },
          child: Text(l10n.attendanceAdd),
        ),
      ],
    ),
  );
  text.dispose();
  hours.dispose();
  if (result == null) return null;
  return rdNewChecklistItem(result.text, result.hours, rdChecklistEventStart(attendance));
}
