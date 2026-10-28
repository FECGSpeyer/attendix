import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/files_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/extra_fields_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import '../widgets/ion_condense.dart'; // UX_SETTINGS (WAVE 8)
import '../widgets/settings_list.dart'; // UX_SETTINGS (WAVE 8)

enum ExtraFieldTarget { person, song }

/// ID eines Zusatzfeldes aus dem Namen (wie Ionic: lowercase, `_` statt Leerzeichen)
String extraFieldIdFromName(String name) {
  return name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');
}

String extraFieldTypeName(String type) {
  final l10n = l10nWithoutContext;
  switch (type) {
    case 'text':
      return l10n.typeSettingsText;
    case 'textarea':
      return l10n.extraFieldsTextarea;
    case 'number':
      return l10n.extraFieldsNumber;
    case 'select':
      return l10n.extraFieldsSelect;
    case 'date':
      return l10n.attendanceDate;
    case 'boolean':
      return l10n.extraFieldsYesNo;
    case 'bfecg_church':
      return l10n.extraFieldsChurch;
    default:
      return l10n.commonUnknown;
  }
}

/// Validierung vor dem Speichern (null = ok, sonst Fehlermeldung)
String? validateExtraFields(List<ExtraField> fields) {
  final l10n = l10nWithoutContext;
  for (final f in fields) {
    if (f.name.trim().isEmpty) return l10n.extraFieldsAllNeedName;
    if (f.type == 'select') {
      if (f.options == null || f.options!.isEmpty) {
        return l10n.extraFieldsSelectNeedsOption(f.name);
      }
      if (f.options!.any((o) => o.trim().isEmpty)) {
        return l10n.extraFieldsOptionsEmptyIn(f.name);
      }
    }
  }
  return null;
}

/// Zusatzfelder für Personen und Werke (Ionic: settings/general/extra-fields)
class ExtraFieldsPage extends ConsumerStatefulWidget {
  const ExtraFieldsPage({super.key});

  @override
  ConsumerState<ExtraFieldsPage> createState() => _ExtraFieldsPageState();
}

class _ExtraFieldsPageState extends ConsumerState<ExtraFieldsPage> {
  List<ExtraField> _personFields = [];
  List<ExtraField> _songFields = [];
  bool _saving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final tenant = ref.read(currentTenantProvider);
    _personFields = [...?tenant?.additionalFields];
    _songFields = [...?tenant?.songAdditionalFields];
  }

  List<ExtraField> _fields(ExtraFieldTarget t) => t == ExtraFieldTarget.person ? _personFields : _songFields;

  void _setFields(ExtraFieldTarget t, List<ExtraField> fields) {
    setState(() {
      if (t == ExtraFieldTarget.person) {
        _personFields = fields;
      } else {
        _songFields = fields;
      }
      _hasChanges = true;
    });
  }

  List<Object> get _churchIds =>
      (ref.read(churchesProvider).valueOrNull ?? []).map((c) => c.id).whereType<String>().toList();

  Future<void> _addField(ExtraFieldTarget target) async {
    final result = await _showFieldSheet(target: target);
    if (result == null) return;
    final fields = _fields(target);
    final id = result.type == 'bfecg_church' ? 'bfecg_church' : extraFieldIdFromName(result.name);
    if (id.isEmpty) {
      if (mounted) ToastHelper.showError(context, context.l10n.extraFieldsIdEmpty);
      return;
    }
    if (fields.any((f) => f.id == id)) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.extraFieldsIdExists);
      }
      return;
    }
    _setFields(target, [...fields, result.copyWith(id: id)]);
  }

  Future<void> _editField(ExtraFieldTarget target, int index) async {
    final fields = _fields(target);
    final result = await _showFieldSheet(target: target, existing: fields[index]);
    if (result == null) return;
    final updated = [...fields];
    updated[index] = result;
    _setFields(target, updated);
  }

  Future<void> _removeField(ExtraFieldTarget target, int index) async {
    final fields = _fields(target);
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.extraFieldsDeleteField,
      message: context.l10n.extraFieldsDeleteFieldMessage(fields[index].name),
      confirmText: context.l10n.commonDelete,
      isDestructive: true,
    );
    if (!confirmed) return;
    _setFields(target, [...fields]..removeAt(index));
  }

  void _reorder(ExtraFieldTarget target, int oldIndex, int newIndex) {
    final fields = [..._fields(target)];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = fields.removeAt(oldIndex);
    fields.insert(newIndex, item);
    _setFields(target, fields);
  }

  Future<void> _save() async {
    final error = validateExtraFields([..._personFields, ..._songFields]);
    if (error != null) {
      ToastHelper.showError(context, error);
      return;
    }
    final repo = ref.read(extraFieldsRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return;
    setState(() => _saving = true);
    try {
      await repo.saveFields(personFields: _personFields, songFields: _songFields);
      await repo.sanitizeValues(table: 'player', definitions: _personFields, churchIds: _churchIds);
      await repo.sanitizeValues(table: 'songs', definitions: _songFields);

      final tenant = ref.read(currentTenantProvider);
      if (tenant != null) {
        await ref.read(currentTenantProvider.notifier).setTenantLocal(
              tenant.copyWith(additionalFields: _personFields, songAdditionalFields: _songFields),
            );
      }
      if (!mounted) return;
      setState(() => _hasChanges = false);
      ToastHelper.showSuccess(context, context.l10n.extraFieldsSaved);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.extraFieldsSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Feld-Editor (Bottom Sheet)
  // ---------------------------------------------------------------------------

  Future<ExtraField?> _showFieldSheet({required ExtraFieldTarget target, ExtraField? existing}) {
    final isEdit = existing != null;
    final isPerson = target == ExtraFieldTarget.person;
    final tenantId = ref.read(currentTenantIdProvider);
    final nameController = TextEditingController(text: existing?.name ?? '');
    final defaultController = TextEditingController(
      text: existing != null && existing.type != 'boolean' && existing.defaultValue != null
          ? '${existing.defaultValue}'
          : '',
    );
    var type = existing?.type ?? 'text';
    var displayMode = existing?.displayMode ?? 'chip';
    var visible = existing?.visibleToPlayers ?? false;
    var editable = existing?.editableByPlayers ?? false;
    var boolDefault = existing?.type == 'boolean' ? existing?.defaultValue == true : false;
    final options = <TextEditingController>[
      for (final o in existing?.options ?? const <String>[]) TextEditingController(text: o),
    ];
    final originalOptions = [...?existing?.options];

    return showModalBottomSheet<ExtraField>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> removeOption(int i) async {
            final extraFieldsRepo = ref.read(extraFieldsRepositoryWithTenantProvider);
            final value = options[i].text;
            if (isEdit && isPerson && value.isNotEmpty && originalOptions.contains(value)) {
              final ok = await DialogHelper.showConfirmation(
                ctx,
                title: context.l10n.extraFieldsDeleteOption,
                message: context.l10n.extraFieldsDeleteOptionMessage(value),
                confirmText: context.l10n.commonDelete,
                isDestructive: true,
              );
              if (!ok) return;
              final remaining = options.map((c) => c.text).toList()..removeAt(i);
              final newDefault = remaining.isNotEmpty ? remaining.first : '';
              try {
                final count = await extraFieldsRepo
                    .updateFieldValue(existing.id, value, newDefault);
                if (count > 0 && mounted) ToastHelper.showSuccess(context, context.l10n.extraFieldsPersonsUpdated(count));
              } catch (_) {
                if (mounted) ToastHelper.showError(context, context.l10n.svcUpdateExtraFieldsFailed);
                return;
              }
            }
            setSheet(() => options.removeAt(i).dispose());
          }

          Future<void> resetValues() async {
            final extraFieldsRepo = ref.read(extraFieldsRepositoryWithTenantProvider);
            final ok = await DialogHelper.showConfirmation(
              ctx,
              title: context.l10n.extraFieldsResetValues,
              message: context.l10n.extraFieldsResetValuesMessage(nameController.text),
              confirmText: context.l10n.dashSettingsReset,
              isDestructive: true,
            );
            if (!ok) return;
            final optionValues = options.map((c) => c.text).toList();
            final resolved = extraFieldDefaultValue(
              type,
              defaultValue: type == 'select'
                  ? null
                  : type == 'boolean'
                      ? boolDefault
                      : _parseDefault(type, defaultController.text),
              options: optionValues,
              churchIds: _churchIds,
            );
            try {
              final count = await extraFieldsRepo.resetFieldValues(existing!.id, resolved);
              if (mounted) ToastHelper.showSuccess(context, context.l10n.extraFieldsPersonsUpdated(count));
            } catch (_) {
              if (mounted) ToastHelper.showError(context, context.l10n.svcUpdateExtraFieldsFailed);
            }
          }

          void submit() {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              ToastHelper.showError(ctx, context.l10n.extraFieldsInvalidName);
              return;
            }
            final optionValues = options.map((c) => c.text).toList();
            dynamic defaultValue;
            if (type == 'select') {
              if (optionValues.isEmpty) {
                ToastHelper.showError(ctx, context.l10n.extraFieldsAddOption);
                return;
              }
              if (optionValues.any((o) => o.trim().isEmpty)) {
                ToastHelper.showError(ctx, context.l10n.extraFieldsOptionsEmpty);
                return;
              }
              defaultValue = optionValues.first;
            } else if (type == 'boolean') {
              defaultValue = boolDefault;
            } else if (type == 'bfecg_church') {
              defaultValue = existing?.defaultValue;
            } else {
              defaultValue = _parseDefault(type, defaultController.text);
            }
            Navigator.pop(
              sheetContext,
              ExtraField(
                id: existing?.id ?? '',
                name: name,
                type: type,
                defaultValue: defaultValue,
                options: type == 'select' ? optionValues : const [],
                visibleToPlayers: isPerson ? visible : false,
                editableByPlayers: isPerson && visible ? editable : false,
                displayMode: displayMode,
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEdit ? context.l10n.typeSettingsEditField : context.l10n.extraFieldsAddNew,
                            style: Theme.of(ctx).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetContext)),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    if (isEdit)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.l10n.typeSettingsType),
                        trailing: Text(extraFieldTypeName(type)),
                      )
                    else
                      AppDropdownFormField<String>(
                        iosInterface: AppSelectInterface.alert, // IOS_THEME2
                        value: type,
                        decoration: InputDecoration(labelText: context.l10n.typeSettingsType),
                        items: [
                          DropdownMenuItem(value: 'text', child: Text(context.l10n.typeSettingsText)),
                          DropdownMenuItem(value: 'number', child: Text(context.l10n.extraFieldsNumber)),
                          DropdownMenuItem(value: 'boolean', child: Text(context.l10n.extraFieldsYesNo)),
                          DropdownMenuItem(value: 'select', child: Text(context.l10n.extraFieldsSelect)),
                          if (isPerson && tenantId == 12)
                            DropdownMenuItem(value: 'bfecg_church', child: Text(context.l10n.extraFieldsChurch)),
                        ],
                        onChanged: (v) => setSheet(() {
                          type = v ?? 'text';
                          boolDefault = false;
                          defaultController.text = type == 'number' ? '0' : '';
                        }),
                      ),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(labelText: context.l10n.typeSettingsName),
                    ),
                    AppDropdownFormField<String>(
                      iosInterface: AppSelectInterface.alert, // IOS_THEME2
                      value: displayMode,
                      decoration: InputDecoration(labelText: context.l10n.extraFieldsDisplay),
                      items: [
                        DropdownMenuItem(value: 'chip', child: Text(context.l10n.extraFieldsAsChip)),
                        DropdownMenuItem(value: 'underneath', child: Text(context.l10n.extraFieldsUnderName)),
                      ],
                      onChanged: (v) => setSheet(() => displayMode = v ?? 'chip'),
                    ),
                    if (isPerson) ...[
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.l10n.extraFieldsVisible),
                        subtitle: Text(context.l10n.extraFieldsVisibleHelper),
                        value: visible,
                        onChanged: (v) => setSheet(() => visible = v),
                      ),
                      if (visible)
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.l10n.extraFieldsEditable),
                          subtitle: Text(context.l10n.extraFieldsEditableHelper),
                          value: editable,
                          onChanged: (v) => setSheet(() => editable = v),
                        ),
                    ],
                    if (type == 'select') ...[
                      const SizedBox(height: AppDimensions.paddingS),
                      Row(
                        children: [
                          Expanded(child: Text(context.l10n.typeSettingsOptions, style: Theme.of(ctx).textTheme.titleSmall)),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => setSheet(() => options.add(TextEditingController())),
                          ),
                        ],
                      ),
                      if (options.isEmpty)
                        Text(isEdit ? context.l10n.extraFieldsNoOptions : context.l10n.extraFieldsNoOptionsSelected,
                            style: const TextStyle(color: AppColors.medium)),
                      for (var i = 0; i < options.length; i++)
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: options[i],
                                textCapitalization: TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: context.l10n.extraFieldsValuePh,
                                  helperText: i == 0 ? context.l10n.extraFieldsFlutterFirstOptionDefault : null,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                              onPressed: () => removeOption(i),
                            ),
                          ],
                        ),
                    ],
                    if (type != 'select' && type != 'bfecg_church') ...[
                      const SizedBox(height: AppDimensions.paddingS),
                      if (type == 'boolean')
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.l10n.extraFieldsDefaultValue),
                          value: boolDefault,
                          onChanged: (v) => setSheet(() => boolDefault = v),
                        )
                      else
                        TextField(
                          controller: defaultController,
                          keyboardType: type == 'number' ? TextInputType.number : TextInputType.text,
                          decoration: InputDecoration(
                            labelText: isEdit ? context.l10n.extraFieldsDefaultValue : context.l10n.extraFieldsDefaultOptional,
                          ),
                        ),
                    ],
                    if (isEdit && isPerson) ...[
                      const SizedBox(height: AppDimensions.paddingS),
                      TextButton(
                        onPressed: resetValues,
                        child: Text(context.l10n.extraFieldsResetAll,
                            style: const TextStyle(color: AppColors.warning)),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.paddingM),
                    ElevatedButton(
                      onPressed: submit,
                      child: Text(isEdit ? context.l10n.commonApply : context.l10n.typeSettingsAddField),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      nameController.dispose();
      defaultController.dispose();
      for (final c in options) {
        c.dispose();
      }
    });
  }

  static dynamic _parseDefault(String type, String text) {
    if (type == 'number') return num.tryParse(text.trim()) ?? 0;
    return text;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Future<void> _confirmLeave() async {
    final leave = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.rolePermUnsaved,
      message: context.l10n.extraFieldsFlutterLeaveMessage,
      confirmText: context.l10n.rolePermDiscard,
      isDestructive: true,
    );
    if (leave && mounted) {
      setState(() => _hasChanges = false);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kirchen vorladen (Standardwert für BFECG-Gemeinde)
    ref.watch(churchesProvider);

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      // UX_SETTINGS (WAVE 8): extra-fields.page.html — arrow-back, condense
      // title, checkmark save, inset groups with header "+" buttons.
      child: IonCondense(builder: (context, collapsed) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: IonCondenseTitle(context.l10n.extraFieldsTitle, collapsed: collapsed),
          actions: [
            IconButton(
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: AppSpinner(strokeWidth: 2))
                  : const Icon(Icons.check),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(ionListMargin(context), ionIsIos(context) ? 0 : 16, ionListMargin(context), 16),
          children: [
            IonLargeTitle(context.l10n.extraFieldsTitle, padding: const EdgeInsets.only(bottom: 4)),
            if (ionIsIos(context)) const SizedBox(height: 16),
            _buildSection(ExtraFieldTarget.person, context.l10n.extraFieldsForPersons),
            if (!ionIsIos(context)) const SizedBox(height: AppDimensions.paddingL),
            _buildSection(ExtraFieldTarget.song, context.l10n.extraFieldsForSongs),
            if (!ionIsIos(context)) const SizedBox(height: AppDimensions.paddingL),
            // Ionic: ion-padding + expand="block" button
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(context.l10n.commonSave),
            ),
          ],
        ),
      )),
    );
  }

  Widget _buildSection(ExtraFieldTarget target, String title) {
    final fields = _fields(target);
    final list = fields.isEmpty
              ? ListTile(title: Text(context.l10n.extraFieldsNoneYet))
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: fields.length,
                  onReorder: (o, n) => _reorder(target, o, n),
                  itemBuilder: (context, i) {
                    final f = fields[i];
                    final lines = <String>[
                      if (f.id != 'bfecg_church') context.l10n.extraFieldsTypeLine(extraFieldTypeName(f.type)),
                      context.l10n.extraFieldsDisplayLine(f.displayMode == 'underneath'
                          ? context.l10n.extraFieldsUnderName
                          : context.l10n.extraFieldsAsChip),
                      if (target == ExtraFieldTarget.person && (f.visibleToPlayers ?? false))
                        '${context.l10n.extraFieldsVisible}${(f.editableByPlayers ?? false) ? context.l10n.extraFieldsEditableSuffix : ''}',
                    ];
                    return ListTile(
                      key: ValueKey('${target.name}-${f.id}-$i'),
                      title: Text(f.name),
                      subtitle: Text(lines.join('\n')),
                      isThreeLine: lines.length > 2,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                            onPressed: () => _editField(target, i),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                            onPressed: () => _removeField(target, i),
                          ),
                          if (fields.length > 1)
                            ReorderableDragStartListener(
                              index: i,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
    if (ionIsIos(context)) {
      return SettingsListSection(
        title: title,
        icons: false,
        headerAction: IconButton(
          icon: const Icon(Icons.add, color: AppColors.primary),
          tooltip: context.l10n.extraFieldsAddNew,
          onPressed: () => _addField(target),
        ),
        children: [list],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: context.l10n.extraFieldsAddNew,
              onPressed: () => _addField(target),
            ),
          ],
        ),
        Card(child: list),
      ],
    );
  }
}
