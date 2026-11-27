part of 'protocol_page.dart';

extension _ProtocolPagePanes on _ProtocolPageState {
  // ── Wide layout (Ionic B4) ─────────────────────────────────

  List<String> get _sectionIds => _sections.map((s) => s.id).toList();

  /// Selects a point (and focuses its editor in the wide layout).
  void _activate(String id, {bool focus = false}) {
    _update(() {
      _activeId = id;
      _sidePane = null;
    });
    if (focus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes[id]?.requestFocus();
      });
    }
  }

  void _nextSection() {
    final next = nextSectionId(_sectionIds, _activeId);
    if (next != null) _activate(next, focus: true);
  }

  void _previousSection() {
    final prev = previousSectionId(_sectionIds, _activeId);
    if (prev != null) _activate(prev, focus: true);
  }

  // ── Beta: two columns (wide) and phone ─────────────────────

  String _betaKicker(_Section s, {bool withStart = true}) => [
        if (s.topNumber != null) context.l10n.protocolTop(s.topNumber!),
        if (withStart && s.start != null) s.start!,
        if (s.duration > 0) context.l10n.planningMinShort(s.duration),
      ].join(' · ');

  /// Status of a point as a word: the result, else "Notiert" once there
  /// are notes, else nothing.
  Widget? _betaStatusPill(String id) {
    final o = _outcomes[id];
    if (o != null) return RdPill(outcomeLabels[o] ?? o, tone: protocolOutcomeTone(o));
    return _hasNotes(id) ? RdPill(context.l10n.protocolNoted) : null;
  }

  String get _betaAttendeeSummary {
    final att = _attendees;
    final l10n = context.l10n;
    return att.excused.isEmpty
        ? l10n.protocolPresentCount(att.present.length)
        : l10n.rdTeamProtocolAttendeesBoth(att.present.length, att.excused.length);
  }

  String get _betaTaskSummary {
    final l10n = context.l10n;
    if (_tasks.isEmpty) return l10n.rdTeamProtocolTasksNone;
    final open = _tasks.where((t) => t.status != 'completed').length;
    return open > 0 ? l10n.rdTeamProtocolTasksOpen(open) : l10n.rdTeamProtocolTasksDone;
  }

  Widget _betaAvatar(ProtocolAttendee a, int index, {double size = 28, Color? color}) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color ?? _avatarColors[(a.personId ?? index) % _avatarColors.length],
          shape: BoxShape.circle,
          border: Border.all(color: context.rd.surface, width: 2),
        ),
        child: Text(
          _initials(a),
          style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      );

  /// At most three overlapping initials (the row's text has the numbers).
  Widget? _betaAvatars(List<ProtocolAttendee> present) {
    final shown = present.take(3).toList();
    if (shown.isEmpty) return null;
    return ExcludeSemantics(
      child: SizedBox(
        width: 28 + 18.0 * (shown.length - 1),
        height: 28,
        child: Stack(
          children: [
            for (var i = 0; i < shown.length; i++) Positioned(left: i * 18.0, child: _betaAvatar(shown[i], i)),
          ],
        ),
      ),
    );
  }

  Widget? _betaLiveCard(VoidCallback? onNext) {
    _Section? liveSec;
    for (final s in _sections) {
      if (s.id == _live?.fieldId) liveSec = s;
    }
    if (_live == null || liveSec == null) return null;
    final l10n = context.l10n;
    return ProtocolLiveCard(
      label: l10n.protocolRunning(
          liveSec.topNumber != null ? l10n.protocolTop(liveSec.topNumber!) : liveSec.name, _live!.remainingMinutes),
      nextLabel: onNext != null ? l10n.protocolNextPoint : null,
      onNext: onNext,
    );
  }

  Widget _betaPublishedLine() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Icon(Icons.check_circle, color: context.rd.present, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(_statusLine, style: RdType.meta(context.rd, size: 13))),
        ]),
      );

  Widget _betaEditor(
    String sectionId, {
    bool expands = false,
    bool wide = false,
    double minHeight = 96,
    void Function(String taskId)? onOpenTask,
  }) =>
      ProtocolEditor(
        key: ValueKey('beta-editor-$sectionId'),
        controller: _controllerFor(sectionId),
        focusNode: wide ? _focusFor(sectionId) : null,
        slim: true,
        hint: wide ? context.l10n.rdTeamProtocolSlashHint : null,
        expands: expands,
        minHeight: minHeight,
        onNextPoint: wide ? _nextSection : null,
        onPreviousPoint: wide ? _previousSection : null,
        taskStatuses: _taskStatuses,
        agendaItems: _openTopics,
        onCreateTask: () => _createTask(sectionId),
        onOpenTask: onOpenTask ?? (id) => context.push('/settings/tasks/$id'),
        onOpenTopic: (id) => context.push('/settings/agenda-items/$id'),
      );

  /// Tasks as Beta rows; [labels] adds the point a task belongs to.
  Widget _betaTaskList(List<TeamTask> list, {Map<String, String>? labels, void Function(TeamTask)? onOpen}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in list)
            ProtocolTaskRow(
              title: t.title,
              meta: [if (labels != null) _sectionLabelOfTask(t, labels), _taskLine(t)]
                  .whereType<String>()
                  .where((x) => x.isNotEmpty)
                  .join(' · '),
              done: t.status == 'completed',
              onTap: () => onOpen != null ? onOpen(t) : context.push('/settings/tasks/${t.id}'),
            ),
        ],
      );

  Widget _betaAddTask(String sectionId, {VoidCallback? after}) {
    final p = context.rd;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: () async {
            await _createTask(sectionId);
            after?.call();
          },
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, size: 22, color: p.link),
                  const SizedBox(width: 10),
                  Text(context.l10n.tasksTask,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.link)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Wide: the writing surface. The notes fill the height; the tasks of the
  /// point and "+ Aufgabe" stay at its lower edge.
  Widget _betaPaneCard(String sectionId, List<TeamTask> tasks) {
    final p = context.rd;
    final radius = BorderRadius.circular(p.cardRadius);
    return DecoratedBox(
      decoration: BoxDecoration(color: p.surface, borderRadius: radius, boxShadow: p.cardShadow),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _betaEditor(sectionId, expands: true, wide: true)),
            Divider(height: 1, thickness: 1, color: p.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tasks.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 112),
                      child: SingleChildScrollView(child: _betaTaskList(tasks)),
                    ),
                  _betaAddTask(sectionId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Wide: a pane whose card fills the height. In a very low window (tablet
  /// with the keyboard open) the pane keeps a minimum height and scrolls.
  Widget _betaFillPane({required List<Widget> head, required Widget card}) {
    final p = context.rd;
    final l10n = context.l10n;
    final hasNext = nextSectionId(_sectionIds, _activeId) != null;
    final apple = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    return LayoutBuilder(builder: (context, constraints) {
      final minHeight = 600 * MediaQuery.textScalerOf(context).scale(1);
      return SingleChildScrollView(
        child: SizedBox(
          height: constraints.maxHeight < minHeight ? minHeight : constraints.maxHeight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...head,
                Expanded(child: card),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        if (_savingCount > 0)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: SizedBox(width: 12, height: 12, child: AppSpinner(strokeWidth: 2)),
                          ),
                        Expanded(
                          child: Text(_saveLabel,
                              style: RdType.meta(p, size: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (hasNext)
                          ProtocolNextButton(
                            key: const Key('rd-protocol-next'),
                            label: l10n.protocolNextPoint,
                            shortcut: apple ? '⌘ ↓' : l10n.rdTeamProtocolCtrlDown,
                            onPressed: _nextSection,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _betaPaneTitle(String text) => Semantics(
        header: true,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: RdType.cardTitle(context.rd).copyWith(fontSize: 24),
        ),
      );

  Widget _betaPointPane(_Section s, Map<String, String> map) {
    final p = context.rd;
    final kicker = _betaKicker(s);
    return _betaFillPane(
      head: [
        if (kicker.isNotEmpty) Text(kicker.toUpperCase(), style: RdType.eyebrow(p.text2)),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _betaPaneTitle(s.name)),
            if (s.conductor != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 3),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    context.l10n.protocolResponsible(s.conductor!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RdType.meta(p, size: 14),
                  ),
                ),
              ),
          ],
        ),
        if (s.isTop) ...[
          const SizedBox(height: 12),
          ProtocolOutcomeChips(value: _outcomes[s.id], onChanged: (o) => _setOutcome(s.id, o)),
        ],
        const SizedBox(height: 12),
      ],
      card: _betaPaneCard(s.id, _tasksFor(s.id, map)),
    );
  }

  Widget _betaGeneralPane(Map<String, String> map) => _betaFillPane(
        head: [
          _betaPaneTitle(context.l10n.protocolGeneralNotes),
          const SizedBox(height: 2),
          Text(context.l10n.protocolWholeMeeting, style: RdType.meta(context.rd, size: 14)),
          const SizedBox(height: 12),
        ],
        card: _betaPaneCard(protocolGeneralSectionId, _tasksFor(protocolGeneralSectionId, map)),
      );

  Widget _betaTasksPane(Map<String, String> map) {
    final l10n = context.l10n;
    return ListView(
      padding: EdgeInsets.fromLTRB(12, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
      children: [
        _betaPaneTitle(l10n.teamOrgTabTasks),
        const SizedBox(height: 2),
        Text(l10n.protocolSessionTasks(_tasks.length), style: RdType.meta(context.rd, size: 14)),
        const SizedBox(height: 12),
        RdCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(l10n.protocolNoTasksYet, style: RdType.meta(context.rd, size: 14)),
                )
              else
                _betaTaskList(_tasks, labels: map),
            ],
          ),
        ),
      ],
    );
  }

  Widget _betaLeftoverPane(_Leftover l, Map<String, String> map) {
    final p = context.rd;
    final tasks = _tasksFor(l.key, map);
    return ListView(
      padding: EdgeInsets.fromLTRB(12, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
      children: [
        Text(context.l10n.protocolMoreNotes.toUpperCase(), style: RdType.eyebrow(p.text2)),
        const SizedBox(height: 2),
        _betaPaneTitle(l.title),
        const SizedBox(height: 2),
        Text(context.l10n.protocolNotInPlan, style: RdType.meta(p, size: 14)),
        const SizedBox(height: 12),
        RdCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _editor(_controllerFor('leftover:${l.key}', readOnly: true, initialDoc: l.doc), editable: false),
              if (tasks.isNotEmpty) _betaTaskList(tasks),
            ],
          ),
        ),
      ],
    );
  }

  /// Wide, left: the Ablaufplan with the status of every point as a word,
  /// below it what belongs to the whole meeting.
  Widget _betaSide(Map<String, String> map) {
    final p = context.rd;
    final l10n = context.l10n;
    final live = _betaLiveCard(nextSectionId(_sectionIds, _activeId) != null ? _nextSection : null);
    final pointSelected = _sidePane == null;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 12, 12, 20 + MediaQuery.paddingOf(context).bottom),
      children: [
        if (_isPublished) _betaPublishedLine(),
        if (live != null) ...[live, const SizedBox(height: 16)],
        RdGroupLabel(l10n.protocolRunSheet),
        RdGroupedList(
          children: [
            for (final s in _sections)
              ProtocolAgendaRow(
                leading: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    s.start ?? '',
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: _live?.fieldId == s.id ? FontWeight.w700 : FontWeight.w400,
                      color: _live?.fieldId == s.id ? p.absent : p.text2,
                    ),
                  ),
                ),
                title: s.name,
                meta: _betaKicker(s, withStart: false),
                status: _betaStatusPill(s.id),
                selected: pointSelected && _activeId == s.id,
                onTap: () => _activate(s.id, focus: true),
              ),
            for (final l in _leftovers)
              ProtocolAgendaRow(
                leading: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(Icons.inventory_2_outlined, size: 20, color: p.text2),
                ),
                title: l.title,
                meta: l10n.protocolMoreNotes,
                selected: pointSelected && _activeId == l.key,
                onTap: () => _activate(l.key),
              ),
            ProtocolAgendaRow(
              leading: Align(alignment: Alignment.centerLeft, child: Icon(Icons.add, size: 22, color: p.link)),
              title: l10n.protocolPoint,
              titleColor: p.link,
              onTap: _addSpontaneousTopic,
            ),
          ],
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.rdTeamProtocolAbout),
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('rd-protocol-general'),
              leading: const RdRowIcon(Icons.notes),
              title: l10n.protocolGeneralNotes,
              subtitle: _hasNotes(protocolGeneralSectionId)
                  ? _betaShortPreview(protocolGeneralSectionId)
                  : l10n.rdTeamProtocolEmpty,
              selected: _sidePane == 'general',
              onTap: () => _openSidePane('general'),
            ),
            RdListRow(
              key: const Key('rd-protocol-tasks'),
              leading: const RdRowIcon(Icons.task_alt),
              title: l10n.teamOrgTabTasks,
              subtitle: _betaTaskSummary,
              selected: _sidePane == 'tasks',
              onTap: () => _openSidePane('tasks'),
            ),
            RdListRow(
              key: const Key('rd-protocol-attendees'),
              leading: const RdRowIcon(Icons.group),
              title: l10n.protocolPresent,
              subtitle: _betaAttendeeSummary,
              trailing: _betaAvatars(_attendees.present),
              onTap: _openAttendees,
            ),
          ],
        ),
      ],
    );
  }

  String _betaShortPreview(String id) {
    final text = _previewOf(id);
    return text.length > 60 ? '${text.substring(0, 59)}…' : text;
  }

  void _openSidePane(String pane) {
    _update(() => _sidePane = pane);
    if (pane == 'general') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes[protocolGeneralSectionId]?.requestFocus();
      });
    }
  }
}
