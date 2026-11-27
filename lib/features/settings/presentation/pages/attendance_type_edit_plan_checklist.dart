part of 'attendance_type_edit_page.dart';

extension _AttendanceTypeEditPlanChecklist on _AttendanceTypeEditPageState {
  // ---------------------------------------------------------------------------
  // Ablaufplan (Ionic type.page default_plan)
  // ---------------------------------------------------------------------------

  List<PlanField> get _planFieldModels => [for (final f in _planFields) PlanField.fromJson(f)];

  /// Gives a row a unique `uid` as its identity while editing: ids repeat
  /// (free text id = text, e.g. "Pause" twice), the uid travels through the
  /// [PlanFieldsEditor] unchanged. A stored, unique uid is kept; otherwise a
  /// local one is set and removed (or the stored one restored) on save.
  Map<String, dynamic> _withRowUid(Map<String, dynamic> row) {
    final stored = row['uid'];
    final storedUid = stored is String && stored.isNotEmpty ? stored : null;
    final taken = storedUid != null &&
        (_localPlanUids.containsKey(storedUid) || _planFields.any((f) => f['uid'] == storedUid));
    if (storedUid != null && !taken) return row;
    final local = 'local-${PlanUtils.uuid()}';
    _localPlanUids[local] = storedUid;
    return {...row, 'uid': local};
  }

  /// [_planFields] as stored: local row identities removed again.
  List<Map<String, dynamic>> get _planFieldsForSave => [
        for (final f in _planFields)
          if (_localPlanUids.containsKey(f['uid']))
            _localPlanUids[f['uid']] == null
                ? ({...f}..remove('uid'))
                : {...f, 'uid': _localPlanUids[f['uid']]}
          else
            f,
      ];

  /// Back to the stored map: the original row (matched by its row identity
  /// `uid`, see [_withRowUid]) is kept and only updated, so unknown keys and
  /// the legacy `isNote` flag survive. The Flutter-only `isGroup: false`
  /// default is not written.
  void _setPlanFields(List<PlanField> fields) {
    _update(() {
      _planFields = mergePlanRows(_planFields, fields);
      _calculateEnd();
      _hasChanges = true;
    });
  }

  /// Ionic calculateEnd(): start time + all minutes, shown as "Ende".
  void _calculateEnd() {
    final start = _startTime ?? const TimeOfDay(hour: 19, minute: 0);
    var minutes = start.hour * 60 + start.minute;
    for (final f in _planFields) {
      minutes += int.tryParse('${f['time'] ?? ''}'.trim()) ?? 0;
    }
    _planEnd = PlanUtils.formatMinutes(minutes);
  }

  void _addPlanRow(Map<String, dynamic> field) {
    _update(() {
      _planFields = [..._planFields, _withRowUid(field)];
      _calculateEnd();
      _hasChanges = true;
    });
  }

  Widget _buildPlanSection() {
    final l10n = context.l10n;
    final isGeneral = _isGeneral;
    final org = ref.watch(currentOrganisationProvider).valueOrNull;
    final start = _formatTime(_startTime ?? const TimeOfDay(hour: 19, minute: 0));
    return _section(
      title: l10n.typeSettingsRunSheet,
      action: Builder(
        builder: (anchorContext) => IconButton(
          tooltip: l10n.typeSettingsAddField,
          icon: Icon(AppIcons.add, color: AppColors.primary),
          onPressed: () => _showPlanAddMenu(anchorContext),
        ),
      ),
      items: [
          SettingsStackedField(
            flush: _flush,
            label: l10n.typeSettingsPlanHeading,
            helper: l10n.typeSettingsTitleHelper,
            builder: (decoration) => TextFormField(
              controller: _planningTitleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: decoration,
              onChanged: (value) {
                _planningTitle = value;
                _hasChanges = true;
              },
            ),
          ),
          // SETTINGS2: Ionic "Instanz-Name vor Werken" (not for general tenants)
          if (!isGeneral)
            IonSwitchListTile(
              contentPadding: _rowPad,
              title: Text(l10n.typeSettingsTenantNameBefore),
              subtitle: Text(l10n.typeSettingsTenantNameHelper),
              value: _planningPrefixInstanceName,
              onChanged: (v) => _update(() {
                _planningPrefixInstanceName = v;
                _hasChanges = true;
              }),
            ),
          // ORG_PLANS: Ionic `@if (db.organisation())`, saved with the FAB.
          // Disabled until the stored value is loaded (it is only saved then).
          if (org != null)
            IonSwitchListTile(
              contentPadding: _rowPad,
              title: Text(l10n.typeSettingsOrgPlanDefault),
              value: _isDefaultOrgPlan,
              onChanged: _isDefaultOrgPlanLoaded
                  ? (v) => _update(() {
                        _isDefaultOrgPlan = v;
                        _hasChanges = true;
                      })
                  : null,
            ),
          // Ionic: "Start" always; editable only for all-day types (otherwise
          // the type's start time, disabled).
          ListTile(
            contentPadding: _rowPad,
            title: Text(l10n.typeSettingsStartShort),
            subtitle: _allDay ? Text(l10n.typeSettingsStartAllDay) : null,
            trailing: _timeValue(
              start,
              onTap: _allDay ? () => _pickTime(isStart: true) : null,
              betaColor: _allDay ? null : AppColors.mediumOf(context),
            ),
            onTap: _allDay ? () => _pickTime(isStart: true) : null,
          ),
          PlanFieldsEditor(
            templateMode: true,
            fields: _planFieldModels,
            startTime: start,
            emptyText: '',
            onChanged: _setPlanFields,
          ),
          if (_planEnd != null)
            ListTile(
              contentPadding: _rowPad,
              title: Text(l10n.typeSettingsEnd),
              trailing: _timeValue(_planEnd!, betaColor: AppColors.mediumOf(context)),
            ),
        ],
    );
  }

  Future<void> _showPlanAddMenu(BuildContext anchorContext) async {
    final l10n = context.l10n;
    final box = anchorContext.findRenderObject() as RenderBox;
    final overlay = Navigator.of(anchorContext).overlay!.context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
    final action = await showMenu<String>(
      context: anchorContext,
      position: RelativeRect.fromRect(Rect.fromPoints(topLeft, bottomRight), Offset.zero & overlay.size),
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 320),
      items: [
        PopupMenuItem(value: 'field', child: Text(l10n.typeSettingsAddField)),
        PopupMenuItem(value: 'note', child: Text(l10n.typeSettingsAddNoteField)),
        if (!_isGeneral) PopupMenuItem(value: 'song', child: Text(l10n.typeSettingsSongPlaceholder)),
        if (_protocol.enableProtocol)
          PopupMenuItem(
            value: 'agenda',
            child: Row(children: [
              Icon(AppIcons.commit, color: AppColors.mediumOf(context)),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.typeSettingsAgendaPlaceholder)),
            ]),
          ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'field':
        await _addPlanField();
      case 'note':
        await _addNoteField();
      case 'song':
        _addSongPlaceholder();
      case 'agenda':
        _addAgendaPlaceholder();
    }
  }

  /// Ionic addExtraField: free text + optional info; id = text, 20 minutes.
  Future<void> _addPlanField() async {
    final l10n = context.l10n;
    final result = await showPlanFieldDialog(
      context,
      title: l10n.typeSettingsAddField,
      nameLabel: '',
      nameHint: l10n.typeSettingsFreeTextPh,
      infoHint: l10n.typeSettingsInfoOptional,
      withConductor: false,
      withMinutes: false,
      requireName: false,
    );
    if (result == null || !mounted) return;
    _addPlanRow({
      'id': result.name,
      'name': result.name,
      if (result.info != null) 'info': result.info,
      'time': '20',
    });
  }

  /// Ionic addNoteField: id `noteFld <text>`, no time.
  Future<void> _addNoteField() async {
    final l10n = context.l10n;
    final result = await showPlanFieldDialog(
      context,
      title: l10n.typeSettingsAddNoteField,
      nameLabel: '',
      nameHint: l10n.typeSettingsNotePh,
      withConductor: false,
      withInfo: false,
      withMinutes: false,
      requireName: false,
    );
    if (result == null || !mounted) return;
    _addPlanRow({
      'id': 'noteFld ${result.name}',
      'name': result.name,
      'conductor': '',
      'time': '0',
    });
  }

  /// Ionic addSongPlaceholder: numbered from 1.
  void _addSongPlaceholder() {
    final n = _planFields.where((f) => '${f['id'] ?? ''}'.startsWith('song-placeholder-')).length + 1;
    _addPlanRow({
      'id': 'song-placeholder-$n',
      'name': context.l10n.typeSettingsSongPlaceholderN(n),
      'time': '20',
    });
  }

  /// Ionic addAgendaItemsPlaceholder: only once.
  void _addAgendaPlaceholder() {
    if (hasAgendaPlaceholder(_planFields)) {
      ToastHelper.showWarning(context, context.l10n.typeSettingsAgendaExists);
      return;
    }
    _addPlanRow(agendaPlaceholderField());
  }

  // ---------------------------------------------------------------------------
  // Checkliste (Ionic type.page)
  // ---------------------------------------------------------------------------


  String _deadlinePresetLabel(int hours) =>
      hours == 168 ? context.l10n.redesignCreateDeadlineWeek : _checklistDeadlineText(hours);

  Widget _buildChecklistSection() {
    final l10n = context.l10n;
    final showCustom = _newTodoDeadline == -1;
    return _section(
      title: l10n.typeSettingsChecklist,
      action: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: IonBadge(text: '${_checklist.length}', color: AppColors.mediumOf(context)),
      ),
      items: [
          if (_checklist.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _checklist.length,
              onReorderItem: (oldIndex, newIndex) {
                _update(() {
                  final item = _checklist.removeAt(oldIndex);
                  _checklist.insert(newIndex, item);
                  _hasChanges = true;
                });
              },
              itemBuilder: (context, index) {
                final item = _checklist[index];
                // Ionic: ion-item-sliding with a trash option,
                // deadline text as subtitle, reorder handle at the end.
                return SwipeActions.delete(
                  key: ObjectKey(item),
                  onDelete: () => _update(() {
                    _checklist.removeAt(index);
                    _hasChanges = true;
                  }),
                  child: ListTile(
                    contentPadding: _rowPad,
                    title: Text(item.text),
                    subtitle: Text(_checklistDeadlineText(item.deadlineHours)),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: Icon(AppIcons.reorder, color: AppColors.mediumOf(context)),
                    ),
                    onTap: () => _editChecklistItem(index),
                  ),
                );
              },
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(AppIcons.checkBoxOutlined, size: 32, color: AppColors.mediumOf(context)),
                  const SizedBox(height: 4),
                  Text(l10n.typeSettingsNoTodos, style: TextStyle(color: AppColors.mediumOf(context))),
                ],
              ),
            ),
          // Ionic: inline "Neues To-Do" + "Deadline" (action sheet) + button.
          SettingsStackedField(
            flush: _flush,
            label: l10n.typeSettingsNewTodo,
            hint: l10n.typeSettingsTodoPlaceholder,
            builder: (decoration) => TextField(
              controller: _newTodoController,
              textCapitalization: TextCapitalization.sentences,
              decoration: decoration,
              onChanged: (_) => _update(() {}),
            ),
          ),
          SettingsStackedField(
            flush: _flush,
            label: l10n.typeSettingsDeadline,
            // Own Form: a deadline for a not yet added to-do is no change of
            // the type (Ionic compares only the type).
            builder: (decoration) => Form(
              child: AppDropdownFormField<int?>(
                interface: AppSelectInterface.actionSheet,
                decoration: decoration.copyWith(hintText: l10n.typeSettingsNoDeadline),
                value: _newTodoDeadline,
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.typeSettingsNoDeadline)),
                  for (final h in _deadlinePresets)
                    DropdownMenuItem(value: h, child: Text(_deadlinePresetLabel(h))),
                  DropdownMenuItem(value: -1, child: Text(l10n.typeSettingsCustomDots)),
                ],
                onChanged: (v) => _update(() => _newTodoDeadline = v),
              ),
            ),
          ),
          if (showCustom)
            SettingsStackedField(
              flush: _flush,
              label: l10n.typeSettingsHoursBefore,
              hint: 'z.B. 12',
              builder: (decoration) => TextField(
                controller: _customDeadlineController,
                keyboardType: TextInputType.number,
                decoration: decoration,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilledButton.icon(
              onPressed: _newTodoController.text.trim().isEmpty ? null : _addChecklistItem,
              icon: Icon(AppIcons.addCircleOutline),
              label: IonButtonLabel(l10n.typeSettingsAddTodo),
            ),
          ),
        ],
    );
  }

  /// Ionic addChecklistItem.
  void _addChecklistItem() {
    final text = _newTodoController.text.trim();
    if (text.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.typeSettingsEnterTodo);
      return;
    }
    int? deadline = _newTodoDeadline;
    if (deadline == -1) {
      final custom = int.tryParse(_customDeadlineController.text.trim());
      deadline = custom != null && custom != 0 ? custom : null;
    }
    _update(() {
      _checklist = [
        ..._checklist,
        ChecklistItem(id: PlanUtils.uuid(), text: text, deadlineHours: deadline),
      ];
      _newTodoController.clear();
      _customDeadlineController.clear();
      _newTodoDeadline = null;
      _hasChanges = true;
    });
  }

  /// Ionic editChecklistItem: alert "To-Do bearbeiten" with the text only.
  Future<void> _editChecklistItem(int index) async {
    final item = _checklist[index];
    final text = await showPlanFieldDialog(
      context,
      title: context.l10n.typeSettingsEditTodo,
      nameLabel: '',
      nameHint: context.l10n.typeSettingsTodoTextPh,
      initialName: item.text,
      confirmText: context.l10n.commonSave,
      withConductor: false,
      withInfo: false,
      withMinutes: false,
      requireName: false,
    );
    if (text == null || text.name.isEmpty || !mounted) return;
    _update(() {
      _checklist[index] = item.copyWith(text: text.name);
      _hasChanges = true;
    });
  }

  /// Ionic getChecklistDeadlineText / getFormattedReminder.
  String _checklistDeadlineText(int? hours) {
    final l10n = context.l10n;
    if (hours == null) return l10n.typeSettingsNoDeadline;
    if (hours == 0) return l10n.typeSettingsSameTime;
    if (hours < 24) return l10n.typeSettingsHoursBeforeN(hours);
    return l10n.typeSettingsDaysBeforeN(hours ~/ 24);
  }

}

const _deadlinePresets = [1, 24, 48, 168];
