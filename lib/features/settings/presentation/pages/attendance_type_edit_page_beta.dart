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
    final groupCount = _relevantGroups.length;
    final features = _rdFeatures(l10n);
    final active = features.where((f) => f.on).toList();
    final name = _nameController.text.trim();

    Widget toggle(String title, String? subtitle, bool value, void Function(bool) set, {Key? key}) => RdListRow(
      key: key,
      title: title,
      subtitle: subtitle,
      showChevron: false,
      onTap: () => _rdSet(() => set(!value)),
      trailing: Switch.adaptive(value: value, onChanged: (v) => _rdSet(() => set(v))),
    );

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
          child: Text(name.isEmpty ? l10n.typeSettingsFlutterTypeTitle : name, style: RdType.title(p)),
        ),
        if (_usageCount > 0) ...[
          const SizedBox(height: 4),
          Text(l10n.rdTypeUsage(_usageCount), style: RdType.meta(p, size: 13)),
        ],
        if (_rdDeletedButUsed) ...[
          const SizedBox(height: 12),
          RdInfoCard(icon: Icons.visibility_off_outlined, text: l10n.rdTypeDeleted),
        ],
        if (_rdInvalid) ...[
          const SizedBox(height: 12),
          RdInfoCard(icon: Icons.error_outline, text: l10n.redesignTypeInvalid),
        ],
        const SizedBox(height: 16),
        RdGroupedList(
          children: [
            RdPlanTextRow(label: l10n.planningName, controller: _nameController, onChanged: (_) => _rdSet(() {})),
            RdListRow(
              key: const Key('rd-type-look'),
              title: l10n.rdTypeLook,
              subtitle: l10n.rdTypeLookHint,
              onTap: () => _rdOpenSub(l10n.rdTypeLook, _rdLookBody),
              trailing: _rdTypePill(name.isEmpty ? l10n.typeSettingsFlutterTypeTitle : name),
            ),
          ],
        ),
        const SizedBox(height: 16),
        RdGroupLabel(l10n.rdTypeEveryEvent),
        RdGroupedList(
          children: [
            toggle(l10n.rdTypeAllDay, null, _allDay, (v) => _allDay = v),
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
            else
              RdListRow(
                title: l10n.rdTypeTime,
                subtitle: l10n.rdTypeTimeHint,
                showChevron: false,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RdValueBox(start, semantics: l10n.typeSettingsStart, onTap: () => _pickTime(isStart: true)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('–', style: TextStyle(color: p.text2)),
                    ),
                    RdValueBox(end, semantics: l10n.typeSettingsEnd, onTap: () => _pickTime(isStart: false)),
                  ],
                ),
              ),
            RdListRow(
              key: const Key('rd-type-attendance'),
              title: l10n.rdTypeAttendance,
              subtitle: l10n.rdTypeAttendanceValue(_getStatusName(defaultStatus), statuses.length),
              onTap: () => _rdOpenSub(l10n.rdTypeAttendance, _rdAttendanceBody),
            ),
            toggle(
              l10n.rdTypeCountsForQuota,
              l10n.rdTypeCountsForQuotaHint,
              _includeInAverage,
              (v) => _includeInAverage = v,
              key: const Key('rd-type-quota'),
            ),
            RdListRow(
              title: l10n.rdTypeInvited,
              subtitle: l10n.rdTypeInvitedHint,
              value: groupCount == 0 ? l10n.rdTypeInvitedAll : l10n.rdTypeInvitedSome(groupCount),
              onTap: () => _rdOpenSub(l10n.rdTypeInvited, _buildFilterSection),
            ),
          ],
        ),
        const SizedBox(height: 16),
        RdGroupLabel(l10n.rdTypeAutomatic),
        RdGroupedList(
          children: [
            for (final f in active)
              RdListRow(
                key: Key('rd-type-feature-${f.id}'),
                leading: RdRowIcon(f.icon),
                title: f.title,
                value: f.value,
                onTap: f.open,
              ),
            if (active.length < features.length)
              RdListRow(
                key: const Key('rd-type-add'),
                leading: RdRowIcon(Icons.add),
                title: l10n.rdTypeAdd,
                titleColor: p.link,
                showChevron: false,
                onTap: () => _rdAddFeature(features.where((f) => !f.on).toList()),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(l10n.rdTypeAutomaticHint, style: RdType.meta(p, size: 13)),
        ),
        const SizedBox(height: 24),
        RdGroupedList(
          children: [
            // No "Für neue Termine anbieten" switch: deleting a type that
            // existing Termine use hides it instead (they keep it).
            if (_rdDeletedButUsed)
              RdListRow(
                key: const Key('rd-type-restore'),
                leading: const RdRowIcon(Icons.restore),
                title: l10n.rdTypeRestore,
                subtitle: l10n.rdTypeRestoreHint,
                showChevron: false,
                onTap: _rdRestoreType,
              )
            else
              RdListRow(
                key: const Key('rd-type-delete'),
                leading: RdRowIcon(Icons.delete_outline, color: p.absent, background: p.absentSoft),
                title: l10n.redesignTypeDelete,
                titleColor: p.absent,
                showChevron: false,
                onTap: _rdDeleteType,
              ),
          ],
        ),
      ],
    );
  }

  /// The pill the type shows in the Termin list (Hervorheben = orange).
  Widget _rdTypePill(String label) {
    final color = ColorUtils.getColorForPicker(_color);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 14, color: color),
          const SizedBox(width: 6),
          RdPill(label, tone: _highlight ? RdTone.excused : RdTone.primary),
        ],
      ),
    );
  }

  /// Everything new Termine of the type can get: shown on the page when on,
  /// else offered under "Hinzufügen".
  List<_RdTypeFeature> _rdFeatures(AppLocalizations l10n) {
    final planCount = _planFields.length;
    return [
      _RdTypeFeature(
        id: 'plan',
        icon: Icons.list,
        title: l10n.rdTypePlan,
        hint: l10n.rdTypePlanHint,
        on: planCount > 0,
        value: l10n.rdTypePlanValue(planCount),
        open: () => _rdOpenSub(l10n.rdTypePlan, _buildPlanSection),
      ),
      _RdTypeFeature(
        id: 'reminders',
        icon: Icons.notifications_outlined,
        title: l10n.rdTypeReminders,
        hint: l10n.rdTypeRemindersHint,
        on: _notification,
        value: l10n.rdTypeRemindersValue(_reminders.length),
        open: () => _rdOpenSub(l10n.rdTypeReminders, _rdRemindersBody),
        enable: () => _notification = true,
      ),
      _RdTypeFeature(
        id: 'checklist',
        icon: Icons.checklist,
        title: l10n.rdTypeChecklist,
        hint: l10n.rdTypeChecklistHint,
        on: _checklistEnabled,
        value: l10n.rdTypeChecklistValue(_checklist.length),
        open: () => _rdOpenSub(l10n.rdTypeChecklist, _rdChecklistBody),
        enable: () {
          _checklistEnabled = true;
          _checklist = [];
        },
      ),
      _RdTypeFeature(
        id: 'duty',
        icon: Icons.assignment_ind_outlined,
        title: l10n.rdTypeDuty,
        hint: l10n.rdTypeDutyHint,
        on: _dutyMode,
        value: l10n.rdTypeOn,
        open: () => _rdOpenSub(l10n.rdTypeDuty, _buildDutySection),
      ),
      _RdTypeFeature(
        id: 'protocol',
        icon: Icons.event_note_outlined,
        title: l10n.rdTypeProtocol,
        hint: l10n.rdTypeProtocolHint,
        on: _protocol.enableProtocol,
        value: l10n.rdTypeOn,
        open: () => _rdOpenSub(l10n.rdTypeProtocol, _rdProtocolBody),
      ),
      _RdTypeFeature(
        id: 'signup',
        icon: Icons.help_outline,
        title: l10n.rdTypeSignup,
        hint: l10n.rdTypeSignupHint,
        on: _registrationFields.isNotEmpty,
        value: l10n.rdTypeSignupValue(_registrationFields.length),
        open: () => _rdOpenSub(l10n.rdTypeSignup, _rdSignupBody),
      ),
    ];
  }

  /// "Hinzufügen": the features that are off, each with one sentence. The
  /// picked one is switched on where that is a plain switch and opens.
  Future<void> _rdAddFeature(List<_RdTypeFeature> off) async {
    final l10n = context.l10n;
    final picked = await showRdPlanSheet<_RdTypeFeature>(
      context,
      title: l10n.rdTypeAdd,
      subtitle: l10n.rdTypeAddHint,
      builder:
          (ctx, pop) => [
            RdGroupedList(
              children: [
                for (final f in off)
                  RdListRow(
                    key: Key('rd-type-add-${f.id}'),
                    leading: RdRowIcon(f.icon),
                    title: f.title,
                    subtitle: f.hint,
                    showChevron: false,
                    onTap: () => pop(f),
                  ),
              ],
            ),
          ],
    );
    if (picked == null || !mounted) return;
    final enable = picked.enable;
    if (enable != null) _rdSet(enable);
    picked.open();
  }

  Widget _rdLookBody() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdListRow(
          title: l10n.typeSettingsColor,
          onTap: _pickColor,
          trailing: Icon(Icons.circle, color: ColorUtils.getColorForPicker(_color)),
        ),
        RdListRow(
          title: l10n.typeSettingsHighlight,
          subtitle: l10n.rdTypeLookHighlightHint,
          showChevron: false,
          onTap: () => _rdSet(() => _highlight = !_highlight),
          trailing: Switch.adaptive(value: _highlight, onChanged: (v) => _rdSet(() => _highlight = v)),
        ),
        RdListRow(
          title: l10n.rdTypeLookHideName,
          subtitle: l10n.rdTypeLookHideNameHint,
          showChevron: false,
          onTap: () => _rdSet(() => _hideName = !_hideName),
          trailing: Switch.adaptive(value: _hideName, onChanged: (v) => _rdSet(() => _hideName = v)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _rdTypePill(_nameController.text.trim()),
          ),
        ),
      ],
    );
  }

  Widget _rdAttendanceBody() {
    final l10n = context.l10n;
    final current = _AttendanceTypeEditPageState._statusOrder.where(_availableStatuses.contains).toList();
    final defaultStatus =
        _availableStatuses.contains(_defaultStatus) ? _defaultStatus : (current.firstOrNull ?? _defaultStatus);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdListRow(
          title: l10n.rdTypeStatuses,
          subtitle: current.map(_getStatusName).join(', '),
          onTap: _pickAvailableStatuses,
        ),
        RdListRow(
          title: l10n.rdTypeDefaultStatus,
          value: _getStatusName(defaultStatus),
          onTap: () => _rdPickDefaultStatus(current),
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

  /// Deleted while existing Termine still use it: only those keep it.
  bool get _rdDeletedButUsed => !_visible && _usageCount != 0; // -1 = count unknown

  /// "Terminart löschen": unused → really deleted; used by existing
  /// Termine (or count unknown, -1) → hidden for new ones (the classic delete would remove those
  /// Termine with it).
  Future<void> _rdDeleteType() async {
    if (_usageCount == 0) return _deleteType();
    final l10n = context.l10n;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: l10n.rdTextTypeDeleteTitle,
      message: _usageCount > 0 ? l10n.rdTypeDeleteUsedMessage(_nameController.text.trim(), _usageCount) : l10n.rdTypeDeleted,
      confirmText: l10n.commonDelete,
      cancelText: l10n.commonCancel,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await _rdSetVisible(false);
    if (!mounted || !ok) return;
    ToastHelper.showSuccess(context, l10n.typeSettingsDeleted);
    context.pop();
  }

  Future<void> _rdRestoreType() async {
    final ok = await _rdSetVisible(true);
    if (ok && mounted) ToastHelper.showSuccess(context, context.l10n.rdTypeRestored);
  }

  /// Stores `visible` right away (after any queued save).
  Future<bool> _rdSetVisible(bool visible) async {
    final notifier = ref.read(attendanceTypeNotifierProvider.notifier);
    final id = widget.typeId!;
    final previous = _visible;
    _update(() => _visible = visible);
    try {
      final save = _rdChain.then((_) => notifier.updateType(id, {'visible': visible}));
      _rdChain = save.then((_) {}, onError: (_) {});
      final updated = await save;
      if (updated == null) throw StateError('update failed');
      _rdInvalidateCaches();
      return true;
    } on DemoModeException {
      if (mounted) _update(() => _visible = previous);
      return false;
    } catch (_) {
      if (mounted) {
        _update(() => _visible = previous);
        ToastHelper.showError(context, context.l10n.typeSettingsUpdateFailed);
      }
      return false;
    }
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

/// One feature of the type on the Beta page ("Neue Termine dieser Art
/// bekommen automatisch" / "Hinzufügen").
class _RdTypeFeature {
  const _RdTypeFeature({
    required this.id,
    required this.icon,
    required this.title,
    required this.hint,
    required this.on,
    required this.value,
    required this.open,
    this.enable,
  });

  final String id;
  final IconData icon;
  final String title;
  final String hint;
  final bool on;
  final String value;
  final VoidCallback open;

  /// Switches it on before [open] (features with a plain on switch).
  final VoidCallback? enable;
}
