import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/files_providers.dart' show extraFieldsRepositoryWithTenantProvider;
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/extra_fields_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/pages/extra_fields_page.dart' show extraFieldChurchIds, extraFieldTypeName;
import '../widgets/event/rd_form_widgets.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import 'rd_extra_fields_page.dart' show rdSaveExtraFields;

/// The text the old page shows in the default field: a boolean has none, a
/// legacy default `false` (Ionic emptyField) shows as empty.
String _defaultText(ExtraField f) =>
    f.type != 'boolean' && f.defaultValue != null && f.defaultValue != false ? '${f.defaultValue}' : '';

/// Same field in its stored JSON form (old page `_sameField`).
bool _sameField(ExtraField a, ExtraField b) {
  final ja = extraFieldToJson(a);
  final jb = extraFieldToJson(b);
  return ja.keys.every((k) => k == 'options' ? listEquals(ja[k] as List, jb[k] as List) : ja[k] == jb[k]);
}

/// REDESIGN: "Zusatzfeld bearbeiten" (template of "Gruppe bearbeiten"):
/// everything the old edit sheet offers (Name, Typ, Darstellung, sichtbar /
/// bearbeitbar for persons, Optionen, Standardwert, "Alle Werte auf Standard
/// zurücksetzen"), saved right away like "Speichern" of the old page (text
/// fields when they lose focus or the page closes). "Zusatzfeld löschen" sits
/// at the bottom with the old question. The field is addressed by its list
/// ([song]) and id; the id stays when the name changes (old page).
class RdExtraFieldEditPage extends ConsumerStatefulWidget {
  const RdExtraFieldEditPage({super.key, required this.song, required this.fieldId});

  final bool song;
  final String fieldId;

  @override
  ConsumerState<RdExtraFieldEditPage> createState() => _RdExtraFieldEditPageState();
}

class _Option {
  _Option(String text) : controller = TextEditingController(text: text);

  final TextEditingController controller;
  final FocusNode focus = FocusNode();

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class _RdExtraFieldEditPageState extends ConsumerState<RdExtraFieldEditPage> {
  final _name = TextEditingController();
  final _default = TextEditingController();
  final _nameFocus = FocusNode();
  final _defaultFocus = FocusNode();
  final List<_Option> _options = [];

  late final bool _song = widget.song;
  late final String _fieldId = widget.fieldId;
  bool get _person => !_song;

  /// Shown values (null until the field is loaded).
  String? _type;
  String _displayMode = 'chip';
  bool _visible = false;
  bool _editable = false;
  bool _boolDefault = false;

  /// The default text as last written: an untouched field keeps the stored
  /// value (e.g. a legacy `false`), like the old page.
  String _storedDefaultText = '';

  bool _deleted = false;
  bool _busy = false;

  /// Writes run one after another, so the last change always wins.
  Future<void> _queue = Future.value();

  /// Bound once the field is loaded, so text saved when the page closes
  /// still goes to the field's tenant.
  ExtraFieldsRepository? _repo;
  late final ProviderContainer _container;
  late final OfflineWriteSession _session;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _session = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _saveName();
    });
    _defaultFocus.addListener(() {
      if (!_defaultFocus.hasFocus) _saveDefaultText();
    });
  }

  @override
  void dispose() {
    // Text typed last is saved when the page closes (no focus change).
    _saveName();
    _saveDefaultText();
    _saveOptions();
    _name.dispose();
    _default.dispose();
    _nameFocus.dispose();
    _defaultFocus.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  static List<ExtraField> _listOf(Tenant? t, bool song) =>
      (song ? t?.songAdditionalFields : t?.additionalFields) ?? const <ExtraField>[];

  void _fill(ExtraField f) {
    if (_repo != null) return;
    _repo = ref.read(extraFieldsRepositoryWithTenantProvider);
    _type = f.type;
    _name.text = f.name;
    _storedDefaultText = _defaultText(f);
    _default.text = _storedDefaultText;
    _displayMode = f.displayMode ?? 'chip';
    _visible = f.visibleToPlayers ?? false;
    _editable = f.editableByPlayers ?? false;
    // A boolean field without default is effectively `true` (old page).
    _boolDefault = f.type == 'boolean' && (f.defaultValue == null || f.defaultValue == true);
    for (final o in f.options ?? const <String>[]) {
      _addOptionRow(o);
    }
  }

  _Option _addOptionRow(String text) {
    final option = _Option(text);
    option.focus.addListener(() {
      if (!option.focus.hasFocus) _saveOptions();
    });
    _options.add(option);
    return option;
  }

  void _enqueue(Future<void> Function() task) {
    _queue = _queue.then((_) => task());
  }

  /// Applies [change] to the field as stored now and saves both lists (like
  /// "Speichern" of the old page). Nothing is written when the field did not
  /// change; reports a failure while the page is open.
  Future<bool> _store(ExtraField Function(ExtraField stored) change) async {
    final repo = _repo;
    if (_deleted || repo == null || !repo.hasTenantId || !_session.isCurrent()) return false;
    final read = _container.read;
    final tenant = read(currentTenantProvider);
    if (tenant?.id != repo.currentTenantId) return false;
    final list = _listOf(tenant, _song);
    final index = list.indexWhere((f) => f.id == _fieldId);
    if (index < 0) return false;
    final next = change(list[index]);
    if (_sameField(next, list[index])) return true;
    final updated = [...list]..[index] = next;
    try {
      final ok = await rdSaveExtraFields(
        read,
        repo,
        persons: _song ? _listOf(tenant, false) : updated,
        songs: _song ? updated : _listOf(tenant, true),
      );
      if (!ok) throw StateError('tenant changed');
      return true;
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.extraFieldsSaveFailed);
      return false;
    }
  }

  /// Saves [change]; on failure [revert] puts the shown value back.
  void _write(ExtraField Function(ExtraField stored) change, {VoidCallback? revert}) => _enqueue(() async {
    if (!await _store(change) && revert != null && mounted && !_deleted) setState(revert);
  });

  /// Like the old page: trimmed; an empty name is not saved.
  void _saveName() {
    final value = _name.text.trim();
    if (_type == null || value.isEmpty) return;
    _write((f) => f.copyWith(name: value));
  }

  void _saveDefaultText() {
    final type = _type;
    if (type == null || type == 'boolean' || type == 'select' || type == 'bfecg_church') return;
    final text = _default.text;
    if (text == _storedDefaultText) return;
    _enqueue(() async {
      // Old page `_parseDefault`: a number field stores a number.
      final value = type == 'number' ? (num.tryParse(text.trim()) ?? 0) : text;
      if (await _store((f) => f.copyWith(defaultValue: value))) _storedDefaultText = text;
    });
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

  /// Like the old page: the options of a selection, the first one is its
  /// default.
  void _saveOptions() {
    if (_type != 'select') return;
    final values = _optionValues;
    if (values == null) return;
    _write((f) => f.copyWith(options: values, defaultValue: values.first));
  }

  void _done() {
    FocusScope.of(context).unfocus();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.extraFields);
    }
  }

  void _setDisplay(String mode) {
    if (mode == _displayMode) return;
    final before = _displayMode;
    setState(() => _displayMode = mode);
    _write((f) => f.copyWith(displayMode: mode), revert: () {
      if (_displayMode == mode) _displayMode = before;
    });
  }

  /// Old page: only a visible field can be editable by players.
  void _setVisible(bool value) {
    final before = _visible;
    final editable = _editable;
    setState(() => _visible = value);
    _write((f) => f.copyWith(visibleToPlayers: value, editableByPlayers: value && editable), revert: () {
      if (_visible == value) _visible = before;
    });
  }

  void _setEditable(bool value) {
    final before = _editable;
    setState(() => _editable = value);
    _write((f) => f.copyWith(editableByPlayers: _visible && value), revert: () {
      if (_editable == value) _editable = before;
    });
  }

  void _setBoolDefault(bool value) {
    final before = _boolDefault;
    setState(() => _boolDefault = value);
    _write((f) => f.copyWith(defaultValue: value), revert: () {
      if (_boolDefault == value) _boolDefault = before;
    });
  }

  void _addOption() {
    late _Option option;
    setState(() => option = _addOptionRow(''));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _options.contains(option)) option.focus.requestFocus();
    });
  }

  /// Old page (removeEditExtraOption): a saved option asks first; for
  /// persons the values are moved to the new default before it goes.
  Future<void> _removeOption(_Option option) async {
    final l10n = context.l10n;
    final repo = _repo;
    final value = option.controller.text;
    final stored = _listOf(ref.read(currentTenantProvider), _song).where((f) => f.id == _fieldId).firstOrNull;
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
        setState(() => _busy = true);
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
          if (mounted) setState(() => _busy = false);
        }
      }
    }
    if (!mounted || !_options.contains(option)) return;
    setState(() => _options.remove(option));
    // Disposed after the frame: the removed row may still hold its focus.
    WidgetsBinding.instance.addPostFrameCallback((_) => option.dispose());
    _saveOptions();
  }

  /// Old page (resetExtraFieldValues): every person gets the default.
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
    setState(() => _busy = true);
    try {
      // The default as edited: pending text and options are saved first.
      _saveDefaultText();
      _saveOptions();
      await _queue;
      if (!mounted) return;
      final field = _listOf(ref.read(currentTenantProvider), _song).where((f) => f.id == _fieldId).firstOrNull;
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
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Old page: asks, then the field goes from its list and its values are
  /// cleaned (like "Speichern").
  Future<void> _delete(ExtraField field) async {
    if (_busy) return;
    final l10n = context.l10n;
    final repo = _repo;
    if (repo == null) return;
    final name = _name.text.trim().isEmpty ? field.name : _name.text.trim();
    setState(() => _busy = true);
    try {
      final confirmed = await DialogHelper.showConfirmation(
        context,
        title: l10n.extraFieldsDeleteField,
        message: l10n.extraFieldsDeleteFieldMessage(name),
        confirmText: l10n.commonDelete,
        isDestructive: true,
      );
      if (!confirmed || !mounted) return;
      // Saves still running finish first; nothing is written to the field
      // while it is deleted (the form is locked); a failed delete writes again.
      await _queue;
      if (!mounted) return;
      _deleted = true;
      var ok = false;
      try {
        final tenant = ref.read(currentTenantProvider);
        List<ExtraField> without(bool song) => [..._listOf(tenant, song).where((f) => song != _song || f.id != _fieldId)];
        ok = await rdSaveExtraFields(ref.read, repo, persons: without(false), songs: without(true));
      } catch (_) {
        ok = false;
      }
      if (!mounted) return;
      if (!ok) {
        _deleted = false;
        ToastHelper.showError(context, l10n.redesignExtraFieldEditDeleteFailed);
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(RedesignRoutes.extraFields);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    // Churches preloaded (default of the BFECG church field), like the old page.
    ref.watch(churchesProvider);
    final tenant = ref.watch(currentTenantProvider);
    final field = _listOf(tenant, _song).where((f) => f.id == _fieldId).firstOrNull;

    final Widget body;
    if (field == null) {
      body = RdFormBody(
        children: [
          tenant == null || _deleted
              ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
              : RdInfoCard(text: l10n.redesignExtraFieldEditNotFound, icon: Icons.error_outline),
        ],
      );
    } else {
      _fill(field);
      // Locked while deleting or moving values: no change can get lost.
      body = IgnorePointer(ignoring: _busy, child: _form(context, field));
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Row(
                children: [
                  const SizedBox(width: 88),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.redesignExtraFieldEditTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: RdTextLink(
                        key: const Key('rd-extra-field-edit-done'),
                        label: l10n.redesignCommonDone,
                        onTap: _done,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context, ExtraField field) {
    final p = context.rd;
    final l10n = context.l10n;
    final type = _type ?? field.type;
    final textStyle = TextStyle(fontSize: 17, color: p.text);

    Widget hint(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(text, style: RdType.meta(p, size: 13).copyWith(color: color)),
    );

    Widget switchRow(String key, String title, String? subtitle, bool value, ValueChanged<bool> onChanged) => RdListRow(
      key: Key('rd-extra-field-edit-$key'),
      title: title,
      subtitle: subtitle,
      showChevron: false,
      onTap: () => onChanged(!value),
      trailing: Switch.adaptive(value: value, activeTrackColor: p.primary, onChanged: onChanged),
    );

    return RdFormBody(
      children: [
        RdGroupedList(
          children: [
            RdFieldRow(
              label: l10n.redesignExtraFieldEditName,
              child: TextField(
                key: const Key('rd-extra-field-edit-name'),
                controller: _name,
                focusNode: _nameFocus,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                style: textStyle,
                decoration: rdInputDecoration(p, ''),
                onChanged: (_) => setState(() {}),
              ),
            ),
            RdListRow(title: l10n.typeSettingsType, value: extraFieldTypeName(type), showChevron: false),
            RdListRow(
              title: l10n.redesignExtraFieldEditTarget,
              value: _song ? l10n.redesignExtraFieldEditTargetSongs : l10n.redesignExtraFieldEditTargetPersons,
              showChevron: false,
            ),
          ],
        ),
        if (_name.text.trim().isEmpty) hint(l10n.redesignExtraFieldEditNameEmpty, color: p.absent),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.extraFieldsDisplay),
        RdSegmented<String>(
          values: const ['chip', 'underneath'],
          selected: _displayMode,
          semanticLabel: l10n.extraFieldsDisplay,
          labelOf: (v) => v == 'underneath' ? l10n.extraFieldsUnderName : l10n.extraFieldsAsChip,
          onChanged: _setDisplay,
        ),
        if (_person) ...[
          const SizedBox(height: 20),
          RdGroupedList(
            children: [
              switchRow('visible', l10n.extraFieldsVisible, l10n.extraFieldsVisibleHelper, _visible, _setVisible),
              if (_visible)
                switchRow('editable', l10n.extraFieldsEditable, l10n.extraFieldsEditableHelper, _editable, _setEditable),
            ],
          ),
        ],
        if (type == 'select') ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: RdGroupLabel(l10n.redesignExtraFieldEditOptions)),
              RdTextLink(
                key: const Key('rd-extra-field-edit-option-add'),
                label: l10n.redesignExtraFieldEditOptionAdd,
                onTap: _addOption,
              ),
            ],
          ),
          if (_options.isNotEmpty)
            RdGroupedList(
              children: [
                for (var i = 0; i < _options.length; i++)
                  Padding(
                    key: ObjectKey(_options[i]),
                    padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: Key('rd-extra-field-edit-option-$i'),
                            controller: _options[i].controller,
                            focusNode: _options[i].focus,
                            textCapitalization: TextCapitalization.sentences,
                            style: textStyle,
                            decoration: rdInputDecoration(p, l10n.extraFieldsValuePh),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: p.absent, semanticLabel: l10n.commonDelete),
                          onPressed: () => _removeOption(_options[i]),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          if (_optionValues == null)
            hint(l10n.redesignExtraFieldEditOptionsNeeded, color: p.absent)
          else
            hint(l10n.redesignExtraFieldEditOptionHint),
        ],
        if (type != 'select' && type != 'bfecg_church') ...[
          const SizedBox(height: 20),
          RdGroupedList(
            children: [
              if (type == 'boolean')
                switchRow('default', l10n.extraFieldsDefaultValue, null, _boolDefault, _setBoolDefault)
              else
                RdFieldRow(
                  label: l10n.extraFieldsDefaultValue,
                  child: TextField(
                    key: const Key('rd-extra-field-edit-default'),
                    controller: _default,
                    focusNode: _defaultFocus,
                    keyboardType: type == 'number' ? TextInputType.number : TextInputType.text,
                    textInputAction: TextInputAction.done,
                    style: textStyle,
                    decoration: rdInputDecoration(p, ''),
                  ),
                ),
            ],
          ),
          hint(l10n.redesignExtraFieldEditDefaultHint),
        ],
        if (_person) ...[
          const SizedBox(height: 20),
          RdGroupedList(
            children: [
              RdListRow(
                key: const Key('rd-extra-field-edit-reset'),
                title: l10n.extraFieldsResetAll,
                titleColor: p.late,
                leading: Icon(Icons.restart_alt, color: p.late),
                showChevron: false,
                onTap: _resetValues,
              ),
            ],
          ),
          hint(l10n.redesignExtraFieldEditResetHint),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 20),
          child: Text(l10n.redesignGroupEditHint, style: RdType.meta(p, size: 13)),
        ),
        RdPrimaryButton(label: l10n.redesignCommonDone, onPressed: _done),
        const SizedBox(height: 28),
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('rd-extra-field-edit-delete'),
              title: l10n.redesignExtraFieldEditDelete,
              titleColor: p.absent,
              leading: Icon(Icons.delete_outline, color: p.absent),
              showChevron: false,
              onTap: _busy ? null : () => _delete(field),
            ),
          ],
        ),
        hint(l10n.redesignExtraFieldEditDeleteHint),
      ],
    );
  }
}
