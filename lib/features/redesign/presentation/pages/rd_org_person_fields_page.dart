import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/organisation/organisation.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../organisation/presentation/pages/org_person_fields_page.dart'
    show numberFieldDefaultText, orgFieldId, orgFieldTypeName, orgFieldTypes;
import '../widgets/event/rd_form_widgets.dart';
import '../widgets/manage/rd_manage_list.dart';
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/rd_widgets.dart';

Future<void>? _orgFieldWrites;

/// Writes of the shared fields not finished yet (also of a closed page).
/// While one runs the list is locked, so no form starts from a list that is
/// about to change.
final _orgFieldWritesPending = ValueNotifier<int>(0);

/// Runs [task] after every earlier write of the shared fields (also of a
/// closed page); never throws.
Future<bool> _serialOrgFieldWrite(Future<bool> Function() task) {
  _orgFieldWritesPending.value++;
  final result = (_orgFieldWrites ?? Future<void>.value())
      .then((_) => task())
      .catchError((Object _) => false)
      .whenComplete(() => _orgFieldWritesPending.value--);
  _orgFieldWrites = result.then((_) {});
  return result;
}

/// REDESIGN: Organisation › Gemeinsame Zusatzfelder in the template
/// "Verwaltungsliste" (like Verwaltung › Zusatzfelder; replaces
/// `/settings/org-settings/person-fields` while the Beta is on). A tap opens
/// "Feld" (form page), "+" "Neues Feld", "Reihenfolge ändern" sits behind
/// "•••". Every change is saved right away like "Speichern" of the old page
/// (same checks; values of a deleted field are removed). Only super admins
/// change anything (old page).
class RdOrgPersonFieldsPage extends ConsumerStatefulWidget {
  const RdOrgPersonFieldsPage({super.key});

  @override
  ConsumerState<RdOrgPersonFieldsPage> createState() => _RdOrgPersonFieldsPageState();
}

class _RdOrgPersonFieldsPageState extends ConsumerState<RdOrgPersonFieldsPage> {
  /// Synchronous check for the form (name taken): the shown list.
  List<OrgExtraField> _shownFields(int orgId) {
    final org = rdLoadedValue(ref.read(currentOrganisationProvider));
    return org?.id == orgId ? (org!.additionalFields ?? const []) : const [];
  }

  /// Saves the list [change] builds from the fields of [orgId] as stored
  /// then (null: no write); [deleted] ids get their values removed. Old page
  /// `_save` checks. Runs through [_orgFieldWrites] with the provider
  /// container, so a change confirmed with "Fertig" is also stored when the
  /// page is left meanwhile. Returns whether it was stored.
  Future<bool> _write(
    int orgId,
    List<OrgExtraField>? Function(List<OrgExtraField> stored) change, {
    List<String> deleted = const [],
    String? success,
  }) async {
    final l10n = context.l10n;
    final read = ProviderScope.containerOf(context, listen: false).read;
    String? error;
    final ok = await _serialOrgFieldWrite(() async {
      try {
        if (read(effectiveRoleProvider) != Role.admin) return false;
        // Waits for a running (re)load: after a write this is the reloaded list.
        final org = await read(currentOrganisationProvider.future);
        if (org?.id != orgId) return false;
        final next = change([...?org!.additionalFields]);
        if (next == null) return false;
        for (final f in next) {
          if (f.name.trim().isEmpty || !f.id.startsWith('org_${orgId}_')) {
            error = l10n.orgFieldsInvalid;
            return false;
          }
          if (f.type == 'select' && f.options.isEmpty) {
            error = l10n.orgFieldsNeedsOptions(f.name);
            return false;
          }
        }
        // Written only into [orgId] (checked again right before the write).
        final stored = await read(
          planSettingsNotifierProvider.notifier,
        ).updateOrgExtraFields(next, deleted, orgId: orgId);
        if (stored) {
          // The queue moves on once the stored list is loaded again, so the
          // next change builds on it; a failed reload shows the error below.
          await read(currentOrganisationProvider.future);
        } else {
          error = l10n.extraFieldsSaveFailed;
        }
        return stored;
      } catch (_) {
        // E.g. the organisation could not be loaded again.
        error = l10n.extraFieldsSaveFailed;
        return false;
      }
    });
    if (mounted) {
      if (ok) {
        ToastHelper.showSuccess(context, success ?? l10n.orgFieldsSaved);
      } else if (error != null) {
        ToastHelper.showError(context, error!);
      }
    }
    return ok;
  }

  Future<void> _add(int orgId) async {
    final field = await _openForm(
      context,
      nameExists: (name) => _shownFields(orgId).any((f) => f.id == orgFieldId(orgId, name)),
    );
    if (field is! OrgExtraField || !mounted) return;
    final id = orgFieldId(orgId, field.name);
    await _write(orgId, (stored) => stored.any((f) => f.id == id) ? null : [...stored, field.copyWith(id: id)]);
  }

  Future<void> _edit(int orgId, OrgExtraField field) async {
    if (ref.read(effectiveRoleProvider) != Role.admin) return;
    final result = await _openForm(context, initial: field);
    if (!mounted || result == null) return;
    if (result == _delete) {
      await _write(
        orgId,
        (stored) => stored.any((f) => f.id == field.id) ? [...stored.where((f) => f.id != field.id)] : null,
        deleted: [field.id],
      );
      return;
    }
    if (result is! OrgExtraField) return;
    await _write(orgId, (stored) {
      final index = stored.indexWhere((f) => f.id == field.id);
      if (index < 0) return null;
      return [...stored]..[index] = result;
    });
  }

  Future<bool> _saveOrder(int orgId, List<RdManageListSection> sections) {
    final order = [
      for (final s in sections)
        for (final i in s.items) i.id,
    ];
    return _write(orgId, (stored) {
      final byId = {for (final f in stored) f.id: f};
      final ordered = [
        for (final id in order)
          if (byId[id] != null) byId[id]!,
      ];
      // Nothing may get lost: fields the list did not show stay at the end.
      return [...ordered, ...stored.where((f) => !ordered.contains(f))];
    }, success: context.l10n.typeSettingsOrderSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(currentOrganisationProvider);
    final org = rdLoadedValue(async);
    final isSuperAdmin = ref.watch(effectiveRoleProvider) == Role.admin;
    return ValueListenableBuilder<int>(
      valueListenable: _orgFieldWritesPending,
      builder: (context, pending, _) => _list(l10n, async, org, isSuperAdmin, saving: pending > 0),
    );
  }

  /// [saving]: a write still runs; the list is locked until it is stored
  /// and loaded again.
  Widget _list(
    AppLocalizations l10n,
    AsyncValue<Organisation?> async,
    Organisation? org,
    bool isSuperAdmin, {
    required bool saving,
  }) {
    final canEdit = isSuperAdmin && !saving;
    final orgId = org?.id;
    final fields = org?.additionalFields ?? const <OrgExtraField>[];
    String summary(OrgExtraField f) => [
      orgFieldTypeName(l10n, f.type),
      f.displayMode == 'underneath' ? l10n.extraFieldsUnderName : l10n.extraFieldsAsChip,
      if (f.visibleToPlayers) '${l10n.extraFieldsVisible}${f.editableByPlayers ? l10n.extraFieldsEditableSuffix : ''}',
    ].join(' · ');

    return RdManageListPage(
      key: ValueKey(orgId),
      notice: saving ? l10n.rdOrgFieldsSaving : null,
      title: l10n.rdOrgPersonFields,
      intro: l10n.orgFieldsIntro,
      backLabel: l10n.rdOrgBack,
      onBack: () => context.canPop() ? context.pop() : context.go('/settings/org-settings'),
      sections:
          org == null
              ? null
              : [
                RdManageListSection(
                  items: [
                    for (final f in fields)
                      RdManageListItem(
                        id: f.id,
                        title: f.name,
                        subtitle: summary(f),
                        onTap: canEdit && orgId != null ? () => _edit(orgId, f) : null,
                      ),
                  ],
                ),
              ],
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(currentOrganisationProvider),
      emptyText: l10n.rdOrgFieldsEmpty,
      emptyIcon: Icons.list_alt,
      addLabel: isSuperAdmin ? l10n.rdOrgFieldsAdd : null,
      onAdd: canEdit && orgId != null ? () => _add(orgId) : null,
      onReorder: canEdit && orgId != null ? (sections) => _saveOrder(orgId, sections) : null,
    );
  }
}

/// Result of the form when "Feld löschen" was confirmed.
const _delete = #delete;

/// Opens "Neues Feld" / "Feld"; returns the field on "Fertig", [_delete]
/// after a confirmed delete, null on "Abbrechen".
Future<Object?> _openForm(BuildContext context, {OrgExtraField? initial, bool Function(String name)? nameExists}) {
  return Navigator.of(context, rootNavigator: true).push<Object>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => _OrgFieldForm(initial: initial, nameExists: nameExists)),
  );
}

/// The old add / edit sheet as a Beta form: same fields, defaults and
/// checks ("Änderungen übernehmen" = "Fertig").
class _OrgFieldForm extends StatefulWidget {
  const _OrgFieldForm({this.initial, this.nameExists});

  final OrgExtraField? initial;

  /// Add mode: true when an org field with this name exists already.
  final bool Function(String name)? nameExists;

  @override
  State<_OrgFieldForm> createState() => _OrgFieldFormState();
}

class _OrgFieldFormState extends State<_OrgFieldForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');

  /// Ionic binds the default of every type (e.g. the number 0 or a date)
  /// and keeps it unless the user edits it.
  late dynamic _defaultValue = widget.initial?.defaultValue ?? '';
  late final _default = TextEditingController(text: _defaultText(_defaultValue));
  late String _type = widget.initial?.type ?? 'text';
  late String _displayMode = widget.initial?.displayMode ?? 'chip';
  late bool _visible = widget.initial?.visibleToPlayers ?? false;
  late bool _editable = widget.initial?.editableByPlayers ?? false;
  late bool _boolDefault = widget.initial?.defaultValue == true;
  late final List<TextEditingController> _options = [
    for (final o in widget.initial?.options ?? const <String>[]) TextEditingController(text: o),
  ];

  bool get _isEdit => widget.initial != null;

  static String _defaultText(dynamic v) => v == null || v is bool ? '' : '$v';

  @override
  void dispose() {
    _name.dispose();
    _default.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ionic onNewFieldTypeChanged: boolean → false, otherwise the type's
  /// default (Zahl 0, Datum heute, Text '').
  void _setType(String type) {
    setState(() {
      _type = type;
      _defaultValue = switch (type) {
        'boolean' => false,
        'number' => 0,
        'date' => DateFormat('yyyy-MM-dd').format(DateTime.now()),
        _ => '',
      };
      _boolDefault = false;
      _default.text = _defaultText(_defaultValue);
    });
  }

  Future<void> _pickType() async {
    final picked = await showRdChoiceSheet<String>(
      context,
      title: context.l10n.typeSettingsType,
      options: [for (final e in orgFieldTypes(context.l10n).entries) (e.key, e.value)],
      selected: _type,
    );
    if (picked != null && picked != _type && mounted) _setType(picked);
  }

  String _dateLabel() {
    final d = DateTime.tryParse('$_defaultValue');
    return d == null ? '' : DateFormat(dateFmt()).format(d.toLocal());
  }

  Future<void> _pickDate() async {
    final current = DateTime.tryParse('$_defaultValue')?.toLocal() ?? DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _defaultValue = DateFormat('yyyy-MM-dd').format(picked));
  }

  void _done() {
    final l10n = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ToastHelper.showError(context, l10n.extraFieldsInvalidName);
      return;
    }
    if (widget.nameExists?.call(name) ?? false) {
      ToastHelper.showError(context, l10n.orgFieldsNameExists);
      return;
    }
    final options = _options.map((c) => c.text.trim()).where((o) => o.isNotEmpty).toList();
    if (_type == 'select' && options.isEmpty) {
      ToastHelper.showError(context, l10n.orgFieldsAddOption);
      return;
    }
    final dynamic defaultValue = switch (_type) {
      'select' => options.first,
      'boolean' => _boolDefault,
      'date' => _defaultValue,
      // Unchanged input keeps the bound value (e.g. the number 0).
      _ when _default.text == _defaultText(_defaultValue) => _defaultValue,
      'number' => numberFieldDefaultText(_default.text),
      _ => _default.text,
    };
    Navigator.of(context).pop(
      OrgExtraField(
        id: widget.initial?.id ?? '',
        name: name,
        type: _type,
        defaultValue: defaultValue,
        options: _type == 'select' ? options : const [],
        visibleToPlayers: _visible,
        editableByPlayers: _visible && _editable,
        displayMode: _displayMode,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirm(
      context,
      title: l10n.extraFieldsDeleteField,
      message: l10n.extraFieldsDeleteFieldMessage(widget.initial?.name ?? ''),
      confirmText: l10n.commonDelete,
      destructive: true,
    );
    if (confirmed && mounted) Navigator.of(context).pop(_delete);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final textStyle = TextStyle(fontSize: 17, color: p.text);

    Widget hint(String text) =>
        Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child: Text(text, style: RdType.meta(p, size: 13)));

    Widget switchRow(String title, String? subtitle, bool value, ValueChanged<bool> onChanged) => RdListRow(
      title: title,
      subtitle: subtitle,
      showChevron: false,
      onTap: () => onChanged(!value),
      trailing: Switch.adaptive(value: value, activeTrackColor: p.primary, onChanged: onChanged),
    );

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RdFormTopBar(
              title: _isEdit ? l10n.rdOrgFieldEdit : l10n.rdOrgFieldNew,
              cancel: l10n.redesignCommonCancel,
              submit: l10n.redesignCommonDone,
              saving: false,
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _done,
            ),
            Expanded(
              child: RdFormBody(
                children: [
                  RdGroupedList(
                    children: [
                      RdFieldRow(
                        label: l10n.redesignExtraFieldEditName,
                        child: TextField(
                          controller: _name,
                          autofocus: !_isEdit,
                          textCapitalization: TextCapitalization.sentences,
                          style: textStyle,
                          decoration: rdInputDecoration(p, ''),
                        ),
                      ),
                      RdListRow(
                        title: l10n.typeSettingsType,
                        value: orgFieldTypeName(l10n, _type),
                        showChevron: !_isEdit,
                        onTap: _isEdit ? null : _pickType,
                      ),
                    ],
                  ),
                  if (_isEdit) hint(l10n.rdOrgFieldTypeFixed),
                  const SizedBox(height: 20),
                  RdGroupLabel(l10n.extraFieldsDisplay),
                  RdSegmented<String>(
                    values: const ['chip', 'underneath'],
                    selected: _displayMode,
                    semanticLabel: l10n.extraFieldsDisplay,
                    labelOf: (v) => v == 'underneath' ? l10n.extraFieldsUnderName : l10n.extraFieldsAsChip,
                    onChanged: (v) => setState(() => _displayMode = v),
                  ),
                  const SizedBox(height: 20),
                  RdGroupedList(
                    children: [
                      switchRow(
                        l10n.extraFieldsVisible,
                        l10n.extraFieldsVisibleHelper,
                        _visible,
                        (v) => setState(() => _visible = v),
                      ),
                      if (_visible)
                        switchRow(
                          l10n.extraFieldsEditable,
                          l10n.extraFieldsEditableHelper,
                          _editable,
                          (v) => setState(() => _editable = v),
                        ),
                    ],
                  ),
                  if (_type == 'select') ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: RdGroupLabel(l10n.redesignExtraFieldEditOptions)),
                        RdTextLink(
                          label: l10n.redesignExtraFieldEditOptionAdd,
                          onTap: () => setState(() => _options.add(TextEditingController())),
                        ),
                      ],
                    ),
                    if (_options.isNotEmpty)
                      RdGroupedList(
                        children: [
                          for (final c in _options)
                            Padding(
                              key: ObjectKey(c),
                              padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: c,
                                      textCapitalization: TextCapitalization.sentences,
                                      style: textStyle,
                                      decoration: rdInputDecoration(p, l10n.extraFieldsValuePh),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: p.absent, semanticLabel: l10n.commonDelete),
                                    onPressed: () {
                                      setState(() => _options.remove(c));
                                      WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
                                    },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    hint(
                      _options.isEmpty
                          ? l10n.redesignExtraFieldEditOptionsNeeded
                          : l10n.redesignExtraFieldEditOptionHint,
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                    RdGroupedList(
                      children: [
                        if (_type == 'boolean')
                          switchRow(
                            l10n.extraFieldsDefaultValue,
                            null,
                            _boolDefault,
                            (v) => setState(() => _boolDefault = v),
                          )
                        else if (_type == 'date')
                          RdListRow(
                            title: _isEdit ? l10n.extraFieldsDefaultValue : l10n.extraFieldsDefaultOptional,
                            value: _dateLabel(),
                            showChevron: _dateLabel().isEmpty,
                            trailing:
                                _dateLabel().isEmpty
                                    ? null
                                    : IconButton(
                                      icon: Icon(Icons.close, color: p.text2),
                                      tooltip: l10n.orgFieldsFlutterClearDefault,
                                      onPressed: () => setState(() => _defaultValue = ''),
                                    ),
                            onTap: _pickDate,
                          )
                        else
                          RdFieldRow(
                            label: _isEdit ? l10n.extraFieldsDefaultValue : l10n.extraFieldsDefaultOptional,
                            child: TextField(
                              controller: _default,
                              keyboardType: _type == 'number' ? TextInputType.number : TextInputType.text,
                              maxLines: _type == 'textarea' ? null : 1,
                              style: textStyle,
                              decoration: rdInputDecoration(p, ''),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (_isEdit) ...[
                    const SizedBox(height: 28),
                    RdGroupedList(
                      children: [
                        RdListRow(
                          title: l10n.rdOrgFieldDelete,
                          titleColor: p.absent,
                          leading: Icon(Icons.delete_outline, color: p.absent),
                          showChevron: false,
                          onTap: _confirmDelete,
                        ),
                      ],
                    ),
                    hint(l10n.rdOrgFieldDeleteHint),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
