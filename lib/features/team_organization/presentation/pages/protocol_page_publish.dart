part of 'protocol_page.dart';

extension _ProtocolPagePublish on _ProtocolPageState {
  // ── Display helpers ────────────────────────────────────────

  String get _title => attendanceTitle(_attendance?.typeInfo, _type) == l10nWithoutContext.attendanceEventFallback
      ? l10nWithoutContext.protocolTitle
      : attendanceTitle(_attendance?.typeInfo, _type);

  String get _dateLabel {
    final d = DateTime.tryParse(_attendance?.date ?? '')?.toLocal();
    return d == null ? '' : '${weekdayShort(d)}, ${DateFormat(dateFmt()).format(d)}';
  }

  String get _timeRange {
    final start = _planStartDateTime;
    if (start == null) return '';
    final total = _sections.fold<int>(0, (s, x) => s + x.duration);
    final fmt = DateFormat('HH:mm');
    return total > 0 ? '${fmt.format(start)}–${fmt.format(start.add(Duration(minutes: total)))}' : fmt.format(start);
  }

  bool get _isPublished => _protocol?.status == 'published';

  String get _statusLine {
    final l10n = l10nWithoutContext;
    if (!_isPublished) return l10n.teamOrgDraft;
    final fmt = DateFormat(dateFmt());
    final pub = DateTime.tryParse(_protocol?.publishedAt ?? '')?.toLocal();
    var line = l10n.teamOrgPublishedOn(pub != null ? fmt.format(pub) : '');
    if (isEditedAfterPublish(_protocol)) {
      final upd = DateTime.tryParse(_protocol!.updatedAt!)?.toLocal();
      line = l10n.teamOrgEditedOn(line, upd != null ? fmt.format(upd) : '');
    }
    return line;
  }

  String get _saveLabel {
    final l10n = l10nWithoutContext;
    if (_savingCount > 0) return l10n.protocolSaving;
    if (_lastSavedAt != null) return l10n.protocolAutoSavedAt(DateFormat('HH:mm').format(_lastSavedAt!));
    return _isPublished ? l10n.protocolChangesAutoSaved : l10n.protocolAutoSaved;
  }

  bool _hasNotes(String id) {
    final c = _controllers[id];
    if (c != null && c.document.toPlainText().trim().isNotEmpty) return true;
    return !isDocEmpty(_docs[id]);
  }

  String _sectionMeta(_Section s) =>
      [s.start, if (s.duration > 0) l10nWithoutContext.planningMinShort(s.duration), s.conductor]
          .whereType<String>()
          .where((x) => x.isNotEmpty)
          .join(' · ');

  String _taskLine(TeamTask t) {
    final parts = <String>[];
    if (t.responsiblePerson.fullName.isNotEmpty) parts.add(t.responsiblePerson.fullName);
    final due = DateTime.tryParse(t.dueDate ?? '');
    if (due != null) parts.add(context.l10n.protocolDueShort(DateFormat(dateFmt(DateFmtKind.dayMonth)).format(due)));
    return parts.join(' · ');
  }

  ({List<ProtocolAttendee> present, List<ProtocolAttendee> excused, List<ProtocolAttendee> others}) get _attendees {
    final all = [...?_attendance?.persons]..sort((a, b) => a.name.compareTo(b.name));
    return (
      present: all.where((a) => isPresentStatus(a.status)).toList(),
      excused: all.where((a) => a.status == AttendanceStatus.excused.value).toList(),
      others: all.where((a) => !isPresentStatus(a.status) && a.status != AttendanceStatus.excused.value).toList(),
    );
  }

  // ── PDF ────────────────────────────────────────────────────

  ProtocolPdfData _buildPdfData({PdfBranding? branding}) {
    final map = _taskSectionMap;
    final l10n = l10nWithoutContext;
    final dueFmt = DateFormat(dateFmt());
    String taskText(TeamTask t) {
      final parts = [t.title];
      if (t.responsiblePerson.fullName.isNotEmpty) parts.add(t.responsiblePerson.fullName);
      final due = DateTime.tryParse(t.dueDate ?? '');
      if (due != null) parts.add(l10n.protocolDueShort(dueFmt.format(due)));
      if (t.status == 'completed') parts.add(l10n.protocolFlutterDoneLower);
      return parts.join(' · ');
    }

    final att = _attendees;
    final sections = [
      for (final s in _sections)
        ProtocolPdfSection(
          title: s.title,
          meta: _sectionMeta(s),
          outcome: outcomeLabels[_outcomes[s.id]],
          doc: _currentDoc(s.id),
          tasks: _tasksFor(s.id, map).map(taskText).toList(),
        ),
      for (final l in _leftovers)
        ProtocolPdfSection(title: l10n.protocolMoreNotesTitle(l.title), doc: l.doc, tasks: _tasksFor(l.key, map).map(taskText).toList()),
    ];
    final leftoverKeys = _leftovers.map((l) => l.key).toSet();
    final other = _tasks.where((t) {
      final id = map[t.id];
      return id == null || (!_sections.any((s) => s.id == id) && !leftoverKeys.contains(id));
    }).toList();
    return ProtocolPdfData(
      title: l10n.protocolPdfTitle(_title),
      subtitle: [_dateLabel, if (_timeRange.isNotEmpty) l10n.attendanceTimeOClock(_timeRange)].join(' · '),
      status: _statusLine,
      present: att.present.map((a) => a.name).toList(),
      excused: att.excused.map((a) => a.name).toList(),
      sections: sections,
      generalNotes: _currentDoc(protocolGeneralSectionId),
      otherTasks: other.map(taskText).toList(),
      branding: branding, // P10_SONGS_ORG: Ionic buildTenantBranding
    );
  }

  Future<void> _sharePdf() async {
    try {
      await _flushAll();
      final branding = await resolvePdfBranding(ref);
      final bytes = await createProtocolPdf(_buildPdfData(branding: branding));
      final d = DateTime.tryParse(_attendance?.date ?? '')?.toLocal();
      final name = l10nWithoutContext
          .protocolFileName(_title, d != null ? DateFormat('yyyy-MM-dd').format(d) : '')
          .trim()
          .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
      await NativeFileService.saveBytes(bytes, '$name.pdf');
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.protocolPdfFailed);
    }
  }

  // ── Publish ────────────────────────────────────────────────

  Future<void> _openPublish() async {
    // Taken before the flush: an edit typed while saving (and saved before
    // the row below arrives) must not be overwritten by an older server row.
    final editsBefore = Map<String, int>.of(_editCount);
    // SOL_FIX2: never offer publishing an incompletely saved protocol.
    if (!await _flushAll()) {
      if (mounted) ToastHelper.showError(context, context.l10n.protocolNotesSaveFailed);
      return;
    }
    // Other leaders may have written in other sections meanwhile.
    try {
      final row = await _repo.getProtocolForAttendance(widget.attendanceId);
      if (row != null && mounted) {
        // Ionic mergeServerRow: every section without an unsaved local
        // change takes the server notes, opened editors included. Sections
        // edited while the row loaded keep the newer local text.
        for (final e in row.content.entries) {
          if (_pending.contains(e.key) || _inFlight.containsKey(e.key) || e.value is! Map) continue;
          if ((_editCount[e.key] ?? 0) != (editsBefore[e.key] ?? 0)) continue;
          final doc = Map<String, dynamic>.from(e.value as Map);
          final controller = _controllers[e.key];
          // Compared by content: jsonb returns the keys sorted, a string
          // compare would replace (cursor, undo) nearly every editor.
          if (controller != null && !const DeepCollectionEquality().equals(_docs[e.key], doc)) {
            _replaceEditorDoc(e.key, controller, doc);
          }
          _docs[e.key] = doc;
        }
        _outcomes = {for (final e in row.outcomes.entries) e.key: e.value.toString()};
      }
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'protocol_page');
    }

    final summary = PublishSummary();
    final att = _attendees;
    summary.taskCount = _tasks.length;
    summary.recipientCount = att.present.length;
    for (final s in _sections) {
      final o = _outcomes[s.id];
      if (o == 'decided') {
        summary.decided.add(s.name);
      } else if (o == 'discussed') {
        summary.discussed.add(s.name);
      } else if (o == 'postponed') {
        summary.postponed.add(s.name);
      } else if (s.isTop) {
        summary.withoutOutcome.add(s.name);
      }
      if (!_hasNotes(s.id)) summary.withoutNotes.add(s.name);
    }
    summary.taskOwners = _tasks
        .map((t) => (t.responsiblePerson?.firstName?.trim().isNotEmpty ?? false)
            ? t.responsiblePerson!.firstName!.trim()
            : (t.responsiblePerson?.lastName?.trim() ?? ''))
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    var closures = <TopicClosure>[];
    final agendaIds = _sections.map((s) => s.agendaItemId).whereType<String>().toList();
    if (agendaIds.isNotEmpty) {
      try {
        final items = await _agendaRepo.getAgendaItemsByIds(agendaIds);
        closures = topicClosureCandidates(
          _sections.map((s) => (id: s.id, name: s.name, agendaItemId: s.agendaItemId)).toList(),
          _outcomes,
          items,
        );
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'protocol_page');
      }
    }
    if (!mounted) return;
    _update(() {});
    var sendPdf = true;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.9,
          child: Column(
            children: [
              AppBar(
                toolbarHeight: ionModalToolbarHeight(context),
                automaticallyImplyLeading: false,
                leading: TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: IonButtonLabel(ctx.l10n.commonCancel)),
                leadingWidth: 100,
                title: Text(ctx.l10n.protocolPublish),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  children: [
                    Text(ctx.l10n.protocolSummary, style: Theme.of(ctx).textTheme.titleSmall),
                    Card(
                      child: Column(children: [
                        if (summary.decided.isNotEmpty)
                          _summaryTile(AppIcons.checkCircle, AppColors.success,
                              ctx.l10n.protocolDecidedCount(summary.decided.length),
                              summary.decided.join(', ')),
                        if (summary.discussed.isNotEmpty)
                          _summaryTile(AppIcons.forumOutlined, AppColors.primary,
                              ctx.l10n.protocolDiscussedCount(summary.discussed.length),
                              summary.discussed.join(', ')),
                        if (summary.postponed.isNotEmpty)
                          _summaryTile(
                              AppIcons.schedule,
                              AppColors.warning,
                              ctx.l10n.protocolPostponedCount(summary.postponed.length),
                              '${summary.postponed.join(', ')}${_type?.suggestPostponed == true ? ctx.l10n.protocolSuggestNext : ''}'),
                        _summaryTile(
                            AppIcons.checkBoxOutlined,
                            AppColors.mediumOf(context),
                            ctx.l10n.protocolTaskCount(summary.taskCount),
                            summary.taskOwners.isNotEmpty ? ctx.l10n.protocolForNames(joinNames(summary.taskOwners)) : null),
                        if (summary.withoutOutcome.isNotEmpty)
                          _summaryTile(AppIcons.helpOutline, AppColors.mediumOf(context),
                              ctx.l10n.protocolWithoutOutcome(summary.withoutOutcome.length), summary.withoutOutcome.join(', ')),
                        if (summary.withoutNotes.isNotEmpty)
                          _summaryTile(AppIcons.errorOutline, AppColors.warning,
                              ctx.l10n.protocolWithoutNotes(summary.withoutNotes.length), summary.withoutNotes.join(', ')),
                      ]),
                    ),
                    if (closures.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.paddingS),
                      Text(ctx.l10n.protocolCloseTopics, style: Theme.of(ctx).textTheme.titleSmall),
                      Card(
                        child: Column(children: [
                          for (final c in closures)
                            CheckboxListTile(
                              value: c.close,
                              onChanged: (v) => setLocal(() => c.close = v ?? false),
                              title: Text(c.title),
                              subtitle: Text(outcomeLabels[c.outcome] ?? ''),
                            ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.paddingS),
                    Text(ctx.l10n.protocolVisibility, style: Theme.of(ctx).textTheme.titleSmall),
                    Card(
                      child: Column(children: [
                        _summaryTile(
                          AppIcons.visibilityOutlined,
                          AppColors.mediumOf(context),
                          ctx.l10n.protocolMayRead,
                          (_type?.relevantGroups?.isNotEmpty ?? false)
                              ? ctx.l10n.protocolReadGroups(_type?.name ?? '')
                              : ctx.l10n.protocolReadAll(_type?.name ?? ''),
                        ),
                        _summaryTile(
                          AppIcons.notificationsOutlined,
                          AppColors.mediumOf(context),
                          ctx.l10n.protocolNotified,
                          '${ctx.l10n.protocolRecipients(summary.recipientCount)}${summary.taskOwners.isNotEmpty ? ctx.l10n.protocolTaskOwners(summary.taskOwners.length) : ''}',
                        ),
                        IonSwitchListTile(
                          value: sendPdf,
                          onChanged: (v) => setLocal(() => sendPdf = v),
                          title: Text(ctx.l10n.protocolSendPdf),
                          subtitle: Text(ctx.l10n.protocolViaTelegram),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingS),
                      child: Text(ctx.l10n.protocolEditAfterPublish),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      icon: Icon(AppIcons.send),
                      label: IonButtonLabel(_isPublished ? ctx.l10n.protocolFlutterRepublishNotify : ctx.l10n.protocolFlutterPublishNotify),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: IonButtonLabel(_isPublished ? ctx.l10n.commonCancel : ctx.l10n.protocolFlutterKeepDraft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) await _publish(closures, sendPdf);
  }

  Widget _summaryTile(IconData icon, Color color, String title, String? subtitle) => ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: subtitle != null && subtitle.isNotEmpty ? Text(subtitle) : null,
      );

  Future<void> _publish(List<TopicClosure> closures, bool sendPdf) async {
    showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: AppSpinner()),
    );
    try {
      // SOL_FIX2: abort when a section could not be saved – do not publish
      // or notify the team about an incomplete protocol.
      if (!await _flushAll()) {
        if (mounted) ToastHelper.showError(context, context.l10n.protocolNotesSaveFailed);
        return;
      }
      final row = await _repo.publish(widget.attendanceId);
      _applyRow(row);

      // Mark the selected topics as done; a failure does not stop the publish.
      var closeFailed = false;
      for (final c in closures.where((c) => c.close)) {
        try {
          await ref.read(agendaItemNotifierProvider.notifier).update(c.agendaItemId, {'status': 'completed'});
        } catch (_) {
          closeFailed = true;
        }
      }
      if (closeFailed && mounted) {
        ToastHelper.showWarning(context, context.l10n.protocolCloseFailed);
      }

      String? pdfUrl;
      String? pdfPath;
      if (sendPdf) {
        try {
          final branding = await resolvePdfBranding(ref);
          final bytes = await createProtocolPdf(_buildPdfData(branding: branding));
          final upload = await _repo.uploadPdf(widget.attendanceId, bytes);
          pdfUrl = upload.url;
          pdfPath = upload.path;
        } catch (_) {
          if (mounted) {
            ToastHelper.showWarning(context, context.l10n.protocolPdfFailedNotify);
          }
        }
      }
      await _repo.notifyTeam({
        'type': 'protocol_published',
        'attendanceId': widget.attendanceId,
        if (pdfUrl != null) 'pdfUrl': pdfUrl,
      });
      if (pdfPath != null) {
        final path = pdfPath;
        // The edge function fetches the file right away; remove it afterwards.
        unawaited(Future.delayed(const Duration(seconds: 60), () => _repo.removePdf(path)));
      }
      ref.invalidate(protocolsProvider);
      if (mounted) ToastHelper.showSuccess(context, context.l10n.protocolPublished);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.protocolPublishFailed);
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _update(() {});
      }
    }
  }
}
