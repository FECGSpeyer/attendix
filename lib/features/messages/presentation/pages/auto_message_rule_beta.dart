part of 'auto_message_rule_page.dart';

/// REDESIGN (canvas K2 "Regel und Verlauf"): page type "Bearbeiten".
/// "Abbrechen · Regel · Fertig" on top, "Regel / Verlauf" below, the same
/// options as the classic page in Beta lists, chips and segments, deleting
/// at the very end. A rule saves only with "Fertig" (an active rule must
/// not send half-done), which checks name, status, channel and text like
/// the classic "Speichern".
extension _RuleBeta on _AutoMessageRulePageState {
  Widget _buildBeta() {
    final p = context.rd;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RdFormTopBar(
              title: _isNew ? l10n.autoMessagesNewRule : l10n.autoMessagesRule,
              cancel: l10n.redesignCommonCancel,
              submit: l10n.redesignCommonDone,
              saving: _saving,
              onCancel: _saving ? null : () => context.pop(),
              onSubmit: _loading ? null : _save,
            ),
            if (!_loading && !_isNew)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: RdSegmented<_Tab>(
                  values: _Tab.values,
                  selected: _tab,
                  labelOf: (t) => t == _Tab.rule ? l10n.autoMessagesRule : l10n.autoMessagesHistory,
                  onChanged: (v) => _setTab(v),
                ),
              ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: p.primary))
                  : RdFormBody(children: _tab == _Tab.history ? _historyBeta() : _ruleBeta()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Text(text, style: RdType.meta(context.rd, size: 13)),
      );

  Widget _section(String? label, List<Widget> children, {String? hint}) => Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (label != null) RdGroupLabel(label),
            ...children,
            if (hint != null) _hint(hint),
          ],
        ),
      );

  Widget _switchRow(String title, bool value, ValueChanged<bool> onChanged, {String? subtitle}) {
    final p = context.rd;
    return RdListRow(
      title: title,
      subtitle: subtitle,
      showChevron: false,
      trailing: Switch.adaptive(value: value, activeTrackColor: p.primary, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }

  /// A row that is ticked (checkbox or radio, Beta: check circle).
  Widget _checkRow(String title, bool checked, VoidCallback onTap, {String? subtitle}) {
    final p = context.rd;
    return Semantics(
      checked: checked,
      child: RdListRow(
        title: title,
        subtitle: subtitle,
        showChevron: false,
        leading: Icon(
          checked ? Icons.check_circle : Icons.radio_button_unchecked,
          color: checked ? p.primary : p.text2,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _stepperRow(String label, String value, VoidCallback onLess, VoidCallback onMore) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdListRow(
      title: label,
      showChevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RdCircleButton(icon: Icons.remove, label: l10n.autoMessagesLess, onPressed: onLess),
          SizedBox(
            width: 56,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text),
            ),
          ),
          RdCircleButton(icon: Icons.add, label: l10n.autoMessagesMore, onPressed: onMore),
        ],
      ),
    );
  }

  Widget _selectRow<T>(String label, T value, List<AppSelectOption<T>> options, ValueChanged<T> onChanged) {
    return RdListRow(
      title: label,
      value: options.where((o) => o.value == value).firstOrNull?.label ?? '',
      onTap: () async {
        final picked = await showAppSelect<T>(context: context, value: value, options: options, header: label);
        if (picked != null) onChanged(picked.value);
      },
    );
  }

  List<Widget> _ruleBeta() {
    final p = context.rd;
    final l10n = context.l10n;
    final types = (ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[])
        .where((t) => t.visible)
        .toList();
    final groups = (ref.watch(groupsProvider).valueOrNull ?? const []).where((g) => g.id != null).toList();
    final rule = _rule;

    return [
      _section(
        l10n.autoMessagesGeneral,
        [
          RdGroupedList(
            children: [
              RdFieldRow(
                label: l10n.autoMessagesName,
                child: TextField(
                  controller: _nameController,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: rdInputDecoration(p, l10n.autoMessagesName).copyWith(counterText: ''),
                ),
              ),
              _switchRow(l10n.autoMessagesActive, rule.enabled, (v) => _update(_rule.copyWith(enabled: v))),
            ],
          ),
        ],
        hint: l10n.autoMessagesActiveHint,
      ),
      _section(l10n.autoMessagesWhen, [
        RdGroupedList(
          children: [
            for (final s in _AutoMessageRulePageState._statusOptions)
              _checkRow(
                l10n.autoMessageTrigger(s),
                rule.statuses.contains(s),
                () => _update(
                  _rule.copyWith(
                    statuses: rule.statuses.contains(s)
                        ? rule.statuses.where((x) => x != s).toList()
                        : [...rule.statuses, s],
                  ),
                  resetPreview: true,
                ),
                subtitle: l10n.autoMessageTriggerHint(s),
              ),
          ],
        ),
      ]),
      _section(
        l10n.autoMessagesHowOften,
        [
          RdSegmented<AutoMessageFrequency>(
            values: const [AutoMessageFrequency.each, AutoMessageFrequency.streak, AutoMessageFrequency.window],
            selected: rule.frequency,
            labelOf: (f) => switch (f) {
              AutoMessageFrequency.each => l10n.autoMessagesFreqEach,
              AutoMessageFrequency.streak => l10n.autoMessagesFreqStreak,
              AutoMessageFrequency.window => l10n.autoMessagesFreqWindow,
            },
            onChanged: (v) => _update(_rule.copyWith(frequency: v), resetPreview: true),
          ),
          if (rule.frequency != AutoMessageFrequency.each) ...[
            const SizedBox(height: 12),
            RdGroupedList(
              children: [
                _stepperRow(
                  l10n.autoMessagesFreqCount,
                  '${rule.frequencyCount}×',
                  () => _update(
                    _rule.copyWith(frequencyCount: (rule.frequencyCount - 1).clamp(2, 50)),
                    resetPreview: true,
                  ),
                  () => _update(
                    _rule.copyWith(frequencyCount: (rule.frequencyCount + 1).clamp(2, 50)),
                    resetPreview: true,
                  ),
                ),
                if (rule.frequency == AutoMessageFrequency.window)
                  _stepperRow(
                    l10n.autoMessagesFreqDays,
                    l10n.autoMessagesDays(rule.frequencyDays),
                    () => _update(
                      _rule.copyWith(frequencyDays: (rule.frequencyDays - 7).clamp(1, 365)),
                      resetPreview: true,
                    ),
                    () => _update(
                      _rule.copyWith(frequencyDays: (rule.frequencyDays + 7).clamp(1, 365)),
                      resetPreview: true,
                    ),
                  ),
              ],
            ),
          ],
        ],
        hint: l10n.autoMessageFrequencyHint(rule),
      ),
      _section(
        l10n.autoMessagesWhichTermine,
        [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in types)
                RdChoiceChip(
                  label: type.name,
                  selected: rule.typeIds?.contains(type.id) ?? false,
                  onTap: () {
                    final ids = [...?rule.typeIds];
                    ids.contains(type.id) ? ids.remove(type.id) : ids.add(type.id!);
                    _update(_rule.copyWith(typeIds: ids.isEmpty ? null : ids), resetPreview: true);
                  },
                ),
            ],
          ),
        ],
        hint: (rule.typeIds?.isNotEmpty ?? false) ? l10n.autoMessagesTypesSome : l10n.autoMessagesTypesAll,
      ),
      _section(
        l10n.autoMessagesGroups,
        [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final group in groups)
                RdChoiceChip(
                  label: group.name,
                  selected: rule.groupIds?.contains(group.id) ?? false,
                  onTap: () {
                    final ids = [...?rule.groupIds];
                    ids.contains(group.id) ? ids.remove(group.id) : ids.add(group.id!);
                    _update(_rule.copyWith(groupIds: ids.isEmpty ? null : ids), resetPreview: true);
                  },
                ),
            ],
          ),
        ],
        hint: (rule.groupIds?.isNotEmpty ?? false) ? l10n.autoMessagesGroupsSome : l10n.autoMessagesGroupsAll,
      ),
      _section(
        null,
        [
          RdGroupedList(
            children: [
              _selectRow<int>(
                l10n.autoMessagesDelay,
                rule.delayMinutes,
                [
                  for (final d in autoMessageDelayOptions)
                    AppSelectOption(value: d, label: l10n.autoMessageDelayLabel(d)),
                ],
                (v) => _update(_rule.copyWith(delayMinutes: v)),
              ),
            ],
          ),
        ],
        hint: l10n.autoMessagesDelayHint,
      ),
      const SizedBox(height: 16),
      RdInfoCard(icon: Icons.lock_outline, text: l10n.autoMessagesSafety),
      _section(l10n.autoMessagesMessage, [
        RdSegmented<bool>(
          values: const [true, false],
          selected: rule.useTemplate,
          labelOf: (t) => t ? l10n.autoMessagesUseTemplate : l10n.autoMessagesCustomText,
          onChanged: (v) => _setTextMode(!v),
        ),
        const SizedBox(height: 12),
        if (rule.useTemplate) ...[
          RdGroupedList(
            children: [
              _selectRow<String>(
                l10n.autoMessagesTemplate,
                rule.templateKey,
                [
                  for (final tpl in autoMessageTemplates)
                    AppSelectOption(value: tpl, label: l10n.autoMessageTemplateName(tpl)),
                ],
                (v) => _update(_rule.copyWith(templateKey: v)),
              ),
              Builder(
                builder: (context) {
                  final sample = _sample(types);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sample.title, style: TextStyle(fontWeight: FontWeight.w600, color: p.text)),
                        const SizedBox(height: 6),
                        Text(sample.body, style: RdType.meta(p, size: 14)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          _hint(l10n.autoMessagesTemplateHint),
        ] else ...[
          RdGroupedList(
            children: [
              RdFieldRow(
                label: l10n.messagesTitle,
                child: TextField(
                  controller: _titleController,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: rdInputDecoration(p, l10n.messagesTitle).copyWith(counterText: ''),
                ),
              ),
              if (_quill != null) ...[
                MessageEditorToolbar(controller: _quill!),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 160),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: QuillEditor.basic(
                      controller: _quill!,
                      config: QuillEditorConfig(scrollable: false, placeholder: l10n.editorMessagePlaceholder),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ph in autoMessagePlaceholders)
                RdChoiceChip(label: '{$ph}', selected: false, onTap: () => _insertPlaceholder(ph)),
            ],
          ),
          _hint(l10n.autoMessagesCustomHint),
          Align(
            alignment: Alignment.centerLeft,
            child: RdTextLink(label: l10n.autoMessagesResetToTemplate, onTap: _resetToTemplate),
          ),
        ],
      ]),
      _section(l10n.autoMessagesChannels, [
        RdGroupedList(
          children: [
            for (final (channel, label) in [
              ('push', l10n.autoMessagesChannelPush),
              ('email', l10n.autoMessagesChannelEmail),
            ])
              _switchRow(
                label,
                rule.channels.contains(channel),
                (on) => _update(
                  _rule.copyWith(
                    channels: on
                        ? {...rule.channels, channel}.toList()
                        : rule.channels.where((c) => c != channel).toList(),
                  ),
                ),
              ),
          ],
        ),
      ]),
      _section(
        l10n.autoMessagesResponses,
        [
          RdGroupedList(
            children: [
              _switchRow(
                l10n.autoMessagesAllowResponses,
                rule.allowResponses,
                (v) => _update(_rule.copyWith(allowResponses: v)),
                subtitle: l10n.autoMessagesAllowResponsesHint,
              ),
              if (rule.allowResponses)
                for (final (instant, label) in [
                  (false, l10n.autoMessagesExcuseAfterCheck),
                  (true, l10n.autoMessagesExcuseInstant),
                ])
                  _checkRow(label, rule.instantExcuse == instant, () => _update(_rule.copyWith(instantExcuse: instant))),
            ],
          ),
        ],
        hint: rule.allowResponses ? l10n.autoMessagesResponsesHint(autoMessageResponseDays) : null,
      ),
      _section(
        l10n.autoMessagesCopy,
        [
          RdGroupedList(
            children: [
              _checkRow(
                l10n.autoMessagesCopyResponsibles,
                rule.copyResponsibles,
                () => _update(_rule.copyWith(copyResponsibles: !rule.copyResponsibles)),
              ),
              _checkRow(
                l10n.autoMessagesCopyVoiceLeaders,
                rule.copyVoiceLeaders,
                () => _update(_rule.copyWith(copyVoiceLeaders: !rule.copyVoiceLeaders)),
              ),
            ],
          ),
        ],
        hint: l10n.autoMessagesCopyHint,
      ),
      _section(l10n.autoMessagesPreview, [
        RdOutlineButton(
          icon: Icons.visibility_outlined,
          label: l10n.autoMessagesShowPreview,
          onPressed: _previewLoading ? null : _loadPreview,
        ),
        if (_previewLoading) ...[
          const SizedBox(height: 12),
          RdInfoCard(text: l10n.redesignTodayLoading, loading: true),
        ],
        if (_previewError) _hint(l10n.autoMessagesPreviewFailed),
        ..._previewBeta(groups.map((g) => (g.id!, g.name)).toList()),
      ]),
      if (!_isNew) ...[
        const SizedBox(height: 28),
        RdOutlineButton(
          icon: Icons.delete_outline,
          label: l10n.autoMessagesDeleteRule,
          color: p.absent,
          onPressed: _delete,
        ),
      ],
    ];
  }

  List<Widget> _previewBeta(List<(int, String)> groups) {
    final preview = _preview;
    if (preview == null) return const [];
    final l10n = context.l10n;
    final p = context.rd;
    String date(String d) {
      final parsed = DateTime.tryParse(d);
      return parsed == null ? d : rdEventMeta(parsed);
    }

    return [
      if (preview.isEmpty) _hint(l10n.autoMessagesPreviewNoTermine),
      for (final (i, t) in preview.indexed) ...[
        const SizedBox(height: 12),
        RdGroupedList(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t.title} · ${date(t.date)}${t.startTime != null ? ' · ${t.startTime}' : ''}',
                    style: RdType.meta(p, size: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.recorded ? l10n.autoMessagesPreviewWould(t.people.length) : l10n.autoMessagesPreviewNotRecorded,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                  ),
                  if (t.recorded && i == 0 && t.sendAt != null)
                    Text(
                      l10n.autoMessagesPreviewAt(DateFormat('${dateFmt()}, HH:mm').format(t.sendAt!.toLocal())),
                      style: RdType.meta(p, size: 13),
                    ),
                ],
              ),
            ),
            for (final person in t.people)
              RdListRow(
                leading: RdInitials(rdInitialsOf(person.name), size: 32),
                title: person.name,
                subtitle: [
                  groups.where((g) => g.$1 == person.groupId).firstOrNull?.$2 ?? '',
                  if (!person.app && person.email) l10n.autoMessagesOnlyEmail,
                  if (!person.app && !person.email) l10n.autoMessagesUnreachable,
                ].where((s) => s.isNotEmpty).join(' · '),
                showChevron: false,
              ),
            if (t.recorded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Text(l10n.autoMessagesPreviewExcluded(t.excused, t.paused), style: RdType.meta(p, size: 13)),
              ),
          ],
        ),
      ],
      _hint(l10n.autoMessagesPreviewHint),
    ];
  }

  List<Widget> _historyBeta() {
    final p = context.rd;
    final l10n = context.l10n;
    final id = _rule.id;
    if (id == null) return const [];
    final historyAsync = ref.watch(autoMessageHistoryProvider(id));
    return historyAsync.when(
      loading: () => [const SizedBox(height: 12), RdInfoCard(text: l10n.redesignTodayLoading, loading: true)],
      error: (e, _) => [
        const SizedBox(height: 12),
        RdInfoCard(icon: Icons.cloud_off_outlined, text: l10n.autoMessagesLoadFailed),
      ],
      data: (history) {
        final sent = history.where((h) => h.run.status == 'sent');
        final totals = [
          (sent.fold<int>(0, (s, h) => s + h.run.recipientCount), l10n.autoMessagesHistSent),
          (sent.fold<int>(0, (s, h) => s + h.read), l10n.autoMessagesHistRead),
          (sent.fold<int>(0, (s, h) => s + h.responses), l10n.autoMessagesHistResponses),
        ];
        String date(String d) {
          final parsed = DateTime.tryParse(d);
          return parsed == null ? d : rdEventMeta(parsed.toLocal());
        }

        return [
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, (value, label)) in totals.indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: RdCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$value',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: p.text,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(label, maxLines: 2, style: RdType.meta(p, size: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (history.isEmpty)
            RdInfoCard(icon: Icons.history, text: l10n.autoMessagesHistEmpty)
          else
            RdGroupedList(
              children: [
                for (final h in history)
                  RdListRow(
                    title: '${h.title} · ${date(h.date)}',
                    subtitle: switch (h.run.status) {
                      'sent' => l10n.autoMessagesHistRowSent(h.run.recipientCount, h.read, h.responses),
                      'not_recorded' => l10n.autoMessagesHistRowNotRecorded,
                      'suspended' => l10n.autoMessagesHistRowSuspended(h.run.createdByName ?? l10n.commonUnknown),
                      _ => l10n.autoMessagesHistRowNone,
                    },
                    showChevron: h.run.messageId != null,
                    onTap: h.run.messageId == null ? null : () => context.push('/messages/${h.run.messageId}'),
                  ),
              ],
            ),
        ];
      },
    );
  }
}
