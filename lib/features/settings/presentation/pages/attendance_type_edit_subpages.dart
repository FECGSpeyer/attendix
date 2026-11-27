part of 'attendance_type_edit_page.dart';

/// Feature subpages opened from [AttendanceTypeEditPage].
extension _AttendanceTypeSubpages on _AttendanceTypeEditPageState {
  /// Opens a dedicated subpage for a feature; rebuilds with the type page.
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
    final current = _statusOrder.where(_availableStatuses.contains).toList();
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
