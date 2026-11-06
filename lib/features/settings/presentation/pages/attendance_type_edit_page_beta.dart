part of 'attendance_type_edit_page.dart';

/// REDESIGN (Termin-Werkzeuge T3): "Terminart bearbeiten" in the Beta look,
/// like "Termin bearbeiten": every change is saved right away (no Speichern,
/// no "Ungespeicherte Änderungen"). Often used settings on top, each
/// feature is one row with its state that opens its own small page. The
/// data, the update columns and the sub-editors are the classic page's.
extension _AttendanceTypeBeta on _AttendanceTypeEditPageState {
  Widget _rdBuild(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    // Changes made on a sub-page show there too.
    WidgetsBinding.instance.addPostFrameCallback((_) => _rdTick.value++);
    _rdNotifier ??= ref.read(attendanceTypeNotifierProvider.notifier);
    _rdContainer ??= ProviderScope.containerOf(context, listen: false);
    if (!_rdListening) {
      _rdListening = true;
      for (final c in [_planningTitleController, _durationDaysController, _customDeadlineController]) {
        c.addListener(_rdOnText);
      }
    }
    final json = _rdJson();
    _rdSavedJson ??= json;
    if (json != _rdSavedJson && json != _rdFailedJson && !_rdSaving && !(_rdSaveTimer?.isActive ?? false)) {
      _hasChanges = true;
      _rdScheduleSave();
    }
    final statuses = _AttendanceTypeEditPageState._statusOrder.where(_availableStatuses.contains).toList();
    final defaultStatus =
        _availableStatuses.contains(_defaultStatus) ? _defaultStatus : (statuses.firstOrNull ?? _defaultStatus);
    final start = _formatTime(_startTime ?? const TimeOfDay(hour: 19, minute: 0));
    final end = _formatTime(_endTime ?? const TimeOfDay(hour: 20, minute: 30));
    final planCount = _planFields.length;
    final groupCount = _relevantGroups.length;
    String onOff(bool v) => v ? l10n.redesignTypeOn : l10n.redesignTypeOff;

    Widget toggle(String title, String? subtitle, bool value, void Function(bool) set, {Key? key}) => RdListRow(
      key: key,
      title: title,
      subtitle: subtitle,
      showChevron: false,
      onTap: () => _rdSet(() => set(!value)),
      trailing: Switch.adaptive(value: value, onChanged: (v) => _rdSet(() => set(v))),
    );
    Widget feature(IconData icon, String title, String value, VoidCallback onTap, {String? subtitle}) =>
        RdListRow(leading: RdRowIcon(icon), title: title, subtitle: subtitle, value: value, onTap: onTap);

    return RdPage(
      children: [
        Row(
          children: [
            Expanded(
              child: RdBackLink(
                label: rdManageTitle(l10n, RdManageEntry.attendanceTypes),
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            Text(
              _rdSaving
                  ? l10n.redesignPlanSaving
                  : _rdInvalid
                  ? ''
                  : l10n.redesignPlanSaved,
              style: RdType.meta(p, size: 14),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(
            _nameController.text.trim().isEmpty ? l10n.typeSettingsFlutterTypeTitle : _nameController.text.trim(),
            style: RdType.title(p),
          ),
        ),
        if (_rdInvalid) ...[
          const SizedBox(height: 12),
          RdInfoCard(icon: Icons.error_outline, text: l10n.redesignTypeInvalid),
        ],
        if (_usageCount > 0) ...[
          const SizedBox(height: 12),
          RdInfoCard(icon: Icons.info_outline, text: l10n.redesignTypeUsage(_usageCount)),
        ],
        const SizedBox(height: 16),
        RdGroupedList(
          children: [
            RdPlanTextRow(label: l10n.planningName, controller: _nameController, onChanged: (_) => _rdSet(() {})),
          ],
        ),
        const SizedBox(height: 16),
        RdGroupLabel(l10n.redesignTypeAttendance),
        RdGroupedList(
          children: [
            RdListRow(
              title: l10n.redesignTypeStatuses,
              subtitle: statuses.map(_getStatusName).join(', '),
              onTap: _pickAvailableStatuses,
            ),
            RdListRow(
              title: l10n.redesignTypeDefault,
              value: _getStatusName(defaultStatus),
              onTap: () => _rdPickDefaultStatus(statuses),
            ),
            toggle(
              l10n.typeSettingsCountForAvg,
              l10n.typeSettingsCountForAvgHelper,
              _includeInAverage,
              (v) => _includeInAverage = v,
            ),
          ],
        ),
        const SizedBox(height: 16),
        RdGroupLabel(l10n.redesignTypeTime),
        RdGroupedList(
          children: [
            toggle(l10n.typeSettingsAllDay, null, _allDay, (v) => _allDay = v),
            if (_allDay)
              RdListRow(
                title: l10n.redesignTypeDays,
                showChevron: false,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.redesignPlanLess,
                      icon: Icon(Icons.remove_circle_outline, color: p.link),
                      onPressed: _durationDays <= 1 ? null : () => _rdSetDays(_durationDays - 1),
                    ),
                    Text('$_durationDays', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text)),
                    IconButton(
                      tooltip: l10n.redesignPlanMore5,
                      icon: Icon(Icons.add_circle_outline, color: p.link),
                      onPressed: () => _rdSetDays(_durationDays + 1),
                    ),
                  ],
                ),
              )
            else ...[
              RdListRow(
                title: l10n.typeSettingsStart,
                subtitle: l10n.redesignTypeTimeHint,
                value: start,
                onTap: () => _pickTime(isStart: true),
              ),
              RdListRow(title: l10n.typeSettingsEnd, value: end, onTap: () => _pickTime(isStart: false)),
            ],
          ],
        ),
        const SizedBox(height: 16),
        RdGroupLabel(l10n.redesignTypeInList),
        RdGroupedList(
          children: [
            toggle(l10n.typeSettingsActive, l10n.typeSettingsActiveHelper, _visible, (v) => _visible = v),
            toggle(l10n.typeSettingsHighlight, null, _highlight, (v) => _highlight = v),
            toggle(l10n.typeSettingsHideName, null, _hideName, (v) => _hideName = v),
            RdListRow(
              title: l10n.typeSettingsColor,
              onTap: _pickColor,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: ColorUtils.getColorForPicker(_color)),
                  Icon(Icons.chevron_right, color: p.text2),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        RdGroupLabel(l10n.redesignTypeFeatures),
        RdGroupedList(
          children: [
            if (!_isGeneral) toggle(l10n.typeSettingsManageSongs, null, _manageSongs, (v) => _manageSongs = v),
            toggle(l10n.redesignTypeLocation, null, _placeEnabled, (v) => _placeEnabled = v),
            feature(
              Icons.list,
              l10n.typeSettingsRunSheet,
              planCount == 0 ? l10n.redesignTypeOff : l10n.redesignPlanItemCount(planCount),
              () => _rdOpenSub(l10n.typeSettingsRunSheet, _buildPlanSection),
            ),
            feature(
              Icons.notifications_outlined,
              l10n.typeSettingsEventReminders,
              _notification ? l10n.redesignTypeRemindersActive(_reminders.length) : l10n.redesignTypeOff,
              () => _rdOpenSub(l10n.typeSettingsEventReminders, _rdRemindersBody),
            ),
            feature(
              Icons.checklist,
              l10n.typeSettingsChecklist,
              onOff(_checklistEnabled),
              () => _rdOpenSub(l10n.typeSettingsChecklist, _rdChecklistBody),
            ),
            feature(
              Icons.assignment_ind_outlined,
              l10n.typeSettingsDutyRoster,
              onOff(_dutyMode),
              () => _rdOpenSub(l10n.typeSettingsDutyRoster, _buildDutySection),
            ),
            feature(
              Icons.event_note_outlined,
              l10n.typeSettingsProtocolAgenda,
              onOff(_protocol.enableProtocol),
              () => _rdOpenSub(l10n.typeSettingsProtocolAgenda, _rdProtocolBody),
            ),
            feature(
              Icons.help_outline,
              l10n.typeSettingsSignupFields,
              '${_registrationFields.length}',
              () => _rdOpenSub(l10n.typeSettingsSignupFields, _rdSignupBody),
            ),
            feature(
              Icons.groups_outlined,
              l10n.redesignTypeWhoBelongs,
              groupCount == 0 ? l10n.redesignTypeAll : '$groupCount',
              () => _rdOpenSub(l10n.redesignTypeWhoBelongs, _buildFilterSection),
              subtitle: l10n.redesignTypeWhoBelongsHint,
            ),
          ],
        ),
        const SizedBox(height: 24),
        RdGroupedList(
          children: [
            RdListRow(
              leading: RdRowIcon(Icons.delete_outline, color: p.absent, background: p.absentSoft),
              title: l10n.redesignTypeDelete,
              titleColor: p.absent,
              showChevron: false,
              onTap: _deleteType,
            ),
          ],
        ),
      ],
    );
  }

  void _rdSet(VoidCallback fn) => _update(() {
    fn();
    _hasChanges = true;
  });

  /// Text fields of the classic sections change without setState.
  void _rdOnText() {
    if (mounted) _update(() {});
  }

  void _rdSetDays(int days) => _rdSet(() {
    _durationDays = days;
    _durationDaysController.text = '$days';
  });

  Future<void> _rdPickDefaultStatus(List<AttendanceStatus> statuses) async {
    final picked = await showRdPlanActionSheet<AttendanceStatus>(
      context,
      title: context.l10n.redesignTypeDefault,
      actions: [
        for (final s in statuses)
          PlanSheetAction(s, _getStatusName(s), icon: s == _defaultStatus ? Icons.check_circle : Icons.circle_outlined),
      ],
    );
    if (picked == null || !mounted) return;
    _rdSet(() => _defaultStatus = picked);
  }

  /// Saves shortly after the last change (typing in the name).
  void _rdScheduleSave() {
    _rdNotifier ??= ref.read(attendanceTypeNotifierProvider.notifier);
    _rdSaveTimer?.cancel();
    _rdSaveTimer = Timer(const Duration(milliseconds: 700), _rdSave);
  }

  Future<void> _rdSave() async {
    if (!mounted || !_hasChanges) return;
    if (_rdSaving) {
      _rdScheduleSave();
      return;
    }
    // Same rules as Speichern: a name and at least two statuses.
    final invalid = _nameController.text.trim().isEmpty || _availableStatuses.length < 2;
    if (invalid) {
      // No rebuild when it already shows (the build would schedule again).
      if (!_rdInvalid) _update(() => _rdInvalid = true);
      return;
    }
    final notifier = ref.read(attendanceTypeNotifierProvider.notifier);
    final data = _buildTypeData();
    final json = _rdJson();
    if (json == (_rdQueuedJson ?? _rdSavedJson)) {
      _hasChanges = false;
      return;
    }
    _update(() {
      _rdInvalid = false;
      _rdSaving = true;
      _hasChanges = false;
    });
    try {
      final id = widget.typeId!;
      final save = _rdChain.then((_) => notifier.updateType(id, data));
      _rdChain = save.then((_) {}, onError: (_) {});
      _rdQueuedJson = json;
      final AttendanceType? updated;
      try {
        updated = await save;
      } finally {
        if (_rdQueuedJson == json) _rdQueuedJson = null;
      }
      if (updated != null) _rdInvalidateCaches();
      if (!mounted) return;
      if (updated == null) {
        ToastHelper.showError(context, context.l10n.typeSettingsUpdateFailed);
        // Tried again with the next change, not in a loop.
        _update(() {
          _hasChanges = true;
          _rdFailedJson = json;
        });
        return;
      }
      _rdSavedJson = json;
      _rdFailedJson = null;
      _originalType = updated;
      await _offerDutyView();
    } on DemoModeException {
      // DEMO_GUARD: the demo warning toast was already shown; not again for
      // the same state.
      _rdFailedJson = json;
    } catch (_) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.typeSettingsUpdateFailed);
        _update(() {
          _hasChanges = true;
          _rdFailedJson = json;
        });
      }
    } finally {
      if (mounted) _update(() => _rdSaving = false);
    }
  }

  /// A small page per feature; it rebuilds with the type page.
  void _rdOpenSub(String title, Widget Function() body) {
    final l10n = context.l10n;
    final name = _nameController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (ctx) => ValueListenableBuilder<int>(
              valueListenable: _rdTick,
              builder: (ctx, _, _) {
                final p = ctx.rd;
                return RdPage(
                  children: [
                    RdBackLink(
                      label: name.isEmpty ? l10n.typeSettingsFlutterTypeTitle : name,
                      onTap: () => Navigator.of(ctx).maybePop(),
                    ),
                    const SizedBox(height: 4),
                    Semantics(header: true, child: Text(title, style: RdType.title(p))),
                    const SizedBox(height: 16),
                    RdCard(child: Material(type: MaterialType.transparency, child: body())),
                  ],
                );
              },
            ),
      ),
    );
  }

  Widget _rdRemindersBody() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.typeSettingsEventReminder),
          subtitle: Text(l10n.typeSettingsEventReminderHelper),
          value: _notification,
          onChanged: (v) => _rdSet(() => _notification = v),
        ),
        if (_notification)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.typeSettingsConfigureReminders),
            subtitle: Text(
              _reminders.isNotEmpty
                  ? l10n.typeSettingsRemindersActive(_reminders.length)
                  : l10n.typeSettingsNoReminders,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openReminders,
          ),
      ],
    );
  }

  Widget _rdChecklistBody() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.typeSettingsEnableChecklist),
          subtitle: Text(l10n.typeSettingsChecklistHelper),
          value: _checklistEnabled,
          onChanged:
              (v) => _rdSet(() {
                _checklistEnabled = v;
                _checklist = [];
              }),
        ),
        if (_checklistEnabled) _buildChecklistSection(),
      ],
    );
  }

  Widget _rdProtocolBody() => TypeProtocolSettingsTiles(
    settings: _protocol,
    showLearnMore: true,
    hasPlaceholder: hasAgendaPlaceholder(_planFields),
    onChanged: (v) => _rdSet(() => _protocol = v),
    onInsertPlaceholder:
        () => _rdSet(() {
          if (!hasAgendaPlaceholder(_planFields)) _planFields.add(_withRowUid(agendaPlaceholderField()));
        }),
  );

  Widget _rdSignupBody() => RegistrationFieldsEditor(
    fields: _registrationFields,
    onChanged: (fields) => _rdSet(() => _registrationFields = fields),
  );
}
