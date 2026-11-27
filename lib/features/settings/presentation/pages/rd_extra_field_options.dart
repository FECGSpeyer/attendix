part of 'rd_extra_field_edit_page.dart';

class _Option {
  _Option(String text) : controller = TextEditingController(text: text);

  final TextEditingController controller;
  final FocusNode focus = FocusNode();

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

/// Option list editing, persistence, and value reset helpers for
/// [RdExtraFieldEditPage].
extension _RdExtraFieldOptions on _RdExtraFieldEditPageState {
  _Option _addOptionRow(String text) {
    final option = _Option(text);
    option.focus.addListener(() {
      if (!option.focus.hasFocus) _saveOptions();
    });
    _options.add(option);
    return option;
  }

  /// The options as shown without empty ones; null when a selection would be
  /// left without any option (then nothing is written).
  List<String>? get _optionValues {
    final values = [
      for (final o in _options)
        if (o.controller.text.trim().isNotEmpty) o.controller.text,
    ];
    return values.isEmpty ? null : values;
  }

  /// Saves the selection options; the first option becomes the default.
  /// A failed save restores the previously stored options unless edited since.
  void _saveOptions() {
    if (_type != 'select') return;
    final values = _optionValues;
    if (values == null) return;
    _write(
      (f) => f.copyWith(options: values, defaultValue: values.first),
      onStored: () => _storedOptions = values,
      revert: () {
        if (!listEquals(_optionValues, values)) return;
        final old = [..._options];
        _options.clear();
        for (final o in _storedOptions) {
          _addOptionRow(o);
        }
        // Disposed after the frame: a removed row may still hold its focus.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final o in old) {
            o.dispose();
          }
        });
      },
    );
  }

  void _addOption() {
    late _Option option;
    _update(() => option = _addOptionRow(''));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _options.contains(option)) option.focus.requestFocus();
    });
  }

  /// Removes an option; saved options prompt for confirmation and migrate
  /// existing person values to the new default first.
  Future<void> _removeOption(_Option option) async {
    final l10n = context.l10n;
    final repo = _repo;
    final value = option.controller.text;
    // A selection keeps one option: removing the last one would move every
    // person to an empty value while the stored field keeps the option.
    if (value.trim().isNotEmpty &&
        !_options.any((o) => !identical(o, option) && o.controller.text.trim().isNotEmpty)) {
      ToastHelper.showError(context, l10n.redesignExtraFieldEditOptionsNeeded);
      return;
    }
    final stored =
        _RdExtraFieldEditPageState._listOf(ref.read(currentTenantProvider), _song)
            .where((f) => f.id == _fieldId)
            .firstOrNull;
    if (repo != null && value.isNotEmpty && (stored?.options ?? const []).contains(value)) {
      final ok = await DialogHelper.showConfirmation(
        context,
        title: l10n.extraFieldsDeleteOption,
        message: l10n.extraFieldsDeleteOptionMessage(value),
        confirmText: l10n.commonDelete,
        isDestructive: true,
      );
      if (!ok || !mounted) return;
      if (_person) {
        final current = [for (final o in _options) o.controller.text];
        final newDefault = current.first == value ? (current.length > 1 ? current[1] : '') : current.first;
        _update(() => _busy = true);
        final rootNav = Navigator.of(context, rootNavigator: true);
        unawaited(
          showDialog<void>(
            context: context,
            useRootNavigator: true,
            barrierDismissible: false,
            builder: (_) => PopScope(
              canPop: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: RdInfoCard(text: l10n.extraFieldsFlutterUpdatingPersons, loading: true),
                ),
              ),
            ),
          ),
        );
        try {
          final count = await repo.updateFieldValue(_fieldId, value, newDefault);
          if (count > 0 && mounted) ToastHelper.showSuccess(context, l10n.extraFieldsPersonsUpdated(count));
        } catch (_) {
          if (mounted) ToastHelper.showError(context, l10n.dbLoadPeopleFailed);
          return;
        } finally {
          rootNav.pop();
          if (mounted) _update(() => _busy = false);
        }
      }
    }
    if (!mounted || !_options.contains(option)) return;
    _update(() => _options.remove(option));
    // Disposed after the frame: the removed row may still hold its focus.
    WidgetsBinding.instance.addPostFrameCallback((_) => option.dispose());
    _saveOptions();
  }

  /// Resets every person's stored value for this field back to the default.
  Future<void> _resetValues() async {
    final l10n = context.l10n;
    final repo = _repo;
    if (repo == null) return;
    final ok = await DialogHelper.showConfirmation(
      context,
      title: l10n.extraFieldsResetValues,
      message: l10n.extraFieldsResetValuesMessage(_name.text),
      confirmText: l10n.dashSettingsReset,
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    _update(() => _busy = true);
    try {
      // The default as edited: pending text and options are saved first.
      _saveDefaultText();
      _saveOptions();
      await _queue;
      if (!mounted) return;
      final field =
          _RdExtraFieldEditPageState._listOf(ref.read(currentTenantProvider), _song)
              .where((f) => f.id == _fieldId)
              .firstOrNull;
      if (field == null) return;
      final resolved = extraFieldDefaultValue(
        field.type,
        defaultValue: field.type == 'select' ? null : field.defaultValue,
        options: field.options,
        churchIds: extraFieldChurchIds(ref.read),
      );
      try {
        final count = await repo.resetFieldValues(_fieldId, resolved);
        if (mounted) ToastHelper.showSuccess(context, l10n.extraFieldsPersonsUpdated(count));
      } catch (_) {
        if (mounted) ToastHelper.showError(context, l10n.dbLoadPeopleFailed);
      }
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }
}
