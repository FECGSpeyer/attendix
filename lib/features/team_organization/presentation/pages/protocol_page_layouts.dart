part of 'protocol_page.dart';

extension _ProtocolPageLayouts on _ProtocolPageState {
  /// Beta, wide: two columns like the other Beta split views. Left the
  /// overview, right one large writing surface.
  Widget _buildBetaWide(BuildContext context) {
    final map = _taskSectionMap;
    _Section? active;
    for (final s in _sections) {
      if (s.id == _activeId) active = s;
    }
    _Leftover? activeLeftover;
    for (final l in _leftovers) {
      if (l.key == _activeId) activeLeftover = l;
    }
    final Widget pane;
    if (_sidePane == 'general') {
      pane = _betaGeneralPane(map);
    } else if (_sidePane == 'tasks') {
      pane = _betaTasksPane(map);
    } else if (active != null) {
      pane = _betaPointPane(active, map);
    } else if (activeLeftover != null) {
      pane = _betaLeftoverPane(activeLeftover, map);
    } else {
      pane = ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 20, 20),
        children: [
          RdInfoCard(
            icon: Icons.list,
            text: _sections.isNotEmpty
                ? context.l10n.protocolFlutterChooseLeft
                : context.l10n.protocolFlutterPlanEmptyShort,
            action: RdOutlineButton(label: context.l10n.protocolAddPoint, onPressed: _addSpontaneousTopic),
          ),
        ],
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final sideWidth = (constraints.maxWidth * 0.32).clamp(300.0, 380.0);
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown, control: true): _nextSection,
          const SingleActivator(LogicalKeyboardKey.arrowDown, meta: true): _nextSection,
          const SingleActivator(LogicalKeyboardKey.arrowUp, control: true): _previousSection,
          const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): _previousSection,
        },
        child: Focus(
          focusNode: _pageFocus,
          autofocus: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: sideWidth, child: _betaSide(map)),
              Expanded(child: pane),
            ],
          ),
        ),
      );
    });
  }

  /// Beta, phone: three buttons for what belongs to the whole meeting,
  /// then the points; only "Abschließen" stays in the footer.
  Widget _buildBetaEditLayout(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final map = _taskSectionMap;
    final unassigned = _unassignedTasks(map);
    final activeIndex = _sections.indexWhere((s) => s.id == _activeId);
    final hasNext = activeIndex >= 0 && activeIndex + 1 < _sections.length;
    final live = _betaLiveCard(hasNext ? () => _activate(_sections[activeIndex + 1].id) : null);
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
      children: [
        Row(
          children: [
            Expanded(
              flex: 11,
              child: ProtocolStripButton(
                key: const Key('rd-protocol-attendees'),
                icon: Icons.group,
                label: l10n.protocolPresentCount(_attendees.present.length),
                semanticLabel: _betaAttendeeSummary,
                onTap: _openAttendees,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 9,
              child: ProtocolStripButton(
                key: const Key('rd-protocol-general'),
                icon: Icons.notes,
                label: l10n.protocolNotes,
                dot: _hasNotes(protocolGeneralSectionId),
                semanticLabel: _hasNotes(protocolGeneralSectionId)
                    ? '${l10n.protocolGeneralNotes}, ${l10n.protocolHasNotes}'
                    : l10n.protocolGeneralNotes,
                onTap: _openGeneralNotes,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 11,
              child: ProtocolStripButton(
                key: const Key('rd-protocol-tasks'),
                icon: Icons.task_alt,
                label: _tasks.isEmpty ? l10n.teamOrgTabTasks : l10n.protocolTaskCount(_tasks.length),
                onTap: _openTasksSheet,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (live != null) ...[live, const SizedBox(height: 12)],
        if (_isPublished) _betaPublishedLine(),
        if (_sections.isEmpty)
          RdCard(child: Text(l10n.protocolPlanEmpty, style: RdType.meta(p, size: 15))),
        for (final s in _sections)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: _betaSectionCard(s, map)),
        Center(
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: _addSpontaneousTopic,
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 22, color: p.link),
                      const SizedBox(width: 6),
                      Text(l10n.protocolPoint,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.link)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (unassigned.isNotEmpty) ...[
          const SizedBox(height: 12),
          RdGroupLabel(l10n.protocolMoreTasks),
          RdCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: _betaTaskList(unassigned),
          ),
        ],
        ..._leftoverWidgets(),
      ],
    );
  }

  /// Beta, phone: one point. Closed it shows its status as a word; open it
  /// shows the result chips in one row, the notes and its tasks.
  Widget _betaSectionCard(_Section s, Map<String, String> map) {
    final p = context.rd;
    final active = _activeId == s.id;
    final isLive = _live?.fieldId == s.id;
    final tasks = _tasksFor(s.id, map);
    final kicker = _betaKicker(s);
    final status = active ? null : _betaStatusPill(s.id);
    return RdCard(
      padding: EdgeInsets.zero,
      border: isLive
          ? Border.all(color: p.absent, width: 1.5)
          : (active ? Border.all(color: p.primary, width: 1.5) : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            expanded: active,
            child: InkWell(
              onTap: () => _update(() {
                _activeId = active ? null : s.id;
                _sidePane = null;
              }),
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 12, active ? 6 : 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (kicker.isNotEmpty) Text(kicker.toUpperCase(), style: RdType.eyebrow(p.text2)),
                          const SizedBox(height: 2),
                          Text(s.name, style: RdType.section(p)),
                          if (active && s.conductor != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(s.conductor!, style: RdType.meta(p, size: 14)),
                            ),
                          if (!active && _hasNotes(s.id))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(_previewOf(s.id),
                                  maxLines: 2, overflow: TextOverflow.ellipsis, style: RdType.meta(p, size: 13)),
                            ),
                          if (!active && tasks.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(context.l10n.protocolTaskCount(tasks.length), style: RdType.meta(p, size: 13)),
                            ),
                        ],
                      ),
                    ),
                    if (status != null) Padding(padding: const EdgeInsets.only(left: 8), child: status),
                    const SizedBox(width: 4),
                    Icon(active ? Icons.expand_less : Icons.expand_more, color: p.text2),
                  ],
                ),
              ),
            ),
          ),
          if (active)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.isTop) ...[
                    ProtocolOutcomeChips(
                      value: _outcomes[s.id],
                      onChanged: (o) => _setOutcome(s.id, o),
                      singleLine: true,
                    ),
                    const SizedBox(height: 12),
                  ],
                  ClipRRect(
                    borderRadius: BorderRadius.circular(p.listRadius),
                    child: ColoredBox(color: p.bg, child: _betaEditor(s.id)),
                  ),
                  if (tasks.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: _betaTaskList(tasks)),
                  _betaAddTask(s.id),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Beta, phone: all tasks of the meeting with the point they belong to.
  Future<void> _openTasksSheet() async {
    final map = _taskSectionMap;
    await showRdSheet<void>(
      context,
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RdSheetTitle(ctx.l10n.teamOrgTabTasks),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  RdCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _tasks.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(ctx.l10n.protocolNoTasksYet, style: RdType.meta(ctx.rd, size: 14)),
                          )
                        : _betaTaskList(_tasks, labels: map, onOpen: (t) {
                            // The sheet lies above the pages: close it first.
                            Navigator.of(ctx).pop();
                            context.push('/settings/tasks/${t.id}');
                          }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "TOP 2" / point name / "Allgemein" of the section a task belongs to.
  String? _sectionLabelOfTask(TeamTask t, Map<String, String> map) {
    final id = map[t.id];
    if (id == null) return null;
    if (id == protocolGeneralSectionId) return context.l10n.protocolGeneral;
    for (final s in _sections) {
      if (s.id == id) return s.topNumber != null ? context.l10n.protocolTop(s.topNumber!) : s.name;
    }
    return null;
  }

  Widget _buildReadLayout(BuildContext context) {
    final theme = Theme.of(context);
    final map = _taskSectionMap;
    final att = _attendees;
    final unassigned = _unassignedTasks(map);
    Widget card(Widget child) =>
        Card(child: Padding(padding: const EdgeInsets.all(AppDimensions.paddingM), child: child));
    final cardLabel = theme.textTheme.titleSmall;
    final readTitle = theme.textTheme.titleMedium;
    Widget pill(String name, {bool muted = false}) =>
        Chip(label: Text(name, style: muted ? TextStyle(color: AppColors.mediumOf(context)) : null));
    return ListView(
      padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM + MediaQuery.paddingOf(context).bottom),
      children: [
        if (_isPublished)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
            child: Row(children: [
              Icon(AppIcons.checkCircle, color: AppColors.success, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(_statusLine)),
            ]),
          ),
        if (att.present.isNotEmpty || att.excused.isNotEmpty)
          card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.protocolPresentList(att.present.length), style: cardLabel),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final a in att.present) pill(a.name),
                  ]),
                  if (att.excused.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.paddingS),
                    Text(context.l10n.protocolExcusedList(att.excused.length), style: cardLabel),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final a in att.excused) pill(a.name, muted: true),
                    ]),
                  ],
                ],
              ),
          ),
        for (final s in _sections)
          if (s.isTop || _hasNotes(s.id) || _outcomes[s.id] != null || _tasksFor(s.id, map).isNotEmpty)
            card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.topNumber != null)
                      Text(context.l10n.protocolTop(s.topNumber!),
                          style: theme.textTheme.labelSmall),
                    Row(children: [
                      Expanded(child: Text(s.name, style: readTitle)),
                      if (_outcomes[s.id] != null)
                        TeamOrgBadge(
                            label: outcomeLabels[_outcomes[s.id]] ?? '', color: outcomeColor(_outcomes[s.id])),
                    ]),
                    if (_hasNotes(s.id))
                      _editor(_controllerFor(s.id, readOnly: true), editable: false)
                    else if (_tasksFor(s.id, map).isEmpty)
                      Text(context.l10n.protocolNoNotes, style: TextStyle(color: AppColors.mediumOf(context))),
                    _taskList(_tasksFor(s.id, map)),
                  ],
                ),
            ),
        ..._leftoverWidgets(),
        if (_hasNotes(protocolGeneralSectionId) || unassigned.isNotEmpty)
          card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.protocolGeneralNotes, style: readTitle),
                  if (_hasNotes(protocolGeneralSectionId))
                    _editor(_controllerFor(protocolGeneralSectionId, readOnly: true), editable: false),
                  _taskList(unassigned),
                ],
              ),
          ),
        const SizedBox(height: AppDimensions.paddingM),
        OutlinedButton.icon(
          onPressed: _sharePdf,
          icon: Icon(AppIcons.iosShare),
          label: IonButtonLabel(context.l10n.protocolSharePdf),
        ),
      ],
    );
  }
}

/// Live progress banner showing the currently active plan item.
class _LiveBar extends StatefulWidget {
  const _LiveBar({required this.label});

  final String label;

  @override
  State<_LiveBar> createState() => _LiveBarState();
}

class _LiveBarState extends State<_LiveBar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  static const _shade = Color(0xFF00815E);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0.35).animate(_pulse),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _shade)),
            ),
          ],
        ),
      ),
    );
  }
}
