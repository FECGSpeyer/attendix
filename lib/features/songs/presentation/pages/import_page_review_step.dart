part of 'import_page.dart';

extension _RdImportReviewStep on _RdImportPageState {
  Widget _questions(BuildContext context, RdImportState state) {
    final p = context.rd;
    final l10n = context.l10n;
    final kind = ref.watch(rdGroupKindProvider);
    final plan = state.plan!;
    final d = state.decisions;
    final existing = plan.works.where((w) => w.match.songId != null).length;
    final created = plan.works.where((w) => rdDefaultTarget(plan, w).isNew).length;
    final unanswered = plan.questions.where((q) => d.answers[q.key] == null && q.proposed == null).length;
    final pendingGroups = rdImportPendingGroups(plan, d);
    final openOnly = _openOnly;
    final questions = openOnly == null ? plan.questions : [for (final q in plan.questions) if (openOnly.contains(q.key)) q];
    // Werk folders the KI is asked about, or answered for.
    final askWorks =
        rdImportWorksToAsk(plan).isNotEmpty || plan.works.any((w) => w.match.kind == RdMatchKind.byAi);
    final aiSwitch = RdGroupedList(
      children: [
        RdSwitchRow(
          title: l10n.redesignImportAiOption,
          subtitle: l10n.redesignImportAiOptionDetail,
          value: state.useAi,
          onChanged: _controller.setUseAi,
        ),
      ],
    );
    return RdImportFrame(
      backLabel: _fromReview ? l10n.redesignImportStepReview : l10n.redesignImportStepSource,
      onBack: _back,
      title: l10n.redesignImportTitle,
      step: 2,
      children: [
        // From the review: only the open questions, then back to it.
        if (openOnly == null) ...[
          RdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.sourceName ?? '', style: RdType.section(p)),
                const SizedBox(height: 4),
                Text(
                  [
                    l10n.redesignImportFoundFiles(plan.fileCount),
                    l10n.redesignImportFoundWorks(plan.works.length),
                  ].join(' · '),
                  style: RdType.body(p),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    l10n.redesignImportFoundExisting(existing),
                    l10n.redesignImportFoundNew(created),
                  ].join(' · '),
                  style: RdType.meta(p),
                ),
              ],
            ),
          ),
          // Changing it compares the Werke again (their decisions start over).
          ..._collectionChoice(context, state),
          const SizedBox(height: 20),
        ],
        if (questions.isEmpty) ...[
          RdCard(child: Text(l10n.redesignImportQuestionsNone, style: RdType.body(p))),
          // Unsure Werk folders go to the KI too: the switch stays.
          if (askWorks) ...[
            const SizedBox(height: 10),
            aiSwitch,
          ],
        ] else ...[
          RdSectionHeader(
            openOnly == null
                ? l10n.redesignImportQuestionsTitle(questions.length)
                : l10n.redesignImportQuestionsOpenTitle(questions.length),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(l10n.redesignImportQuestionsIntro, style: RdType.meta(p, size: 13)),
          ),
          // The switch sits above the questions: the names go to the KI
          // only while it is on.
          aiSwitch,
          const SizedBox(height: 10),
          if (_aiNote(context, state) case final note?)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    if (state.aiStatus == RdImportAiStatus.loading)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary)),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ExcludeSemantics(child: Icon(Icons.auto_awesome, size: 16, color: p.primary)),
                      ),
                    Expanded(child: Text(note, style: RdType.meta(p, size: 13))),
                  ],
                ),
              ),
            ),
          if (openOnly == null && questions.length >= _groupFrom) ...[
            // Many names: by the instrument they most likely mean, to take
            // a whole group with one tap.
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                l10n.redesignImportQuestionsAnswered(questions.length - unanswered, questions.length),
                style: RdType.meta(p, size: 13),
              ),
            ),
            for (final g in rdImportQuestionGroups(
              questions,
              answers: d.answers,
              ai: {
                if (state.useAi)
                  for (final e in state.ai.entries) e.key: e.value.category,
              },
            )) ...[
              Builder(builder: (context) {
                final title = g.category == null
                    ? l10n.redesignImportGroupUnclear
                    : g.category!.newGroup != null
                        ? l10n.redesignImportAnswerNewGroup(kind, g.category!.newGroup!)
                        : rdImportCategoryLabel(context, plan, g.category!);
                final open = _groupOpen[title] ?? g.category == null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _QuestionGroupCard(
                      title: title,
                      group: g,
                      decisions: d,
                      aiFilled: state.aiFilled,
                      open: open,
                      onToggle: () => _update(() => _groupOpen[title] = !open),
                      onAll: _controller.answerAll,
                    ),
                    if (open)
                      for (final q in g.questions)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 8),
                          child: _questionCard(state, q, pendingGroups),
                        ),
                  ],
                );
              }),
              const SizedBox(height: 10),
            ],
          ] else
            for (final q in questions) ...[
              _questionCard(state, q, pendingGroups),
              const SizedBox(height: 10),
            ],
          if (openOnly != null && questions.length < plan.questions.length)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _update(() => _openOnly = null),
                child: Text(l10n.redesignImportQuestionsShowAll),
              ),
            ),
        ],
        if (openOnly == null) ...[
          const SizedBox(height: 10),
          RdSectionHeader(l10n.redesignImportOptionsTitle),
          RdGroupedList(
            children: [
              RdSwitchRow(
                title: l10n.redesignImportOptionFassung,
                subtitle: l10n.redesignImportOptionFassungDetail,
                value: d.proposeFassung,
                onChanged: _controller.setProposeFassung,
              ),
              RdSwitchRow(
                title: l10n.redesignImportOptionWord,
                subtitle: l10n.redesignImportOptionWordDetail,
                value: d.skipWordBesidePdf,
                onChanged: _controller.setSkipWordBesidePdf,
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        if (unanswered > 0) ...[
          Text(l10n.redesignImportQuestionsOpen(unanswered), style: RdType.meta(p, size: 13)),
          const SizedBox(height: 10),
        ],
        RdPrimaryButton(
          label: _preparing ? l10n.redesignImportPreparing : l10n.redesignImportToReview,
          loading: _preparing,
          // A Sammlung being made is the target: on only once it is chosen.
          onPressed: _addingCollection ? null : _toReview,
        ),
      ],
    );
  }

  Widget _questionCard(RdImportState state, RdImportQuestion q, List<String> pendingGroups) {
    final d = state.decisions;
    return _QuestionCard(
      plan: state.plan!,
      question: q,
      // A known instrument without a group: its new group counts until the
      // person answers.
      answer: d.answers[q.key] ?? q.proposed,
      proposedOnly: !d.answers.containsKey(q.key) && q.proposed != null,
      newGroups: pendingGroups,
      ai: state.useAi ? state.ai[q.key]?.category : null,
      filled: state.aiFilled.contains(q.key),
      readPages: state.useAi && _controller.canReadPages(q),
      onAnswer: (a) => _controller.answer(q.key, a),
      // First pages of some of its files, to see what the name means.
      preview: q.examples.any((e) => rdImportPreviewable(e.file))
          ? () => RdImportQuestionPreview(
                examples: [for (final e in q.examples) if (rdImportPreviewable(e.file)) e],
                page: _controller.pagePreview,
                link: _controller.viewLink,
              )
          : null,
    );
  }

  /// "Zur Prüfung": answers the KI filled in are confirmed first (they are
  /// used for every file with the name and learned as terms).
  Future<void> _toReview() async {
    if (_preparing) return;
    final filled = ref.read(rdImportProvider).aiFilled.length;
    if (filled > 0) {
      final l10n = context.l10n;
      final ok = await showAppConfirm(
        context,
        title: l10n.redesignImportAiConfirmTitle,
        message: l10n.redesignImportAiConfirmMessage(filled),
        confirmText: l10n.redesignImportAiConfirmButton,
        cancelText: l10n.redesignImportAiConfirmCancel,
      );
      if (!ok || !mounted) return;
      _controller.confirmAi();
    }
    _update(() {
      _filter = null;
      _openOnly = null;
      _fromReview = false;
      _preparing = true;
    });
    // Show "Wird vorbereitet …" before the work blocks the page.
    await WidgetsBinding.instance.endOfFrame;
    try {
      if (mounted) await _controller.goTo(RdImportStep.review);
    } finally {
      if (mounted) _update(() => _preparing = false);
    }
  }

  /// What the KI did with the questions; null when it was not asked.
  String? _aiNote(BuildContext context, RdImportState state) {
    final l10n = context.l10n;
    if (!state.useAi) return null;
    return switch (state.aiStatus) {
      RdImportAiStatus.off => null,
      RdImportAiStatus.loading => l10n.redesignImportAiLoading,
      RdImportAiStatus.limit => l10n.redesignImportAiLimit,
      RdImportAiStatus.failed => l10n.redesignImportAiFailed,
      RdImportAiStatus.done => state.aiFilled.isNotEmpty
          ? l10n.redesignImportAiFilled(state.aiFilled.length)
          : state.ai.isNotEmpty
              ? l10n.redesignImportAiOffered
              : l10n.redesignImportAiNone,
    };
  }

  /// How far the KI got with the first pages of unclear parts; null when
  /// it is not reading.
  String? _pagesNote(BuildContext context, RdImportState state) {
    final pages = state.pages;
    if (!state.useAi) return null;
    if (pages.limit) return context.l10n.redesignImportPagesLimit;
    return pages.done < pages.total ? context.l10n.redesignImportPagesReading(pages.done, pages.total) : null;
  }

  // -------------------------------------------------------------------------
  // 3 Prüfen

  Widget _review(BuildContext context, RdImportState state) {
    final p = context.rd;
    final l10n = context.l10n;
    final plan = state.plan!;
    final d = state.decisions;
    final states = {for (final w in plan.works) w.key: rdWorkState(plan, d, w)};
    final summary = rdImportSummary(plan, d);
    final unanswered = plan.questions.where((q) => d.answers[q.key] == null && q.proposed == null).length;
    final open = plan.works.where((w) => states[w.key]!.open).toList();
    final created = plan.works.where((w) => states[w.key]!.target.isNew).toList();
    final filter = _filter ?? (open.isNotEmpty ? _Filter.open : _Filter.all);
    final shown = switch (filter) {
      _Filter.open => [for (final w in plan.works) if (states[w.key]!.open || d.confirmed.contains(w.key) && states[w.key]!.flags.isNotEmpty) w],
      _Filter.created => created,
      _Filter.all => plan.works,
    };
    return RdImportFrame(
      backLabel: l10n.redesignImportStepRead,
      onBack: _back,
      title: l10n.redesignImportTitle,
      step: 3,
      children: [
        if (unanswered > 0) ...[
          RdInfoCard(
            text: l10n.redesignImportReviewQuestionsOpen(unanswered),
            icon: Icons.help_outline,
            action: RdOutlineButton(
              label: l10n.redesignImportReviewAnswer,
              onPressed: () {
                _update(() {
                  _openOnly = {
                    for (final q in plan.questions)
                      if (d.answers[q.key] == null && q.proposed == null) q.key,
                  };
                  _fromReview = true;
                });
                _controller.goTo(RdImportStep.questions);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_pagesNote(context, state) case final note?) ...[
          Text(note, style: RdType.meta(p, size: 13)),
          const SizedBox(height: 8),
        ],
        // The upload stays at the top: the list can be long.
        if (state.readingDates) ...[
          Text(l10n.redesignImportDatesReading, style: RdType.meta(p, size: 13)),
          const SizedBox(height: 8),
        ] else if (summary.open > 0) ...[
          Text(l10n.redesignImportOpenHint(summary.open), style: RdType.meta(p, size: 13)),
          const SizedBox(height: 8),
        ],
        RdPrimaryButton(
          label: l10n.redesignImportUploadButton(summary.take),
          onPressed: summary.take == 0 || state.readingDates ? null : _startUpload,
        ),
        const SizedBox(height: 20),
        RdSegmented<_Filter>(
          values: _Filter.values,
          selected: filter,
          labelOf: (f) => switch (f) {
            _Filter.open => l10n.redesignImportReviewOpen(open.length),
            _Filter.created => l10n.redesignImportReviewNew(created.length),
            _Filter.all => l10n.redesignImportReviewAll(plan.works.length),
          },
          onChanged: (f) => _update(() => _filter = f),
        ),
        const SizedBox(height: 12),
        Text(l10n.redesignImportReviewIntro, style: RdType.meta(p, size: 13)),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          RdCard(child: Text(l10n.redesignImportReviewEmpty, style: RdType.body(p)))
        else
          RdGroupedList(
            children: [
              for (final w in shown)
                RdListRow(
                  title: w.folderName,
                  subtitle: rdImportWorkSubtitle(context, plan, w, states[w.key]!),
                  footer: switch (rdImportFlagPills(context, states[w.key]!)) {
                    final pills when pills.isNotEmpty => Wrap(spacing: 6, runSpacing: 6, children: pills),
                    _ => null,
                  },
                  onTap: () {
                    _controller.readFirst(w.key);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => RdImportWorkPage(workKey: w.key)),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 4 Hochladen

  Widget _upload(BuildContext context, RdImportState state) {
    final p = context.rd;
    final l10n = context.l10n;
    final kind = ref.watch(rdGroupKindProvider);
    final upload = state.upload;
    final plan = state.plan;
    if (upload == null || plan == null) return _source(context);
    final finished = state.step == RdImportStep.done;
    final ok = upload.succeeded;
    final summary = rdImportSummary(plan, state.decisions);
    final retry = {for (final f in upload.failures) if (f.path.isNotEmpty) f.path};

    if (!finished) {
      final value = upload.total == 0 ? 0.0 : upload.done / upload.total;
      final left = rdImportTimeLeftText(l10n, upload);
      return RdImportFrame(
        title: l10n.redesignImportTitle,
        step: 4,
        children: [
          RdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l10n.redesignImportUploadTitle, style: RdType.section(p))),
                    Text('${(value * 100).round()} %', style: RdType.meta(p)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [l10n.redesignImportUploadProgress(upload.done, upload.total), if (left != null) left].join(' · '),
                  style: RdType.meta(p),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: value, minHeight: 10, color: p.primary, backgroundColor: p.track),
                ),
                if (upload.current != null) ...[
                  const SizedBox(height: 10),
                  Text(upload.current!, style: RdType.meta(p, size: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 14),
                RdHintBox(l10n.redesignImportKeepOpen),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (upload.cancelled)
            Text(l10n.redesignImportCancelling, style: RdType.meta(p, size: 13), textAlign: TextAlign.center)
          else
            RdOutlineButton(label: l10n.redesignImportCancel, icon: Icons.close, onPressed: _cancelUpload),
        ],
      );
    }

    // Not uploaded because of "Abbrechen" apart from those that failed.
    final failures = [for (final f in upload.failures) if (!f.cancelled) f];
    final notUploaded = upload.failures.length - failures.length;
    // Retrying and the open Werke still need the shared folder.
    final needsLink = retry.isNotEmpty || summary.open > 0;
    return RdImportFrame(
      title: l10n.redesignImportTitle,
      step: 4,
      children: [
        RdCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: upload.failures.isEmpty ? p.presentSoft : p.lateSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  upload.failures.isEmpty ? Icons.check : Icons.priority_high,
                  color: upload.failures.isEmpty ? p.present : p.late,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.redesignImportDoneTitle, style: RdType.section(p)),
                    const SizedBox(height: 2),
                    Text(l10n.redesignImportDoneText(ok), style: RdType.body(p)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (upload.aborted) ...[
          const SizedBox(height: 12),
          RdCard(child: Text(l10n.redesignImportDoneAborted, style: RdType.body(p).copyWith(color: p.absent))),
        ] else if (upload.cancelled) ...[
          const SizedBox(height: 12),
          RdCard(child: Text(l10n.redesignImportDoneCancelled(notUploaded), style: RdType.body(p))),
        ],
        if (upload.learnFailed) ...[
          const SizedBox(height: 12),
          RdCard(child: Text(l10n.redesignImportLearnFailed, style: RdType.body(p).copyWith(color: p.late))),
        ],
        const SizedBox(height: 16),
        RdGroupedList(
          children: [
            RdListRow(title: l10n.redesignImportDoneNewWorks, value: '${upload.newWorks}', showChevron: false),
            if (upload.newGroups > 0) RdListRow(title: l10n.redesignImportDoneNewGroups(kind), value: '${upload.newGroups}', showChevron: false),
            RdListRow(title: l10n.redesignImportDoneLearned, value: '${upload.learned}', showChevron: false),
            RdListRow(title: l10n.redesignImportDoneSkipped, value: '${summary.skip}', showChevron: false),
            if (summary.open > 0) RdListRow(title: l10n.redesignImportDoneOpen, value: '${summary.open}', showChevron: false),
            if (notUploaded > 0) RdListRow(title: l10n.redesignImportDoneNotUploaded, value: '$notUploaded', showChevron: false),
            if (failures.isNotEmpty)
              RdListRow(title: l10n.redesignImportDoneFailed, value: '${failures.length}', showChevron: false, titleColor: p.absent),
          ],
        ),
        if (failures.isNotEmpty) ...[
          const SizedBox(height: 16),
          RdGroupedList(
            children: [
              for (final f in failures.take(50))
                RdListRow(
                  title: f.path.isEmpty ? f.error : f.path.split('/').last,
                  subtitle: f.path.isEmpty ? null : '${f.work} · ${f.error}',
                  showChevron: false,
                ),
            ],
          ),
        ],
        if (retry.isNotEmpty) ...[
          const SizedBox(height: 12),
          RdOutlineButton(
            label: notUploaded > 0 ? l10n.redesignImportDoneRetryRest : l10n.redesignImportDoneRetry,
            icon: Icons.refresh,
            onPressed: () => _controller.upload(only: retry),
          ),
        ],
        if (summary.open > 0) ...[
          const SizedBox(height: 16),
          Text(
            state.driveFolder != null ? l10n.redesignImportDoneAgainHintDrive : l10n.redesignImportDoneAgainHint,
            style: RdType.meta(p, size: 13),
          ),
        ],
        // Last: once the folder is no longer shared, retrying fails.
        if (state.driveFolder != null) ...[
          const SizedBox(height: 16),
          RdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.redesignImportUnshareTitle, style: RdType.section(p)),
                const SizedBox(height: 4),
                Text(needsLink ? l10n.redesignImportUnshareTextLater : l10n.redesignImportUnshareText, style: RdType.body(p)),
                const SizedBox(height: 12),
                RdOutlineButton(
                  label: l10n.redesignImportUnshareOpen,
                  icon: Icons.open_in_new,
                  onPressed: () => _openDrive(state.driveFolder),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        RdPrimaryButton(label: l10n.redesignImportDoneToWorks, onPressed: _leave),
        const SizedBox(height: 8),
        Center(child: RdTextLink(label: l10n.redesignImportDoneAnother, onTap: _startOver)),
      ],
    );
  }
}
