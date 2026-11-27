part of 'master_data_sheet.dart';

/// Form body, extra-field rows, and church picker helpers for [MasterDataSheet].
extension _MasterDataSheetForm on _MasterDataSheetState {
  /// "Meine Stammdaten" edit page – Passbild on top, fields in cards,
  /// saves on its own ("Gespeichert ✓"), "Fertig" closes.
  Widget _buildView(
    BuildContext context,
    AsyncValue<OwnProfile?> profileAsync,
    OwnProfile? profile,
    List<Church> churches,
  ) {
    final p = context.rd;
    final l10n = context.l10n;
    Widget text(
      String label,
      TextEditingController c, {
      TextInputType? keyboard,
      TextCapitalization caps = TextCapitalization.none,
      int lines = 1,
      String hint = '',
    }) => RdFieldRow(
      label: label,
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        textCapitalization: caps,
        minLines: 1,
        maxLines: lines,
        style: TextStyle(fontSize: 17, color: p.text),
        decoration: rdInputDecoration(p, hint),
        onChanged: (_) => _changed(),
      ),
    );
    final Widget body;
    if (!_initialized) {
      body = SizedBox(
        height: 200,
        child: Center(
          child:
              profileAsync.hasError
                  ? Text(l10n.signoutFlutterError(friendlyErrorMessage(profileAsync.error)), style: RdType.body(p))
                  : profileAsync.hasValue && profile == null
                  ? Text(l10n.settingsFlutterNoProfile, style: RdType.body(p))
                  : const AppSpinner(),
        ),
      );
    } else {
      body = RdFormBody(
        shrinkWrap: true,
        children: [
          const SizedBox(height: 8),
          // Name card like "Neue Person": Passbild (initials + camera
          // badge) beside Vorname/Nachname.
          RdCard(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: RdPersonAvatar(
                    name: '${_firstName.text} ${_lastName.text}',
                    imageUrl: hasCustomProfileImage(_img) ? _img : null,
                    onTap: _changeImg,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      text(l10n.peopleFirstName, _firstName, caps: TextCapitalization.words),
                      Divider(height: 1, thickness: 1, color: p.line),
                      text(l10n.peopleLastName, _lastName, caps: TextCapitalization.words),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          RdGroupLabel(l10n.redesignPersonFormContact),
          RdGroupedList(
            children: [
              text(l10n.settingsMobile, _phone, keyboard: TextInputType.phone, hint: '+49 123 456789'),
            ],
          ),
          const SizedBox(height: 20),
          RdGroupedList(
            children: [
              RdListRow(
                title: l10n.peopleBirthday,
                value: (_birthday ?? '').isEmpty ? l10n.orgChoose : formatIonDateButton(_birthday),
                onTap: _pickBirthday,
              ),
            ],
          ),
          if (_visibleFields.isNotEmpty) ...[
            const SizedBox(height: 20),
            RdGroupLabel(l10n.settingsExtraFields),
            RdGroupedList(
              children: [
                for (final field in _visibleFields) _buildExtraField(field, churches, text),
              ],
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(
              _saving
                  ? l10n.redesignMeSaving
                  : _dirty
                  ? ''
                  : _saved
                  ? l10n.redesignMeSaved
                  : l10n.redesignMeSavesItself,
              style: RdType.meta(p, size: 13),
            ),
          ),
        ],
      );
    }
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Padding(
        // Keep the lower fields above the keyboard.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RdFormTopBar(
              title: l10n.settingsMyData,
              cancel: '',
              submit: l10n.redesignCommonDone,
              saving: _closing,
              onCancel: null,
              onSubmit: _done,
            ),
            Flexible(child: IgnorePointer(ignoring: _closing, child: body)),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraField(
    ProfileExtraField field,
    List<Church> churches,
    Widget Function(
      String label,
      TextEditingController c, {
      TextInputType? keyboard,
      TextCapitalization caps,
      int lines,
      String hint,
    })
    text,
  ) {
    final p = context.rd;
    if (!field.editableByPlayers) {
      return RdListRow(
        title: field.name,
        subtitle: extraFieldDisplayValue(field, _additional, churches),
        showChevron: false,
      );
    }
    switch (field.type) {
      case 'boolean':
        return RdListRow(
          title: field.name,
          showChevron: false,
          trailing: IonSwitch(
            value: _additional[field.id] == true,
            activeTrackColor: p.primary,
            onChanged: (v) {
              _update(() => _additional[field.id] = v);
              _changed(now: true);
            },
          ),
        );
      case 'select':
        final current = _additional[field.id]?.toString();
        final valid = field.options.contains(current);
        return RdListRow(
          title: field.name,
          value: valid ? current! : context.l10n.settingsPleaseSelect,
          onTap: () async {
            final value = await showIonSelectOptions<String>(
              context,
              title: field.name,
              options: [for (final o in field.options) (o, o)],
              selected: valid ? current : null,
            );
            if (value != null && mounted) {
              _update(() => _additional[field.id] = value);
              _changed(now: true);
            }
          },
        );
      case 'bfecg_church':
        return RdListRow(
          title: field.name,
          value: _churchLabel(field, churches),
          onTap: () async {
            final before = _additional[field.id];
            await _selectChurch(field, churches);
            if (mounted && _additional[field.id] != before) _changed(now: true);
          },
        );
      default:
        return text(
          field.name,
          _controllerFor(field),
          keyboard: field.type == 'number' ? TextInputType.number : TextInputType.text,
          caps: TextCapitalization.sentences,
          lines: field.type == 'textarea' ? 4 : 1,
        );
    }
  }

  String _churchLabel(ProfileExtraField field, List<Church> churches) {
    final value = _additional[field.id];
    if (value == null) return context.l10n.settingsPleaseSelect;
    if (value == '') return context.l10n.settingsNotListed;
    return churches.where((c) => c.id == value).firstOrNull?.name ?? context.l10n.settingsPleaseSelect;
  }

  Future<void> _selectChurch(ProfileExtraField field, List<Church> churches) async {
    final selected = await showChurchPicker(
      context,
      title: field.name,
      churches: churches,
      selectedId: _additional[field.id]?.toString(),
      searchHint: context.l10n.settingsSearchChurch,
      notListedLabel: context.l10n.settingsNotListed,
      noChurchLabel: context.l10n.settingsNoChurch,
    );
    if (selected != null && mounted) {
      _update(() => _additional[field.id] = selected);
    }
  }
}
