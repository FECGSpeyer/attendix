part of 'protocol_page.dart';

extension _ProtocolPageBeta on _ProtocolPageState {
  /// Beta: same content, Beta frame (back link, title with date and
  /// status, share as round button, footer with the Beta buttons).
  Widget _buildBeta(BuildContext context, bool wide, bool showFooter) {
    final p = context.rd;
    final l10n = context.l10n;
    final ready = !_loading && !_notAvailable && !_loadFailed && _attendance != null;
    final Widget body;
    if (_loading) {
      body = _betaState(RdInfoCard(text: l10n.redesignTodayLoading, loading: true));
    } else if (_notAvailable) {
      body = _betaState(RdInfoCard(icon: Icons.lock_outline, text: '${l10n.protocolNotPublished}\n${l10n.protocolNotPublishedHint}'));
    } else if (!ready) {
      body = _betaState(RdInfoCard(
        icon: Icons.cloud_off_outlined,
        text: l10n.protocolLoadFailed,
        action: RdOutlineButton(label: l10n.protocolRetry, onPressed: _load),
      ));
    } else {
      body = _isLeader ? (wide ? _buildBetaWide(context) : _buildBetaEditLayout(context)) : _buildReadLayout(context);
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_flushAll());
      },
      child: Scaffold(
        backgroundColor: p.bg,
        bottomNavigationBar: showFooter ? _betaFooter(context) : null,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: RdBackLink(
                            label: l10n.rdTeamTitle,
                            onTap: () => context.canPop() ? context.pop() : context.go('/settings/team-organization'),
                          ),
                        ),
                        if (ready)
                          RdCircleButton(
                            key: const Key('rd-protocol-share'),
                            icon: Icons.ios_share,
                            label: l10n.protocolSharePdf,
                            onPressed: _sharePdf,
                          ),
                        // Wide: the one main action sits here, always visible.
                        if (ready && wide && _isLeader) ...[
                          const SizedBox(width: 10),
                          RdPrimaryButton(
                            key: const Key('rd-protocol-finish'),
                            label: _isPublished ? l10n.protocolRepublish : l10n.rdTeamFinishMeeting,
                            height: 44,
                            onPressed: _openPublish,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.protocolTitle.toUpperCase(), style: RdType.eyebrow(p.text2)),
                    if (ready) ...[
                      const SizedBox(height: 2),
                      Semantics(header: true, child: Text(_title, style: RdType.title(p))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              [_dateLabel, if (_timeRange.isNotEmpty) l10n.attendanceTimeOClock(_timeRange)].join(' · '),
                              style: RdType.meta(p, size: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          RdPill(
                            _isPublished ? l10n.teamOrgPublished : l10n.teamOrgDraft,
                            tone: _isPublished ? RdTone.present : null,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  Widget _betaState(Widget card) => ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [card]);

  /// Beta footer (phone): save state above the one main action.
  Widget _betaFooter(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Material(
      color: p.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_savingCount > 0)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: SizedBox(width: 12, height: 12, child: AppSpinner(strokeWidth: 2)),
                    ),
                  Flexible(
                    child: Text(_saveLabel,
                        style: RdType.meta(p, size: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: RdPrimaryButton(
                  key: const Key('rd-protocol-finish'),
                  label: _isPublished ? l10n.protocolRepublish : l10n.rdTeamFinishMeeting,
                  onPressed: _openPublish,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(ProtocolAttendee a) {
    final f = a.firstName.trim();
    final l = a.lastName.trim();
    final s = '${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  Future<void> _openAttendees() async {
    final att = _attendees;
    final p = context.rd;
    Widget row(ProtocolAttendee a, int i, {Color? color, bool muted = false}) => RdListRow(
          leading: muted ? null : ExcludeSemantics(child: _betaAvatar(a, i, size: 32, color: color)),
          title: a.name,
          subtitle: a.notes?.isNotEmpty == true ? a.notes : null,
          titleColor: muted ? p.text2 : null,
          showChevron: false,
        );
    await showRdSheet<void>(
      context,
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RdSheetTitle(ctx.l10n.protocolParticipants),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  RdGroupLabel(ctx.l10n.protocolPresentList(att.present.length)),
                  RdGroupedList(
                    children: [
                      for (var i = 0; i < att.present.length; i++) row(att.present[i], i),
                      if (att.present.isEmpty)
                        RdListRow(title: ctx.l10n.protocolNobodyPresent, titleColor: p.text2, showChevron: false),
                    ],
                  ),
                  if (att.excused.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    RdGroupLabel(ctx.l10n.protocolExcusedList(att.excused.length)),
                    RdGroupedList(
                      children: [for (var i = 0; i < att.excused.length; i++) row(att.excused[i], i, color: p.off)],
                    ),
                  ],
                  if (att.others.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    RdGroupLabel(ctx.l10n.protocolOthersList(att.others.length)),
                    RdGroupedList(
                      children: [for (var i = 0; i < att.others.length; i++) row(att.others[i], i, muted: true)],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(ctx.l10n.protocolListFromAttendance, style: RdType.meta(p, size: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGeneralNotes() async {
    await showRdSheet<void>(
      context,
      Builder(
        // The keyboard must not cover the notes.
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RdSheetTitle(ctx.l10n.protocolGeneralNotes),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Text(ctx.l10n.protocolWholeMeeting, style: RdType.meta(ctx.rd, size: 14)),
                    const SizedBox(height: 12),
                    RdCard(
                      padding: EdgeInsets.zero,
                      // The task form opens above the sheet; back in the
                      // sheet the reference and the task are shown and
                      // writing continues.
                      child: StatefulBuilder(
                        builder: (sheetCtx, setSheet) {
                          final tasks = _tasksFor(protocolGeneralSectionId, _taskSectionMap);
                          // The sheet lies above the pages: close it before
                          // a task opens.
                          void openTask(String id) {
                            Navigator.of(ctx).pop();
                            context.push('/settings/tasks/$id');
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _betaEditor(protocolGeneralSectionId, minHeight: 140, onOpenTask: openTask),
                              Divider(height: 1, thickness: 1, color: ctx.rd.line),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (tasks.isNotEmpty)
                                      _betaTaskList(tasks, onOpen: (t) {
                                        if (t.id != null) openTask(t.id!);
                                      }),
                                    _betaAddTask(protocolGeneralSectionId, after: () {
                                      if (sheetCtx.mounted) setSheet(() {});
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await _flush(protocolGeneralSectionId);
    if (mounted) _update(() {});
  }

  /// Live task statuses for the task chips in the notes.
  Map<String, String> get _taskStatuses => {
        for (final t in _tasks)
          if (t.id != null) t.id!: t.status,
      };

  /// Open topics offered by "/tagesordnung".
  List<AgendaItem> get _openTopics => (ref.read(agendaItemsProvider).valueOrNull ?? const <AgendaItem>[])
      .where((i) => i.status == 'open' && (i.proposalStatus == null || i.proposalStatus == 'accepted'))
      .toList();

  Widget _editor(QuillController controller, {bool editable = true, bool expands = false}) {
    String? sectionId;
    for (final e in _controllers.entries) {
      if (identical(e.value, controller)) sectionId = e.key;
    }
    final canWrite = editable && !controller.readOnly && sectionId != null && !sectionId.startsWith('leftover:');
    return ProtocolEditor(
      key: ValueKey('editor-$sectionId'),
      controller: controller,
      editable: canWrite,
      expands: expands,
      taskStatuses: _taskStatuses,
      agendaItems: canWrite ? _openTopics : const [],
      onCreateTask: canWrite ? () => _createTask(sectionId!) : null,
      onOpenTask: (id) => context.push('/settings/tasks/$id'),
      onOpenTopic: _isLeader ? (id) => context.push('/settings/agenda-items/$id') : null,
    );
  }

  Widget _taskList(List<TeamTask> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final t in list)
          ListTile(
            dense: true,
            leading: Icon(
              t.status == 'completed' ? AppIcons.checkCircle : AppIcons.radioButtonUnchecked,
              color: t.status == 'completed' ? AppColors.success : AppColors.mediumOf(context),
            ),
            title: Text(
              t.title,
              style: t.status == 'completed' ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
            ),
            subtitle: _taskLine(t).isNotEmpty ? Text(_taskLine(t)) : null,
            onTap: () => context.push('/settings/tasks/${t.id}'),
          ),
      ],
    );
  }

  String _previewOf(String id) {
    final c = _controllers[id];
    if (c != null) {
      final text = c.document.toPlainText().replaceAll(RegExp(r'\s+'), ' ').trim();
      return text.length > 140 ? '${text.substring(0, 139)}…' : text;
    }
    return docToPlainText(_docs[id], maxLength: 140);
  }

  List<Widget> _leftoverWidgets() {
    if (_leftovers.isEmpty) return const [];
    return [
      const SizedBox(height: AppDimensions.paddingM),
      Text(context.l10n.protocolMoreNotes, style: Theme.of(context).textTheme.titleSmall),
      Text(context.l10n.protocolMoreNotesHint),
      for (final l in _leftovers)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.title, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  context.l10n.protocolNotInPlan,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mediumOf(context)),
                ),
                _editor(_controllerFor('leftover:${l.key}', readOnly: true, initialDoc: l.doc), editable: false),
              ],
            ),
          ),
        ),
    ];
  }
}
