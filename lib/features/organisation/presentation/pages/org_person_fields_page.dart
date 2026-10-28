import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../planning/presentation/widgets/plan_field_dialogs.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/widgets/ion_condense.dart'; // UX_SETTINGS (WAVE 8)
import '../../../settings/presentation/widgets/settings_list.dart'; // UX_SETTINGS (WAVE 8)

Map<String, String> _fieldTypes(AppLocalizations l10n) => <String, String>{
      'text': l10n.typeSettingsText,
      'textarea': l10n.extraFieldsTextarea,
      'number': l10n.extraFieldsNumber,
      'date': l10n.attendanceDate,
      'boolean': l10n.extraFieldsYesNo,
      'select': l10n.extraFieldsSelect,
    };

String _typeName(AppLocalizations l10n, String type) => _fieldTypes(l10n)[type] ?? l10n.commonUnknown;

/// Field id of an org-wide extra field (Ionic `org_<orgId>_<name>`).
String orgFieldId(int orgId, String name) =>
    'org_${orgId}_${name.toLowerCase().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-z0-9_]'), '')}';

/// "Personen-Zusatzfelder" of the organisation (Ionic `OrgPersonFieldsPage`).
///
/// Edits `tenant_groups.additional_fields`; values of deleted fields are
/// removed from `tenant_group_person_fields` on save.
class OrgPersonFieldsPage extends ConsumerStatefulWidget {
  const OrgPersonFieldsPage({super.key});

  @override
  ConsumerState<OrgPersonFieldsPage> createState() => _OrgPersonFieldsPageState();
}

class _OrgPersonFieldsPageState extends ConsumerState<OrgPersonFieldsPage> {
  List<OrgExtraField>? _fields;
  Set<String> _originalIds = {};
  bool _saving = false;

  bool get _isSuperAdmin => ref.read(effectiveRoleProvider) == Role.admin;

  Future<void> _add(int orgId) async {
    final field = await showModalBottomSheet<OrgExtraField>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FieldEditorSheet(),
    );
    if (field == null || !mounted) return;
    final id = orgFieldId(orgId, field.name);
    if (_fields!.any((f) => f.id == id)) {
      ToastHelper.showError(context, context.l10n.orgFieldsNameExists);
      return;
    }
    setState(() => _fields = [..._fields!, field.copyWith(id: id)]);
  }

  Future<void> _edit(int index) async {
    final field = await showModalBottomSheet<OrgExtraField>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FieldEditorSheet(initial: _fields![index]),
    );
    if (field == null) return;
    setState(() {
      final list = [..._fields!];
      list[index] = field;
      _fields = list;
    });
  }

  Future<void> _remove(int index) async {
    final ok = await showPlanConfirm(
      context,
      title: context.l10n.extraFieldsDeleteField,
      message: context.l10n.extraFieldsDeleteFieldMessage(_fields![index].name),
      confirmText: context.l10n.commonDelete,
      destructive: true,
    );
    if (ok) setState(() => _fields = [..._fields!]..removeAt(index));
  }

  Future<void> _save(int orgId) async {
    if (!_isSuperAdmin) return;
    for (final f in _fields!) {
      if (f.name.trim().isEmpty || !f.id.startsWith('org_${orgId}_')) {
        ToastHelper.showError(context, context.l10n.orgFieldsInvalid);
        return;
      }
      if (f.type == 'select' && f.options.isEmpty) {
        ToastHelper.showError(context, context.l10n.orgFieldsNeedsOptions(f.name));
        return;
      }
    }
    setState(() => _saving = true);
    final current = _fields!.map((f) => f.id).toSet();
    final deleted = _originalIds.where((id) => !current.contains(id)).toList();
    final ok = await ref.read(planSettingsNotifierProvider.notifier).updateOrgExtraFields(_fields!, deleted);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _originalIds = current;
      ToastHelper.showSuccess(context, context.l10n.orgFieldsSaved);
    } else {
      ToastHelper.showError(context, context.l10n.extraFieldsSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(currentOrganisationProvider).valueOrNull;
    final isSuperAdmin = ref.watch(effectiveRoleProvider) == Role.admin;
    if (_fields == null && org != null) {
      _fields = [...?org.additionalFields];
      _originalIds = _fields!.map((f) => f.id).toSet();
    }

    final ios = ionIsIos(context);
    final Widget fieldList = _fields == null
        ? const SizedBox.shrink()
        : _fields!.isEmpty
            ? ListTile(title: Text(context.l10n.orgFieldsNone))
            : ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: (from, to) {
                  if (!isSuperAdmin) return;
                  setState(() {
                    final list = [..._fields!];
                    final item = list.removeAt(from);
                    list.insert(to > from ? to - 1 : to, item);
                    _fields = list;
                  });
                },
                children: [
                  for (var i = 0; i < _fields!.length; i++) _fieldTile(i, isSuperAdmin),
                ],
              );
    final addButton = IconButton(
      tooltip: context.l10n.extraFieldsAddNew,
      icon: Icon(Icons.add, color: ios ? AppColors.primary : null),
      onPressed: isSuperAdmin && org?.id != null ? () => _add(org!.id!) : null,
    );

    // UX_SETTINGS (WAVE 8): org-person-fields.page.html — arrow-back,
    // condense title, intro item + "Für Personen" inset list with header "+".
    return IonCondense(builder: (context, collapsed) => Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: IonCondenseTitle(context.l10n.orgPersonFields, collapsed: collapsed),
        actions: [
          IconButton(
            tooltip: context.l10n.commonSave,
            icon: const Icon(Icons.check),
            onPressed: _saving || !isSuperAdmin || org?.id == null ? null : () => _save(org!.id!),
          ),
        ],
      ),
      body: _fields == null
          ? const Center(child: CircularProgressIndicator())
          : ios
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    IonLargeTitle(context.l10n.orgPersonFields, padding: const EdgeInsets.only(bottom: 4)),
                    const SizedBox(height: 16),
                    SettingsListSection(
                      children: [
                        SettingsListTile(
                          icon: Icons.info_outline,
                          iconColor: AppColors.medium,
                          title: context.l10n.orgFieldsIntro,
                          titleWidget: Text(
                            context.l10n.orgFieldsIntro,
                            style: TextStyle(fontSize: 14, color: IonIos.labelP(context)),
                          ),
                        ),
                      ],
                    ),
                    SettingsListSection(
                      title: context.l10n.extraFieldsForPersons,
                      icons: false,
                      headerAction: addButton,
                      children: [fieldList],
                    ),
                  ],
                )
              : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppColors.medium),
                  title: Text(
                    context.l10n.orgFieldsIntro,
                    style: const TextStyle(fontSize: 13, color: AppColors.medium),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(context.l10n.extraFieldsForPersons.toUpperCase(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.medium)),
                      ),
                      addButton,
                    ],
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: fieldList,
                ),
              ],
            ),
    ));
  }

  Widget _fieldTile(int i, bool isSuperAdmin) {
    final f = _fields![i];
    final l10n = context.l10n;
    final mode = f.displayMode == 'underneath' ? l10n.extraFieldsUnderName : l10n.extraFieldsAsChip;
    return ListTile(
      key: ValueKey(f.id),
      title: Text(f.name),
      subtitle: Text([
        l10n.extraFieldsTypeLine(_typeName(l10n, f.type)),
        l10n.extraFieldsDisplayLine(mode),
        if (f.visibleToPlayers) '${l10n.extraFieldsVisible}${f.editableByPlayers ? l10n.extraFieldsEditableSuffix : ''}',
      ].join('\n')),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: isSuperAdmin ? () => _edit(i) : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: isSuperAdmin ? () => _remove(i) : null,
          ),
          if (isSuperAdmin) ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
        ],
      ),
    );
  }
}

/// Add / edit sheet of one org extra field.
class _FieldEditorSheet extends StatefulWidget {
  const _FieldEditorSheet({this.initial});
  final OrgExtraField? initial;

  @override
  State<_FieldEditorSheet> createState() => _FieldEditorSheetState();
}

class _FieldEditorSheetState extends State<_FieldEditorSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _default =
      TextEditingController(text: widget.initial?.defaultValue is String ? widget.initial!.defaultValue as String : '');
  late String _type = widget.initial?.type ?? 'text';
  late String _displayMode = widget.initial?.displayMode ?? 'chip';
  late bool _visible = widget.initial?.visibleToPlayers ?? false;
  late bool _editable = widget.initial?.editableByPlayers ?? false;
  late bool _boolDefault = widget.initial?.defaultValue == true;
  late final List<TextEditingController> _options =
      (widget.initial?.options ?? const <String>[]).map((o) => TextEditingController(text: o)).toList();

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _default.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ToastHelper.showError(context, context.l10n.extraFieldsInvalidName);
      return;
    }
    final options = _options.map((c) => c.text.trim()).where((o) => o.isNotEmpty).toList();
    if (_type == 'select' && options.isEmpty) {
      ToastHelper.showError(context, context.l10n.orgFieldsAddOption);
      return;
    }
    final dynamic defaultValue = switch (_type) {
      'select' => options.first,
      'boolean' => _boolDefault,
      _ => _default.text,
    };
    Navigator.pop(
      context,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_isEdit ? context.l10n.typeSettingsEditField : context.l10n.extraFieldsAddNew, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (_isEdit)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.typeSettingsType),
                  trailing: Text(_typeName(context.l10n, _type)),
                )
              else
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: InputDecoration(labelText: context.l10n.typeSettingsType),
                  items: [
                    for (final e in _fieldTypes(context.l10n).entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'text'),
                ),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: context.l10n.typeSettingsName),
              ),
              DropdownButtonFormField<String>(
                value: _displayMode,
                decoration: InputDecoration(labelText: context.l10n.extraFieldsDisplay),
                items: [
                  DropdownMenuItem(value: 'chip', child: Text(context.l10n.extraFieldsAsChip)),
                  DropdownMenuItem(value: 'underneath', child: Text(context.l10n.extraFieldsUnderName)),
                ],
                onChanged: (v) => setState(() => _displayMode = v ?? 'chip'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.extraFieldsVisible),
                subtitle: Text(context.l10n.extraFieldsVisibleHelper),
                value: _visible,
                onChanged: (v) => setState(() => _visible = v),
              ),
              if (_visible)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.extraFieldsEditable),
                  subtitle: Text(context.l10n.extraFieldsEditableHelper),
                  value: _editable,
                  onChanged: (v) => setState(() => _editable = v),
                ),
              if (_type == 'select') ...[
                Row(
                  children: [
                    Expanded(child: Text(context.l10n.typeSettingsOptions, style: const TextStyle(fontWeight: FontWeight.bold))),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => _options.add(TextEditingController())),
                    ),
                  ],
                ),
                if (_options.isEmpty) Text(context.l10n.extraFieldsNoOptionsSelected),
                for (var i = 0; i < _options.length; i++)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _options[i],
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: context.l10n.extraFieldsValuePh,
                            helperText: i == 0 ? context.l10n.orgFieldsFlutterFirstOptionDefault : null,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        onPressed: () => setState(() => _options.removeAt(i).dispose()),
                      ),
                    ],
                  ),
              ] else if (_type == 'boolean')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.extraFieldsDefaultValue),
                  value: _boolDefault,
                  onChanged: (v) => setState(() => _boolDefault = v),
                )
              else
                TextField(
                  controller: _default,
                  keyboardType: _type == 'number' ? TextInputType.number : TextInputType.text,
                  decoration: InputDecoration(labelText: _isEdit ? context.l10n.extraFieldsDefaultValue : context.l10n.extraFieldsDefaultOptional),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: Text(_isEdit ? context.l10n.orgFieldsApplyChanges : context.l10n.typeSettingsAddField),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
